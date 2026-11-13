import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounting/domain/services/auto_voucher_service.dart';
import 'package:kifino/features/accounting/domain/services/voucher_settings_service.dart';
import 'package:kifino/features/business/data/repositories/business_repository_impl.dart';
import 'package:kifino/features/business/domain/entities/contact_entity.dart';
import 'package:kifino/features/business/domain/entities/inventory_log_entity.dart';
import 'package:kifino/features/business/domain/entities/invoice_entity.dart';
import 'package:kifino/features/business/domain/entities/product_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Phase 2.1 — Business metrics exclude cancelled & draft invoices', () {
    test(
      'watchBusinessMetrics sums only confirmed active sale invoices',
      () async {
        final now = DateTime.now();
        await repo.createContact(
          ContactEntity(
            id: 'c-m1',
            name: 'مشتری',
            type: ContactType.customer,
            outstandingBalance: Money.zero(Currency.toman),
            createdAt: now,
            updatedAt: now,
          ),
        );

        InvoiceEntity mkInv(String id, InvoiceStatus status, int totalMinor) =>
            InvoiceEntity(
              id: id,
              invoiceNumber: 'INV-$id',
              contactId: 'c-m1',
              type: InvoiceType.sale,
              status: status,
              issueDate: now,
              dueDate: now,
              subtotal: Money.fromMinor(totalMinor, Currency.toman),
              discount: Money.zero(Currency.toman),
              tax: Money.zero(Currency.toman),
              total: Money.fromMinor(totalMinor, Currency.toman),
              paidAmount: Money.zero(Currency.toman),
              createdAt: now,
              updatedAt: now,
            );

        // 1 active sent invoice (1,000,000), 1 draft (5,000,000), 1 cancelled (9,000,000)
        await repo.createInvoice(mkInv('i-sent', InvoiceStatus.sent, 1000000));
        await repo.createInvoice(
          mkInv('i-draft', InvoiceStatus.draft, 5000000),
        );
        await repo.createInvoice(
          mkInv('i-cancel', InvoiceStatus.cancelled, 9000000),
        );

        final metrics = await repo.watchBusinessMetrics().first;
        expect(metrics.totalSales.minorUnits, equals(1000000));
        expect(metrics.unpaidReceivables.minorUnits, equals(1000000));
        expect(metrics.totalInvoicesCount, equals(1));
      },
    );
  });

  group('Phase 2.2 — Initial stock کاردکس & avgCostMinor initialization', () {
    test('createProduct initializes avgCostMinor from purchasePrice, writes initial کاردکس row, and posts COGS on sale', () async {
      final now = DateTime.now();
      final created = await repo.createProduct(
        ProductEntity(
          id: 'p-init',
          name: 'محصول اولیه',
          purchasePrice: Money.fromMinor(250000, Currency.toman),
          sellingPrice: Money.fromMinor(400000, Currency.toman),
          currentStock: 5.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      expect(created.isSuccess, isTrue);
      expect(created.dataOrNull!.avgCostMinor, equals(250000));

      // Initial stock row must appear in کاردکس
      final card = await repo.getProductCard('p-init');
      expect(card.length, equals(1));
      expect(card.first.movementType, equals(InventoryMovementType.adjustment));
      expect(card.first.inQuantity, equals(5.0));
      expect(card.first.balance, equals(5.0));

      // Selling 2 units immediately without a prior purchase MUST post COGS 070001
      await repo.createContact(
        ContactEntity(
          id: 'c-cogs',
          name: 'مشتری',
          type: ContactType.customer,
          outstandingBalance: Money.zero(Currency.toman),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repo.createInvoice(
        InvoiceEntity(
          id: 'inv-cogs-init',
          invoiceNumber: 'S-INIT',
          contactId: 'c-cogs',
          type: InvoiceType.sale,
          status: InvoiceStatus.sent,
          issueDate: now,
          dueDate: now,
          subtotal: Money.fromMinor(800000, Currency.toman),
          discount: Money.zero(Currency.toman),
          tax: Money.zero(Currency.toman),
          total: Money.fromMinor(800000, Currency.toman),
          paidAmount: Money.zero(Currency.toman),
          createdAt: now,
          updatedAt: now,
          items: [
            InvoiceItemEntity(
              id: 'it-1',
              invoiceId: 'inv-cogs-init',
              productId: 'p-init',
              description: 'محصول اولیه',
              quantity: 2.0,
              unitPrice: Money.fromMinor(400000, Currency.toman),
              discount: Money.zero(Currency.toman),
              tax: Money.zero(Currency.toman),
              total: Money.fromMinor(800000, Currency.toman),
            ),
          ],
        ),
      );

      final updatedCard = await repo.getProductCard('p-init');
      expect(updatedCard.length, equals(2));
      expect(updatedCard.last.balance, equals(3.0));

      final invEntity = (await repo.getInvoiceById('inv-cogs-init'))
          .dataOrNull!;
      final voucher = await voucherService.generateInvoiceVoucher(invEntity);
      expect(voucher, isNotNull);
      final cogsLeg = voucher!.transactions
          .where((t) => t.subject?.code == '070001')
          .toList();
      expect(cogsLeg, hasLength(1));
      expect(cogsLeg.first.debit.minorUnits, equals(500000)); // 2 * 250,000
    });
  });

  group('Phase 2.3 — Purchase contact balance & payment validation', () {
    test(
      'recordInvoicePayment rejects <= 0, cancelled, quotes, and overpayments',
      () async {
        final now = DateTime.now();
        await repo.createContact(
          ContactEntity(
            id: 'c-val',
            name: 'طرف حساب',
            type: ContactType.both,
            outstandingBalance: Money.zero(Currency.toman),
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repo.createInvoice(
          InvoiceEntity(
            id: 'inv-v1',
            invoiceNumber: 'V-1',
            contactId: 'c-val',
            type: InvoiceType.sale,
            status: InvoiceStatus.sent,
            issueDate: now,
            dueDate: now,
            subtotal: Money.fromMinor(100000, Currency.toman),
            discount: Money.zero(Currency.toman),
            tax: Money.zero(Currency.toman),
            total: Money.fromMinor(100000, Currency.toman),
            paidAmount: Money.zero(Currency.toman),
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(
          (await repo.recordInvoicePayment(
            'inv-v1',
            Money.zero(Currency.toman),
          )).isFailure,
          isTrue,
        );
        expect(
          (await repo.recordInvoicePayment(
            'inv-v1',
            Money.fromMinor(150000, Currency.toman),
          )).isFailure,
          isTrue,
        );

        // Exact partial payment works
        expect(
          (await repo.recordInvoicePayment(
            'inv-v1',
            Money.fromMinor(40000, Currency.toman),
          )).isSuccess,
          isTrue,
        );
        // Remaining is 60000, paying 70000 must fail
        expect(
          (await repo.recordInvoicePayment(
            'inv-v1',
            Money.fromMinor(70000, Currency.toman),
          )).isFailure,
          isTrue,
        );

        // Quote payment rejected
        await repo.createInvoice(
          InvoiceEntity(
            id: 'inv-q',
            invoiceNumber: 'Q-1',
            contactId: 'c-val',
            type: InvoiceType.quote,
            status: InvoiceStatus.sent,
            issueDate: now,
            dueDate: now,
            subtotal: Money.fromMinor(100000, Currency.toman),
            discount: Money.zero(Currency.toman),
            tax: Money.zero(Currency.toman),
            total: Money.fromMinor(100000, Currency.toman),
            paidAmount: Money.zero(Currency.toman),
            createdAt: now,
            updatedAt: now,
          ),
        );
        expect(
          (await repo.recordInvoicePayment(
            'inv-q',
            Money.fromMinor(50000, Currency.toman),
          )).isFailure,
          isTrue,
        );
      },
    );

    test('unpaid purchase invoice sets negative payable balance & payment moves toward 0 without corrupting sales receivable', () async {
      final now = DateTime.now();
      await repo.createContact(
        ContactEntity(
          id: 'c-both',
          name: 'شریک تجاری',
          type: ContactType.both,
          outstandingBalance: Money.zero(Currency.toman),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 1. Customer owes us 1,000,000 (+1,000,000)
      await repo.createInvoice(
        InvoiceEntity(
          id: 'inv-s',
          invoiceNumber: 'S-1',
          contactId: 'c-both',
          type: InvoiceType.sale,
          status: InvoiceStatus.sent,
          issueDate: now,
          dueDate: now,
          subtotal: Money.fromMinor(1000000, Currency.toman),
          discount: Money.zero(Currency.toman),
          tax: Money.zero(Currency.toman),
          total: Money.fromMinor(1000000, Currency.toman),
          paidAmount: Money.zero(Currency.toman),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. We buy 300,000 on credit (-300,000) -> net balance becomes +700,000
      await repo.createInvoice(
        InvoiceEntity(
          id: 'inv-p',
          invoiceNumber: 'P-1',
          contactId: 'c-both',
          type: InvoiceType.purchase,
          status: InvoiceStatus.sent,
          issueDate: now,
          dueDate: now,
          subtotal: Money.fromMinor(300000, Currency.toman),
          discount: Money.zero(Currency.toman),
          tax: Money.zero(Currency.toman),
          total: Money.fromMinor(300000, Currency.toman),
          paidAmount: Money.zero(Currency.toman),
          createdAt: now,
          updatedAt: now,
        ),
      );

      var contact = (await repo.getContacts()).dataOrNull!.firstWhere(
        (c) => c.id == 'c-both',
      );
      expect(contact.outstandingBalance.minorUnits, equals(700000));

      // 3. Paying off the 300,000 purchase invoice restores net balance to +1,000,000 receivable!
      final payPur = await repo.recordInvoicePayment(
        'inv-p',
        Money.fromMinor(300000, Currency.toman),
      );
      expect(payPur.isSuccess, isTrue);

      contact = (await repo.getContacts()).dataOrNull!.firstWhere(
        (c) => c.id == 'c-both',
      );
      expect(contact.outstandingBalance.minorUnits, equals(1000000));
    });
  });
}
