import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounting/domain/services/auto_voucher_service.dart';
import 'package:kifino/features/accounting/domain/services/voucher_settings_service.dart';
import 'package:kifino/features/business/data/repositories/business_repository_impl.dart';
import 'package:kifino/features/business/domain/entities/contact_entity.dart';
import 'package:kifino/features/business/domain/entities/invoice_entity.dart';
import 'package:kifino/features/business/domain/entities/product_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 1-2 regression: برگشت از فروش (credit note). A return re-enters
/// stock at the weighted average, credits the customer balance, and issues
/// a mirror voucher (DR برگشت از فروش / CR مشتری + DR inventory / CR COGS).
void main() {
  late AppDatabase db;
  late BusinessRepositoryImpl repo;
  late AccountingRepositoryImpl accountingRepo;
  late AutoVoucherService voucherService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = BusinessRepositoryImpl(db);
    accountingRepo = AccountingRepositoryImpl(db);
    await accountingRepo.seedChartOfAccountsIfNotExists();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    voucherService = AutoVoucherService(
      accountingRepo,
      settingsService: VoucherSettingsService(prefs),
      businessRepository: repo,
    );
  });

  tearDown(() async => db.close());

  InvoiceEntity purchaseInvoice(String id, DateTime now) => InvoiceEntity(
        id: id,
        invoiceNumber: 'PUR-$id',
        contactId: 'sup-1',
        type: InvoiceType.purchase,
        status: InvoiceStatus.paid,
        issueDate: now,
        dueDate: now,
        subtotal: Money.fromMinor(5000000, Currency.irr),
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: Money.fromMinor(5000000, Currency.irr),
        paidAmount: Money.fromMinor(5000000, Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [
          InvoiceItemEntity(
            id: '',
            invoiceId: id,
            productId: 'p-1',
            description: 'کالا',
            quantity: 5,
            unitPrice: Money.fromMinor(1000000, Currency.irr),
            discount: Money.zero(Currency.irr),
            tax: Money.zero(Currency.irr),
            total: Money.fromMinor(5000000, Currency.irr),
          ),
        ],
      );

  test('full return flow: stock in, balance credit, mirror voucher',
      () async {
    final now = DateTime.now();
    await repo.createProduct(
      ProductEntity(
        id: 'p-1',
        name: 'کالا',
        purchasePrice: Money.fromMinor(1000000, Currency.irr),
        sellingPrice: Money.fromMinor(1500000, Currency.irr),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repo.createContact(
      ContactEntity(
        id: 'sup-1',
        name: 'تأمین',
        type: ContactType.supplier,
        outstandingBalance: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repo.createContact(
      ContactEntity(
        id: 'cust-1',
        name: 'مشتری',
        type: ContactType.customer,
        outstandingBalance: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Buy 5 @ 1,000,000 → avg 1M, stock 5.
    await repo.createInvoice(purchaseInvoice('pur-1', now));

    // Sell 3 @ 1,500,000 → stock 2, customer owes 4.5M.
    final unit = Money.fromMinor(1500000, Currency.irr);
    await repo.createInvoice(
      InvoiceEntity(
        id: 'sale-1',
        invoiceNumber: 'SALE-1',
        contactId: 'cust-1',
        type: InvoiceType.sale,
        status: InvoiceStatus.sent,
        issueDate: now,
        dueDate: now,
        subtotal: unit * 3,
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: unit * 3,
        paidAmount: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [
          InvoiceItemEntity(
            id: '',
            invoiceId: 'sale-1',
            productId: 'p-1',
            description: 'کالا',
            quantity: 3,
            unitPrice: unit,
            discount: Money.zero(Currency.irr),
            tax: Money.zero(Currency.irr),
            total: unit * 3,
          ),
        ],
      ),
    );
    await voucherService.generateInvoiceVoucher(
      (await repo.getInvoiceById('sale-1')).dataOrNull!,
    );

    // ── RETURN: full sale reversed ──
    final sale = (await repo.getInvoiceById('sale-1')).dataOrNull!;
    final ret = InvoiceEntity(
      id: 'ret-1',
      invoiceNumber: 'RET-SALE-1',
      contactId: sale.contactId,
      type: InvoiceType.salesReturn,
      status: InvoiceStatus.paid,
      issueDate: now,
      dueDate: now,
      subtotal: sale.subtotal,
      discount: sale.discount,
      tax: sale.tax,
      total: sale.total,
      paidAmount: sale.total,
      items: sale.items
          .map(
            (it) => InvoiceItemEntity(
              id: '',
              invoiceId: '',
              productId: it.productId,
              description: it.description,
              quantity: it.quantity,
              unitPrice: it.unitPrice,
              discount: it.discount,
              tax: it.tax,
              total: it.total,
            ),
          )
          .toList(),
      notes: 'برگشت فاکتور SALE-1 (sale-1)',
      createdAt: now,
      updatedAt: now,
    );
    final created = await repo.createInvoice(ret);
    expect(created.isSuccess, isTrue);
    await voucherService.generateInvoiceVoucher(
      (await repo.getInvoiceById('ret-1')).dataOrNull!,
    );

    // Stock: 2 + 3 = 5 again.
    final products = await repo.getProducts();
    expect(products.dataOrNull!.first.currentStock, equals(5.0));
    // Avg cost unchanged by the return (goods re-enter at their avg).
    expect(products.dataOrNull!.first.avgCostMinor, equals(1000000));

    // Customer balance: 4.5M − 4.5M = 0.
    final contacts = await repo.getContacts();
    final cust = contacts.dataOrNull!.firstWhere((c) => c.id == 'cust-1');
    expect(cust.outstandingBalance.minorUnits, equals(0));

    // Movements: a 'returned' entry exists for the return invoice.
    final logs = await (db.select(db.inventoryLogsTable)
          ..where((t) => t.referenceId.equals('ret-1')))
        .get();
    expect(logs.single.movementType, equals('return'));
    expect(logs.single.changeQuantity, equals(3.0));

    // Mirror voucher: DR 061002 4.5M + CR customer 4.5M, balanced.
    final docs = await accountingRepo.getDocuments();
    final voucher = docs.firstWhere((d) => d.referenceId == 'ret-1');
    final returnRows = voucher.transactions.where(
      (t) => t.subject?.code == '061002',
    );
    expect(returnRows, hasLength(1));
    expect(returnRows.first.debit.minorUnits, equals(4500000));
    expect(voucher.isBalanced, isTrue);

    // Inventory re-entry legs at avg cost: DR 015002 / CR 070001 = 3M.
    final invRow = voucher.transactions.firstWhere(
      (t) => t.subject?.code == '015002',
    );
    expect(invRow.debit.minorUnits, equals(3000000));
  });
}
