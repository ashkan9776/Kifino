import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/business/data/repositories/business_repository_impl.dart';
import 'package:kifino/features/business/domain/entities/contact_entity.dart';
import 'package:kifino/features/business/domain/entities/inventory_log_entity.dart';
import 'package:kifino/features/business/domain/entities/invoice_entity.dart';
import 'package:kifino/features/business/domain/entities/product_entity.dart';

void main() {
  late AppDatabase db;
  late BusinessRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BusinessRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BusinessRepositoryImpl Tests', () {
    test('Creates contact, updates and watches contacts correctly', () async {
      final now = DateTime.now();
      final contact = ContactEntity(
        id: 'c-1',
        name: 'شرکت رایان پژواک',
        companyName: 'رایان پژواک',
        type: ContactType.customer,
        phone: '09121112233',
        outstandingBalance: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
      );

      final createRes = await repo.createContact(contact);
      expect(createRes.isSuccess, isTrue);

      final list = await repo.getContacts();
      expect(list.dataOrNull?.length, equals(1));
      expect(list.dataOrNull?.first.name, equals('شرکت رایان پژواک'));
    });

    test('Creates product and adjusts stock with inventory logs', () async {
      final now = DateTime.now();
      final product = ProductEntity(
        id: 'p-1',
        name: 'لپ‌تاپ گیمینگ',
        purchasePrice: Money.fromMinor(500000000, Currency.irr),
        sellingPrice: Money.fromMinor(650000000, Currency.irr),
        currentStock: 5.0,
        lowStockThreshold: 2.0,
        createdAt: now,
        updatedAt: now,
      );

      final createRes = await repo.createProduct(product);
      expect(createRes.isSuccess, isTrue);

      // Adjust stock (purchase 3 more)
      final adjustRes = await repo.adjustStock(
        productId: 'p-1',
        changeQuantity: 3.0,
        type: InventoryMovementType.purchase,
        notes: 'خرید پارت جدید',
      );
      expect(adjustRes.isSuccess, isTrue);

      final products = await repo.getProducts();
      expect(products.dataOrNull?.first.currentStock, equals(8.0));
      expect(products.dataOrNull?.first.isLowStock, isFalse);
    });

    test('Creates sales invoice: automatically deducts stock and increases customer balance', () async {
      final now = DateTime.now();

      // 1. Create Customer
      await repo.createContact(
        ContactEntity(
          id: 'cust-1',
          name: 'مشتری ممتاز',
          type: ContactType.customer,
          outstandingBalance: Money.zero(Currency.irr),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Create Product
      await repo.createProduct(
        ProductEntity(
          id: 'prod-1',
          name: 'مانیتور ۲۷ اینچ',
          purchasePrice: Money.fromMinor(100000000, Currency.irr),
          sellingPrice: Money.fromMinor(140000000, Currency.irr),
          currentStock: 10.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 3. Issue Invoice for 2 monitors
      final item = InvoiceItemEntity.calculate(
        id: 'item-1',
        invoiceId: 'inv-1',
        productId: 'prod-1',
        description: 'مانیتور ۲۷ اینچ',
        quantity: 2,
        unitPrice: Money.fromMinor(140000000, Currency.irr),
        taxRate: 0.10, // 10%
      );

      final invoice = InvoiceEntity(
        id: 'inv-1',
        invoiceNumber: 'INV-101',
        contactId: 'cust-1',
        type: InvoiceType.sale,
        status: InvoiceStatus.sent,
        issueDate: now,
        dueDate: now.add(const Duration(days: 7)),
        subtotal: item.unitPrice * item.quantity,
        discount: item.discount,
        tax: item.tax,
        total: item.total,
        paidAmount: Money.zero(Currency.irr),
        items: [item],
        createdAt: now,
        updatedAt: now,
      );

      final invoiceRes = await repo.createInvoice(invoice);
      expect(invoiceRes.isSuccess, isTrue);

      // Verify stock deducted from 10 to 8
      final prods = await repo.getProducts();
      expect(prods.dataOrNull?.first.currentStock, equals(8.0));

      // Verify customer outstanding balance increased by total invoice amount
      final contacts = await repo.getContacts();
      expect(
        contacts.dataOrNull?.first.outstandingBalance.minorUnits,
        equals(invoice.total.minorUnits),
      );

      // 4. Pay partial invoice
      final partialPayment = Money.fromMinor(100000000, Currency.irr);
      final payRes = await repo.recordInvoicePayment('inv-1', partialPayment);
      expect(payRes.isSuccess, isTrue);

      final updatedInv = await repo.getInvoiceById('inv-1');
      expect(
        updatedInv.dataOrNull?.status,
        equals(InvoiceStatus.partiallyPaid),
      );
      expect(
        updatedInv.dataOrNull?.paidAmount.minorUnits,
        equals(partialPayment.minorUnits),
      );

      // Customer balance reduced accordingly
      final updatedContacts = await repo.getContacts();
      expect(
        updatedContacts.dataOrNull?.first.outstandingBalance.minorUnits,
        equals(invoice.total.minorUnits - partialPayment.minorUnits),
      );
    });
  });

  group('Phase 3 — warehouse & کاردکس', () {
    test('purchase invoice ADDS stock and writes purchase movement', () async {
      final now = DateTime.now();
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
      await repo.createProduct(
        ProductEntity(
          id: 'p-pur',
          name: 'هارد اکسترنال',
          purchasePrice: Money.fromMinor(5000000, Currency.irr),
          sellingPrice: Money.fromMinor(6500000, Currency.irr),
          currentStock: 2.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final invoice = InvoiceEntity(
        id: 'inv-pur-1',
        invoiceNumber: 'PUR-1001',
        contactId: 'sup-1',
        type: InvoiceType.purchase,
        status: InvoiceStatus.paid,
        issueDate: now,
        dueDate: now,
        subtotal: Money.fromMinor(10000000, Currency.irr),
        discount: Money.fromMinor(0, Currency.irr),
        tax: Money.fromMinor(0, Currency.irr),
        total: Money.fromMinor(10000000, Currency.irr),
        paidAmount: Money.fromMinor(10000000, Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [
          InvoiceItemEntity(
            id: 'it-1',
            invoiceId: 'inv-pur-1',
            productId: 'p-pur',
            description: 'هارد',
            quantity: 3,
            unitPrice: Money.fromMinor(10000000, Currency.irr),
            discount: Money.fromMinor(0, Currency.irr),
            tax: Money.fromMinor(0, Currency.irr),
            total: Money.fromMinor(10000000, Currency.irr),
          ),
        ],
      );

      final res = await repo.createInvoice(invoice);
      expect(res.isSuccess, isTrue);

      final products = await repo.getProducts();
      expect(products.dataOrNull!.first.currentStock, equals(5.0)); // 2 + 3
    });

    test(
      'getProductCard returns chronological movements with running balance',
      () async {
        final now = DateTime.now();
        await repo.createProduct(
          ProductEntity(
            id: 'p-card',
            name: 'کالا کاردکس',
            purchasePrice: Money.fromMinor(100000, Currency.irr),
            sellingPrice: Money.fromMinor(150000, Currency.irr),
            currentStock: 10.0,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repo.adjustStock(
          productId: 'p-card',
          changeQuantity: 5.0,
          type: InventoryMovementType.purchase,
          notes: 'ورود',
        );
        await repo.adjustStock(
          productId: 'p-card',
          changeQuantity: -2.0,
          type: InventoryMovementType.loss,
          notes: 'ضایعات',
        );

        final card = await repo.getProductCard('p-card');
        expect(card.length, equals(2));
        expect(card[0].inQuantity, equals(5.0));
        expect(card[0].balance, equals(5.0));
        expect(card[1].outQuantity, equals(2.0));
        expect(card[1].balance, equals(3.0));
      },
    );

    test(
      'P0-3: purchase 10 -> delete purchase invoice -> stock reverts to 0',
      () async {
        final now = DateTime.now();
        await repo.createContact(
          ContactEntity(
            id: 'sup-p03',
            name: 'تأمین‌کننده P0-3',
            type: ContactType.supplier,
            outstandingBalance: Money.zero(Currency.irr),
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repo.createProduct(
          ProductEntity(
            id: 'p-p03-1',
            name: 'کالای خرید',
            purchasePrice: Money.fromMinor(1000, Currency.irr),
            sellingPrice: Money.fromMinor(1500, Currency.irr),
            currentStock: 0.0,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final invoice = InvoiceEntity(
          id: 'inv-pur-p03',
          invoiceNumber: 'PUR-001',
          contactId: 'sup-p03',
          type: InvoiceType.purchase,
          status: InvoiceStatus.paid,
          issueDate: now,
          dueDate: now,
          subtotal: Money.fromMinor(10000, Currency.irr),
          discount: Money.zero(Currency.irr),
          tax: Money.zero(Currency.irr),
          total: Money.fromMinor(10000, Currency.irr),
          paidAmount: Money.fromMinor(10000, Currency.irr),
          createdAt: now,
          updatedAt: now,
          items: [
            InvoiceItemEntity(
              id: 'it-pur-1',
              invoiceId: 'inv-pur-p03',
              productId: 'p-p03-1',
              description: 'کالای خرید',
              quantity: 10,
              unitPrice: Money.fromMinor(1000, Currency.irr),
              discount: Money.zero(Currency.irr),
              tax: Money.zero(Currency.irr),
              total: Money.fromMinor(10000, Currency.irr),
            ),
          ],
        );

        final createRes = await repo.createInvoice(invoice);
        expect(createRes.isSuccess, isTrue);

        final prodsAfterCreate = await repo.getProducts();
        expect(
          prodsAfterCreate.dataOrNull!
              .firstWhere((p) => p.id == 'p-p03-1')
              .currentStock,
          equals(10.0),
        );

        // Now delete the purchase invoice
        final delRes = await repo.deleteInvoice('inv-pur-p03');
        expect(delRes.isSuccess, isTrue);

        // Stock must revert back to 0.0!
        final prodsAfterDelete = await repo.getProducts();
        expect(
          prodsAfterDelete.dataOrNull!
              .firstWhere((p) => p.id == 'p-p03-1')
              .currentStock,
          equals(0.0),
        );
      },
    );

    test('P0-3: sale + accounting voucher -> delete invoice -> voucher voided and stock reverted', () async {
      final now = DateTime.now();
      await repo.createContact(
        ContactEntity(
          id: 'cust-p03',
          name: 'مشتری P0-3',
          type: ContactType.customer,
          outstandingBalance: Money.zero(Currency.irr),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repo.createProduct(
        ProductEntity(
          id: 'p-p03-sale',
          name: 'کالای فروش',
          purchasePrice: Money.fromMinor(1000, Currency.irr),
          sellingPrice: Money.fromMinor(2000, Currency.irr),
          currentStock: 10.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final invoice = InvoiceEntity(
        id: 'inv-sale-p03',
        invoiceNumber: 'SALE-001',
        contactId: 'cust-p03',
        type: InvoiceType.sale,
        status: InvoiceStatus.sent,
        issueDate: now,
        dueDate: now,
        subtotal: Money.fromMinor(8000, Currency.irr),
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: Money.fromMinor(8000, Currency.irr),
        paidAmount: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [
          InvoiceItemEntity(
            id: 'it-sale-1',
            invoiceId: 'inv-sale-p03',
            productId: 'p-p03-sale',
            description: 'کالای فروش',
            quantity: 4,
            unitPrice: Money.fromMinor(2000, Currency.irr),
            discount: Money.zero(Currency.irr),
            tax: Money.zero(Currency.irr),
            total: Money.fromMinor(8000, Currency.irr),
          ),
        ],
      );

      final createRes = await repo.createInvoice(invoice);
      expect(createRes.isSuccess, isTrue);

      // Stock deducted to 6
      expect(
        (await repo.getProducts()).dataOrNull!
            .firstWhere((p) => p.id == 'p-p03-sale')
            .currentStock,
        equals(6.0),
      );

      // Simulate accounting document created for this invoice
      await db
          .into(db.accountingDocumentsTable)
          .insert(
            AccountingDocumentsTableCompanion.insert(
              id: 'doc-inv-p03',
              number: 101,
              date: now.millisecondsSinceEpoch,
              title: 'سند فاکتور SALE-001',
              status: 'approved',
              referenceType: const Value('invoice'),
              referenceId: const Value('inv-sale-p03'),
              createdAt: now.millisecondsSinceEpoch,
              updatedAt: now.millisecondsSinceEpoch,
            ),
          );

      // Now delete invoice
      final delRes = await repo.deleteInvoice('inv-sale-p03');
      expect(delRes.isSuccess, isTrue);

      // 1. Stock reverted back to 10
      expect(
        (await repo.getProducts()).dataOrNull!
            .firstWhere((p) => p.id == 'p-p03-sale')
            .currentStock,
        equals(10.0),
      );

      // 2. Customer balance reverted to 0
      expect(
        (await repo.getContacts()).dataOrNull!
            .firstWhere((c) => c.id == 'cust-p03')
            .outstandingBalance
            .minorUnits,
        equals(0),
      );

      // 3. Accounting voucher must be deleted/voided (deletedAt != null)!
      final voucher = await (db.select(
        db.accountingDocumentsTable,
      )..where((t) => t.id.equals('doc-inv-p03'))).getSingle();
      expect(voucher.deletedAt, isNotNull);
    });

    test('P0-3: editing purchase invoice correctly updates stock', () async {
      final now = DateTime.now();
      await repo.createContact(
        ContactEntity(
          id: 'sup-edit',
          name: 'تأمین‌کننده ویرایش',
          type: ContactType.supplier,
          outstandingBalance: Money.zero(Currency.irr),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repo.createProduct(
        ProductEntity(
          id: 'p-edit-pur',
          name: 'کالای ویرایش خرید',
          purchasePrice: Money.fromMinor(1000, Currency.irr),
          sellingPrice: Money.fromMinor(1500, Currency.irr),
          currentStock: 0.0,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final originalInvoice = InvoiceEntity(
        id: 'inv-pur-edit',
        invoiceNumber: 'PUR-EDIT',
        contactId: 'sup-edit',
        type: InvoiceType.purchase,
        status: InvoiceStatus.paid,
        issueDate: now,
        dueDate: now,
        subtotal: Money.fromMinor(10000, Currency.irr),
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: Money.fromMinor(10000, Currency.irr),
        paidAmount: Money.fromMinor(10000, Currency.irr),
        createdAt: now,
        updatedAt: now,
        items: [
          InvoiceItemEntity(
            id: 'it-pe-1',
            invoiceId: 'inv-pur-edit',
            productId: 'p-edit-pur',
            description: 'کالا',
            quantity: 10,
            unitPrice: Money.fromMinor(1000, Currency.irr),
            discount: Money.zero(Currency.irr),
            tax: Money.zero(Currency.irr),
            total: Money.fromMinor(10000, Currency.irr),
          ),
        ],
      );

      await repo.createInvoice(originalInvoice);
      expect(
        (await repo.getProducts()).dataOrNull!
            .firstWhere((p) => p.id == 'p-edit-pur')
            .currentStock,
        equals(10.0),
      );

      // Update purchase quantity from 10 to 6
      final updatedInvoice = originalInvoice.copyWith(
        items: [
          InvoiceItemEntity(
            id: 'it-pe-2',
            invoiceId: 'inv-pur-edit',
            productId: 'p-edit-pur',
            description: 'کالا',
            quantity: 6,
            unitPrice: Money.fromMinor(1000, Currency.irr),
            discount: Money.zero(Currency.irr),
            tax: Money.zero(Currency.irr),
            total: Money.fromMinor(6000, Currency.irr),
          ),
        ],
        subtotal: Money.fromMinor(6000, Currency.irr),
        total: Money.fromMinor(6000, Currency.irr),
      );

      final updateRes = await repo.updateInvoice(updatedInvoice);
      expect(updateRes.isSuccess, isTrue);

      // Stock should now be 6.0 (not 10.0 or 16.0)!
      expect(
        (await repo.getProducts()).dataOrNull!
            .firstWhere((p) => p.id == 'p-edit-pur')
            .currentStock,
        equals(6.0),
      );
    });
  });
}
