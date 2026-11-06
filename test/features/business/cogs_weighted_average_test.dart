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

/// Phase 1-1 regression: weighted-average COGS. Purchase invoices maintain
/// products.avgCostMinor, and the SALE voucher posts a complete pair —
/// DR بهای تمام‌شده (070001) / CR موجودی کالا (015002) — so the inventory
/// account actually moves and the P&L carries cost of goods.
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

  Future<ProductEntity> seedProduct({
    String id = 'p-1',
    double stock = 0,
  }) async {
    final now = DateTime.now();
    final product = ProductEntity(
      id: id,
      name: 'کالای تست',
      purchasePrice: Money.fromMinor(1000000, Currency.irr),
      sellingPrice: Money.fromMinor(1500000, Currency.irr),
      currentStock: stock,
      createdAt: now,
      updatedAt: now,
    );
    final res = await repo.createProduct(product);
    return res.dataOrNull!;
  }

  InvoiceItemEntity item(
    String invoiceId,
    String productId,
    double qty,
    int unitPriceMinor,
  ) {
    final unit = Money.fromMinor(unitPriceMinor, Currency.irr);
    return InvoiceItemEntity(
      id: 'it-$productId-$qty',
      invoiceId: invoiceId,
      productId: productId,
      description: 'ردیف',
      quantity: qty,
      unitPrice: unit,
      discount: Money.zero(Currency.irr),
      tax: Money.zero(Currency.irr),
      total: unit * qty,
    );
  }

  test('purchase invoice updates the weighted-average cost', () async {
    final now = DateTime.now();
    await seedProduct();
    await repo.createContact(
      ContactEntity(
        id: 'sup-1',
        name: 'تأمین‌کننده',
        type: ContactType.supplier,
        outstandingBalance: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // Purchase 2 @ 1,000,000 → avg = 1,000,000
    await repo.createInvoice(
      InvoiceEntity(
        id: 'inv-pur-1',
        invoiceNumber: 'PUR-1',
        contactId: 'sup-1',
        type: InvoiceType.purchase,
        status: InvoiceStatus.paid,
        issueDate: now,
        dueDate: now,
        subtotal: Money.fromMinor(2000000, Currency.irr),
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: Money.fromMinor(2000000, Currency.irr),
        paidAmount: Money.fromMinor(2000000, Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [item('inv-pur-1', 'p-1', 2, 1000000)],
      ),
    );

    var products = await repo.getProducts();
    expect(products.dataOrNull!.first.avgCostMinor, equals(1000000));

    // Purchase 3 @ 2,000,000 → avg = (2×1M + 3×2M) / 5 = 1,600,000
    await repo.createInvoice(
      InvoiceEntity(
        id: 'inv-pur-2',
        invoiceNumber: 'PUR-2',
        contactId: 'sup-1',
        type: InvoiceType.purchase,
        status: InvoiceStatus.paid,
        issueDate: now,
        dueDate: now,
        subtotal: Money.fromMinor(6000000, Currency.irr),
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: Money.fromMinor(6000000, Currency.irr),
        paidAmount: Money.fromMinor(6000000, Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [item('inv-pur-2', 'p-1', 3, 2000000)],
      ),
    );

    products = await repo.getProducts();
    expect(products.dataOrNull!.first.avgCostMinor, equals(1600000));
    expect(products.dataOrNull!.first.currentStock, equals(5.0));
  });

  test('sale voucher carries the COGS pair and stays balanced', () async {
    final now = DateTime.now();
    await seedProduct(); // stock 0 — the purchase below defines the avg
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

    // Give the product an avg cost of 1,000,000 via a purchase.
    await repo.createInvoice(
      InvoiceEntity(
        id: 'inv-pur-0',
        invoiceNumber: 'PUR-0',
        contactId: 'cust-1',
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
        items: [item('inv-pur-0', 'p-1', 5, 1000000)],
      ),
    );

    // Sell 2 units.
    final qty = 2.0;
    final unit = Money.fromMinor(1500000, Currency.irr);
    await repo.createInvoice(
      InvoiceEntity(
        id: 'inv-sale-1',
        invoiceNumber: 'SALE-1',
        contactId: 'cust-1',
        type: InvoiceType.sale,
        status: InvoiceStatus.sent,
        issueDate: now,
        dueDate: now,
        subtotal: unit * qty,
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: unit * qty,
        paidAmount: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [item('inv-sale-1', 'p-1', qty, 1500000)],
      ),
    );

    await voucherService.generateInvoiceVoucher(
      (await repo.getInvoiceById('inv-sale-1')).dataOrNull!,
    );

    final docs = await accountingRepo.getDocuments();
    final voucher = docs.firstWhere((d) => d.referenceId == 'inv-sale-1');
    final cogsRows = voucher.transactions.where(
      (t) => t.subject?.code == '070001',
    );
    final invRows = voucher.transactions.where(
      (t) => t.subject?.code == '015002',
    );

    // DR COGS 2 × 1,000,000 = 2,000,000
    expect(cogsRows, hasLength(1));
    expect(cogsRows.first.debit.minorUnits, equals(2000000));
    // CR inventory — same amount, balanced pair
    expect(invRows, hasLength(1));
    expect(invRows.first.credit.minorUnits, equals(2000000));
    expect(voucher.isBalanced, isTrue);
  });

  test('sale of a never-purchased product omits COGS legs (still balanced)',
      () async {
    final now = DateTime.now();
    await seedProduct(stock: 3); // avgCostMinor = 0
    await repo.createContact(
      ContactEntity(
        id: 'cust-2',
        name: 'مشتری دو',
        type: ContactType.customer,
        outstandingBalance: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final unit = Money.fromMinor(900000, Currency.irr);
    await repo.createInvoice(
      InvoiceEntity(
        id: 'inv-sale-2',
        invoiceNumber: 'SALE-2',
        contactId: 'cust-2',
        type: InvoiceType.sale,
        status: InvoiceStatus.sent,
        issueDate: now,
        dueDate: now,
        subtotal: unit,
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: unit,
        paidAmount: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [item('inv-sale-2', 'p-1', 1, 900000)],
      ),
    );

    await voucherService.generateInvoiceVoucher(
      (await repo.getInvoiceById('inv-sale-2')).dataOrNull!,
    );

    final docs = await accountingRepo.getDocuments();
    final voucher = docs.firstWhere((d) => d.referenceId == 'inv-sale-2');
    expect(
      voucher.transactions.where((t) => t.subject?.code == '070001'),
      isEmpty,
    );
    expect(voucher.isBalanced, isTrue);
  });

  test('کاردکس sale movement records the avg cost as costPerUnit', () async {
    final now = DateTime.now();
    await seedProduct(); // stock 0 — avg comes purely from the purchase
    await repo.createContact(
      ContactEntity(
        id: 'cust-3',
        name: 'مشتری سه',
        type: ContactType.customer,
        outstandingBalance: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
      ),
    );
    // Direct stock injection via adjustStock leaves avg at 0 — buy first.
    await repo.createInvoice(
      InvoiceEntity(
        id: 'inv-pur-9',
        invoiceNumber: 'PUR-9',
        contactId: 'cust-3',
        type: InvoiceType.purchase,
        status: InvoiceStatus.paid,
        issueDate: now,
        dueDate: now,
        subtotal: Money.fromMinor(2000000, Currency.irr),
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: Money.fromMinor(2000000, Currency.irr),
        paidAmount: Money.fromMinor(2000000, Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [item('inv-pur-9', 'p-1', 2, 1000000)],
      ),
    );

    final unit = Money.fromMinor(1800000, Currency.irr);
    await repo.createInvoice(
      InvoiceEntity(
        id: 'inv-sale-9',
        invoiceNumber: 'SALE-9',
        contactId: 'cust-3',
        type: InvoiceType.sale,
        status: InvoiceStatus.sent,
        issueDate: now,
        dueDate: now,
        subtotal: unit,
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: unit,
        paidAmount: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [item('inv-sale-9', 'p-1', 1, 1800000)],
      ),
    );

    final card = await repo.getProductCard('p-1');
    final saleEntry = card.lastWhere((e) => e.outQuantity > 0);
    expect(saleEntry.outQuantity, equals(1.0));
    // The movement's cost reference is the weighted avg, not list price.
    final rows = await (db.select(db.inventoryLogsTable)
          ..where((t) => t.referenceId.equals('inv-sale-9')))
        .get();
    expect(rows.single.costPerUnitMinor, equals(1000000));
  });
}
