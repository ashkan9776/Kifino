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

/// Phase 1-5 regression: پیش‌فاکتور (quote) — quotes carry NO stock, NO
/// customer-balance and NO voucher effects; conversion creates a real sale
/// that applies every effect and gets its voucher.
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

  test('quote has zero side effects; conversion applies them all', () async {
    final now = DateTime.now();
    await repo.createProduct(
      ProductEntity(
        id: 'p-1',
        name: 'کالا',
        purchasePrice: Money.fromMinor(1000000, Currency.irr),
        sellingPrice: Money.fromMinor(1500000, Currency.irr),
        currentStock: 4,
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

    final unit = Money.fromMinor(1500000, Currency.irr);
    final quote = InvoiceEntity(
      id: 'q-1',
      invoiceNumber: 'QT-1',
      contactId: 'cust-1',
      type: InvoiceType.quote,
      status: InvoiceStatus.sent,
      issueDate: now,
      dueDate: now.add(const Duration(days: 7)),
      subtotal: unit * 2,
      discount: Money.zero(Currency.irr),
      tax: Money.zero(Currency.irr),
      total: unit * 2,
      paidAmount: Money.zero(Currency.irr),
      createdAt: now,
      updatedAt: now,
      items: [
        InvoiceItemEntity(
          id: '',
          invoiceId: '',
          productId: 'p-1',
          description: 'کالا',
          quantity: 2,
          unitPrice: unit,
          discount: Money.zero(Currency.irr),
          tax: Money.zero(Currency.irr),
          total: unit * 2,
        ),
      ],
    );
    final created = await repo.createInvoice(quote);
    expect(created.isSuccess, isTrue);

    // Quote: no stock change, no balance, no voucher.
    var products = await repo.getProducts();
    expect(products.dataOrNull!.first.currentStock, equals(4.0));
    var contacts = await repo.getContacts();
    expect(contacts.dataOrNull!.first.outstandingBalance.minorUnits, equals(0));
    var docs = await accountingRepo.getDocuments();
    expect(docs.where((d) => d.referenceId == 'q-1'), isEmpty);
    // generateInvoiceVoucher returns null for quotes.
    expect(
      await voucherService.generateInvoiceVoucher(quote),
      isNull,
    );

    // ── Convert ──
    final convRes = await repo.convertQuoteToInvoice('q-1');
    expect(convRes.isSuccess, isTrue);
    final sale = convRes.dataOrNull!;
    expect(sale.type, equals(InvoiceType.sale));
    expect(sale.items.first.quantity, equals(2.0));

    // Sale effects: stock 4 → 2, customer owes 3M.
    products = await repo.getProducts();
    expect(products.dataOrNull!.first.currentStock, equals(2.0));
    contacts = await repo.getContacts();
    expect(
      contacts.dataOrNull!.first.outstandingBalance.minorUnits,
      equals(3000000),
    );

    // The converted sale gets a balanced voucher.
    await voucherService.generateInvoiceVoucher(sale);
    docs = await accountingRepo.getDocuments();
    final voucher = docs.firstWhere((d) => d.referenceId == sale.id);
    expect(voucher.isBalanced, isTrue);
    expect(
      voucher.transactions.any((t) => t.subject?.code == '060001'),
      isTrue,
    );

    // Quote is left intact.
    final q2 = await repo.getInvoiceById('q-1');
    expect(q2.dataOrNull!.type, equals(InvoiceType.quote));

    // Double conversion of a non-quote is rejected.
    final bad = await repo.convertQuoteToInvoice(sale.id);
    expect(bad.isSuccess, isFalse);
  });
}
