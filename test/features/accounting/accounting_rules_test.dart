import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_audit_entity.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_document_entity.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_transaction_entity.dart';

/// Phase-1 accounting rule tests: integrity lock, audit trail, period lock,
/// floating details (تفصیلی شناور) and fiscal year closing/opening.
void main() {
  late AppDatabase db;
  late AccountingRepositoryImpl repo;
  // REAL seeded subject ids — the close/open flow only sees postings made
  // against existing subjects (phantom string ids used to make this file's
  // close test vacuous).
  late String cashId; // 011 صندوق
  late String salesId; // 060 فروش

  AccountingDocumentEntity balancedDoc({
    String title = 'سند تست',
    DateTime? date,
    String status = 'approved',
  }) {
    final now = date ?? DateTime.now();
    return AccountingDocumentEntity(
      id: '',
      number: 0,
      date: now,
      title: title,
      status: DocumentStatus.fromCode(status),
      createdAt: now,
      updatedAt: now,
      transactions: [
        AccountingTransactionEntity(
          id: '',
          documentId: '',
          subjectId: cashId, // صندوق
          debit: Money.fromMinor(100000),
          credit: Money.fromMinor(0),
          description: 'بدهکار',
          rowOrder: 1,
          createdAt: now,
          updatedAt: now,
        ),
        AccountingTransactionEntity(
          id: '',
          documentId: '',
          subjectId: salesId, // فروش
          debit: Money.fromMinor(0),
          credit: Money.fromMinor(100000),
          description: 'بستانکار',
          rowOrder: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = AccountingRepositoryImpl(db);
    await repo.seedChartOfAccountsIfNotExists();
    cashId = (await repo.getSubjectByCode('011'))!.id;
    salesId = (await repo.getSubjectByCode('060'))!.id;
  });

  tearDown(() async => db.close());

  group('Phase 1 — document integrity lock', () {
    test('rejects unbalanced document with approved status', () async {
      final doc = AccountingDocumentEntity(
        id: '',
        number: 0,
        date: DateTime.now(),
        title: 'سند ناموازنه',
        status: DocumentStatus.approved,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        transactions: [
          AccountingTransactionEntity(
            id: '',
            documentId: '',
            subjectId: '011',
            debit: Money.fromMinor(100000),
            credit: Money.fromMinor(0),
            description: '',
            rowOrder: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      expect(() => repo.createDocument(doc), throwsStateError);
    });

    test('allows unbalanced draft but blocks approving it', () async {
      final draft = AccountingDocumentEntity(
        id: '',
        number: 0,
        date: DateTime.now(),
        title: 'پیش‌نویس ناموازنه',
        status: DocumentStatus.draft,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        transactions: [
          AccountingTransactionEntity(
            id: '',
            documentId: '',
            subjectId: '011',
            debit: Money.fromMinor(100000),
            credit: Money.fromMinor(0),
            description: '',
            rowOrder: 1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      );

      final saved = await repo.createDocument(draft);
      expect(saved.status, DocumentStatus.draft);

      expect(() => repo.approveDocument(saved.id), throwsStateError);
    });

    test('blocks editing and deleting a posted document', () async {
      final doc = await repo.createDocument(
        balancedDoc().copyWith(status: DocumentStatus.posted),
      );

      expect(
        () => repo.updateDocument(doc.copyWith(title: 'تغییر بعد از قطعی')),
        throwsStateError,
      );
      expect(() => repo.deleteDocument(doc.id), throwsStateError);
    });

    test('allows editing an approved document but logs it', () async {
      final doc = await repo.createDocument(balancedDoc());
      await repo.approveDocument(doc.id);

      final updated = await repo.updateDocument(
        doc.copyWith(title: 'ویرایش پس از تأیید'),
      );
      expect(updated.title, equals('ویرایش پس از تأیید'));

      final logs = await repo.watchAuditLogs().first;
      expect(logs.any((l) => l.action == AuditLogAction.update), isTrue);
    });
  });

  group('Phase 1 — audit trail', () {
    test('logs create, approve, update and delete with snapshots', () async {
      // Draft → approve: the real lifecycle. (approveDocument is now
      // idempotent for already-approved documents and logs nothing.)
      final created = await repo.createDocument(
        balancedDoc(title: 'سند حسابرسی', status: 'draft'),
      );
      await repo.approveDocument(created.id);
      await repo.updateDocument(
        created.copyWith(
          title: 'سند حسابرسی ویرایش‌شده',
          status: DocumentStatus.draft,
        ),
      );
      await repo.deleteDocument(created.id);

      final logs = await repo.watchAuditLogs().first;
      final actions = logs.map((l) => l.action).toList();

      expect(actions.contains(AuditLogAction.create), isTrue);
      expect(actions.contains(AuditLogAction.approve), isTrue);
      expect(actions.contains(AuditLogAction.update), isTrue);
      expect(actions.contains(AuditLogAction.delete), isTrue);

      final updateLog = logs.firstWhere(
        (l) => l.action == AuditLogAction.update,
      );
      expect(updateLog.beforeJson, isNotNull);
      expect(updateLog.afterJson, isNotNull);
      expect(updateLog.beforeJson, contains('سند حسابرسی'));
      expect(updateLog.afterJson, contains('ویرایش‌شده'));
    });
  });

  group('Phase 1 — period lock', () {
    test('rejects documents dated inside a closed fiscal year', () async {
      final years = await repo.getFiscalYears();
      final fy = years.first;

      // Close the year directly (lock).
      await (db.update(db.fiscalYearsTable)
            ..where((tbl) => tbl.id.equals(fy.id)))
          .write(FiscalYearsTableCompanion(isClosed: const Value(true)));

      final doc = balancedDoc(date: fy.startDate.add(const Duration(days: 5)));
      expect(() => repo.createDocument(doc), throwsStateError);
    });
  });

  group('Phase 1 — floating details (تفصیلی شناور)', () {
    test(
      'creates ledger + values, tags document, and reports by value',
      () async {
        final ledgerId = await repo.createDetailLedger(
          title: 'مشتریان',
          code: 'customer',
        );
        final valueId = await repo.createDetailValue(
          ledgerId: ledgerId,
          title: 'شرکت الف',
        );

        final doc = await repo.createDocument(
          balancedDoc(title: 'فروش به شرکت الف'),
          details: [DocumentDetailTag(ledgerId: ledgerId, valueId: valueId)],
        );

        final report = await repo.getDetailReport(
          ledgerId: ledgerId,
          valueId: valueId,
        );
        expect(report.rows, isNotEmpty);
        expect(report.totalDebitMinorUnits, equals(100000));
        expect(report.totalCreditMinorUnits, equals(100000));
        expect(report.rows.first.documentNumber, doc.number);

        final tags = await repo.getDocumentDetails(doc.id);
        expect(tags.length, equals(1));
        expect(tags.first.valueId, equals(valueId));
      },
    );

    test('enforces the 10-ledger limit', () async {
      for (var i = 0; i < 10; i++) {
        await repo.createDetailLedger(title: 'تفصیلی $i', code: 'l$i');
      }
      expect(
        () => repo.createDetailLedger(title: 'یازدهم', code: 'l11'),
        throwsStateError,
      );
    });
  });

  group('Phase 1 — fiscal year close/open', () {
    test('closing produces balanced closing voucher, next year and opening voucher', () async {
      // Revenue + expense documents inside the current fiscal year.
      final now = DateTime.now();
      final expenseId = (await repo.getSubjectByCode('040001'))!.id;
      await repo.createDocument(balancedDoc(title: 'فروش', date: now));
      await repo.createDocument(
        balancedDoc(title: 'هزینه').copyWith(
          transactions: [
            AccountingTransactionEntity(
              id: '',
              documentId: '',
              subjectId: expenseId,
              debit: Money.fromMinor(40000),
              credit: Money.fromMinor(0),
              description: 'هزینه',
              rowOrder: 1,
              createdAt: now,
              updatedAt: now,
            ),
            AccountingTransactionEntity(
              id: '',
              documentId: '',
              subjectId: cashId,
              debit: Money.fromMinor(0),
              credit: Money.fromMinor(40000),
              description: 'پرداخت',
              rowOrder: 2,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );

      final years = await repo.getFiscalYears();
      final closing = await repo.closeFiscalYearWithDocuments(years.first.id);

      expect(closing.isBalanced, isTrue);
      expect(closing.status, DocumentStatus.approved);

      final yearsAfter = await repo.getFiscalYears();
      expect(yearsAfter.length, equals(2));
      final oldYear = yearsAfter.firstWhere((y) => y.id == years.first.id);
      final newYear = yearsAfter.firstWhere((y) => y.id != years.first.id);
      expect(oldYear.isClosed, isTrue);
      expect(oldYear.closingDocumentId, closing.id);
      expect(newYear.isClosed, isFalse);
      expect(newYear.openingDocumentId, isNotNull);
    });
  });
}
