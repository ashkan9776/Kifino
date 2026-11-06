import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/business/data/repositories/business_repository_impl.dart';
import 'package:kifino/features/business/domain/entities/contact_entity.dart';
import 'package:kifino/features/business/domain/entities/invoice_entity.dart';

/// Phase 1-4 regression: گزارش سنی — open invoices bucketed per contact by
/// days past due (جاری / 1-30 / 31-60 / 61-90 / +90).
void main() {
  late AppDatabase db;
  late BusinessRepositoryImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BusinessRepositoryImpl(db);
  });

  tearDown(() async => db.close());

  InvoiceEntity saleInvoice({
    required String id,
    required String contactId,
    required int totalMinor,
    required DateTime dueDate,
  }) {
    final unit = Money.fromMinor(totalMinor, Currency.irr);
    return InvoiceEntity(
      id: id,
      invoiceNumber: 'S-$id',
      contactId: contactId,
      type: InvoiceType.sale,
      status: InvoiceStatus.sent,
      issueDate: dueDate.subtract(const Duration(days: 10)),
      dueDate: dueDate,
      subtotal: unit,
      discount: Money.zero(Currency.irr),
      tax: Money.zero(Currency.irr),
      total: unit,
      paidAmount: Money.zero(Currency.irr),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  test('buckets by days past due and totals per contact', () async {
    final now = DateTime.now();
    await repo.createContact(
      ContactEntity(
        id: 'c-1',
        name: 'مشتری الف',
        type: ContactType.customer,
        outstandingBalance: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repo.createContact(
      ContactEntity(
        id: 'c-2',
        name: 'مشتری ب',
        type: ContactType.customer,
        outstandingBalance: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
      ),
    );

    // الف: current (due in 10d) 2M + 45d overdue 1M
    await repo.createInvoice(
      saleInvoice(
        id: 'a1',
        contactId: 'c-1',
        totalMinor: 2000000,
        dueDate: now.add(const Duration(days: 10)),
      ),
    );
    await repo.createInvoice(
      saleInvoice(
        id: 'a2',
        contactId: 'c-1',
        totalMinor: 1000000,
        dueDate: now.subtract(const Duration(days: 45)),
      ),
    );
    // ب: 100d overdue 3M
    await repo.createInvoice(
      saleInvoice(
        id: 'b1',
        contactId: 'c-2',
        totalMinor: 3000000,
        dueDate: now.subtract(const Duration(days: 100)),
      ),
    );
    // Fully paid → excluded entirely.
    final paid = saleInvoice(
      id: 'a3',
      contactId: 'c-1',
      totalMinor: 9999999,
      dueDate: now.subtract(const Duration(days: 200)),
    );
    await repo.createInvoice(
      paid.copyWith(
        paidAmount: paid.total,
        status: InvoiceStatus.paid,
      ),
    );

    final res = await repo.getAgingReport(receivables: true);
    final entries = res.dataOrNull!;
    expect(entries, hasLength(2));

    // Sorted by total desc: ب (3M) first, الف (3M)... equal → order stable.
    final a = entries.firstWhere((e) => e.contactId == 'c-1');
    final b = entries.firstWhere((e) => e.contactId == 'c-2');

    expect(a.currentMinor, equals(2000000));
    expect(a.days31To60Minor, equals(1000000)); // 45 days
    expect(a.totalMinor, equals(3000000));

    expect(b.days90PlusMinor, equals(3000000)); // 100 days
    expect(b.totalMinor, equals(3000000));
  });

  test('payables side buckets purchase invoices instead', () async {
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
    final unit = Money.fromMinor(4000000, Currency.irr);
    await repo.createInvoice(
      InvoiceEntity(
        id: 'pur-1',
        invoiceNumber: 'P-1',
        contactId: 'sup-1',
        type: InvoiceType.purchase,
        status: InvoiceStatus.sent,
        issueDate: now.subtract(const Duration(days: 40)),
        dueDate: now.subtract(const Duration(days: 20)),
        subtotal: unit,
        discount: Money.zero(Currency.irr),
        tax: Money.zero(Currency.irr),
        total: unit,
        paidAmount: Money.zero(Currency.irr),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final receivables = await repo.getAgingReport(receivables: true);
    expect(receivables.dataOrNull, isEmpty);

    final payables = await repo.getAgingReport(receivables: false);
    final entry = payables.dataOrNull!.single;
    expect(entry.contactName, equals('تأمین‌کننده'));
    expect(entry.days1To30Minor, equals(4000000)); // 20 days past due
  });
}
