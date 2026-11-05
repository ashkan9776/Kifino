import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounting/data/repositories/accounting_repository_impl.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_document_entity.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_transaction_entity.dart';
import 'package:kifino/features/accounting/domain/entities/accounting_audit_entity.dart';
import 'package:kifino/features/accounting/domain/entities/fiscal_year_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression suite for the double-entry accounting audit (2026-11-05):
/// fiscal close signs + no kol/moein double-count + atomicity, period-lock
/// boundary, draft exclusion from reports, manual doc year resolution and
/// per-year numbering, payment vouchers.
String testUid() =>
      '${DateTime.now().microsecondsSinceEpoch}${DateTime.now().millisecondsSinceEpoch % 1000}';

void main() {
  late AppDatabase db;
  late AccountingRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = AccountingRepositoryImpl(db);
    SharedPreferences.setMockInitialValues({});
    await repo.seedChartOfAccountsIfNotExists();
  });

  tearDown(() async => db.close());

  Future<FiscalYearEntity> seededYear() async =>
      (await repo.getActiveFiscalYear())!;

  /// Posts a balanced manual voucher with two custom rows.
  Future<void> postRows(
    String subjectCodeDebit,
    int debitMinor,
    String subjectCodeCredit,
    int creditMinor, {
    DateTime? date,
    String? title,
  }) async {
    final dr = await repo.getSubjectByCode(subjectCodeDebit);
    final cr = await repo.getSubjectByCode(subjectCodeCredit);
    assert(dr != null && cr != null);
    final now = DateTime.now();
    final doc = AccountingDocumentEntity(
      id: '',
      number: 0,
      date: date ?? now,
      title: title ?? 'سند آزمون',
      status: DocumentStatus.approved,
      isManual: true,
      createdAt: now,
      updatedAt: now,
      transactions: [
        AccountingTransactionEntity(
          id: testUid(),
          documentId: '',
          subjectId: dr!.id,
          debit: Money.fromMinor(debitMinor),
          credit: const Money.zero(),
          description: 'بد',
          createdAt: now,
          updatedAt: now,
        ),
        AccountingTransactionEntity(
          id: testUid(),
          documentId: '',
          subjectId: cr!.id,
          debit: const Money.zero(),
          credit: Money.fromMinor(creditMinor),
          description: 'بس',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    await repo.createDocument(doc);
  }


  group('fiscal close (P0: signs + double-count + atomicity)', () {
    test('closing voucher is balanced and year closes end-to-end', () async {
      final fy = await seededYear();

      // Revenue 5,000,000 / Expense 1,000,000 → profit 4,000,000.
      await postRows('012001', 5000000, '060001', 5000000,
          title: 'فروش');
      await postRows('040001', 1000000, '010', 1000000, title: 'هزینه');

      final closing = await repo.closeFiscalYearWithDocuments(fy.id);

      // The closing voucher must be BALANCED (the old code inverted signs and
      // hit the integrity lock).
      expect(closing.isBalanced, isTrue,
          reason:
              'مجموع بدهکار=${closing.totalDebit.minorUnits} بستانکار=${closing.totalCredit.minorUnits}');

      // Closing rows: debit revenue 5M (credit balance), credit expense 1M
      // (debit balance), credit equity 4M (profit).
      final revRow = closing.transactions
          .firstWhere((t) => (t.subject?.code ?? '').startsWith('060'));
      final expRow = closing.transactions
          .firstWhere((t) => (t.subject?.code ?? '').startsWith('040'));
      expect(revRow.debit.minorUnits, equals(5000000));
      expect(expRow.credit.minorUnits, equals(1000000));

      final years = await repo.getFiscalYears();
      final closed = years.firstWhere((y) => y.id == fy.id);
      expect(closed.isClosed, isTrue);
      expect(closed.closingDocumentId, isNotNull);

      // New year exists, is active, and carries an opening voucher.
      final next = years.firstWhere((y) => y.yearNumber == fy.yearNumber + 1);
      expect(next.isActive, isTrue);
      expect(next.openingDocumentId, isNotNull);
    });

    test('opening voucher carries EXACT closing balances (no kol doubling)',
        () async {
      final fy = await seededYear();
      // Bank balance 70,000,000 (debit).
      await postRows('010', 70000000, '060001', 70000000, title: 'سرمایه');
      await repo.closeFiscalYearWithDocuments(fy.id);

      final years = await repo.getFiscalYears();
      final next = years.firstWhere((y) => y.yearNumber == fy.yearNumber + 1);
      final opening =
          (await repo.getDocumentById(next.openingDocumentId!))!;

      final bankRows = opening.transactions
          .where((t) => (t.subject?.code ?? '').startsWith('010'))
          .toList();
      expect(bankRows, hasLength(1),
          reason: 'bank must appear once (leaf level), not kol+moein');
      expect(bankRows.first.debit.minorUnits, equals(70000000),
          reason: 'opening balance must equal the true balance, not 2x');

      // Kol-level total across ALL 010 rows must also be 70M.
      final totalDebit = opening.transactions
          .where((t) => (t.subject?.code ?? '').startsWith('010'))
          .fold<int>(0, (s, t) => s + t.debit.minorUnits);
      expect(totalDebit, equals(70000000));
    });

    test('profit lands on equity: closing voucher nets to zero P/L remainder',
        () async {
      final fy = await seededYear();
      await postRows('012001', 5000000, '060001', 5000000); // revenue 5M
      await postRows('040001', 1000000, '010', 1000000); // expense 1M

      final closing = await repo.closeFiscalYearWithDocuments(fy.id);
      // Debits 5M (rev close) vs credits 1M + 4M (expense close + equity) = 5M.
      expect(closing.totalDebit.minorUnits,
          equals(closing.totalCredit.minorUnits));
      expect(closing.totalDebit.minorUnits, equals(5000000));
    });
  });

  group('period lock boundary (P1)', () {
    test('first day of the year AFTER a closed year is registrable', () async {
      final fy = await seededYear();

      // Move every doc aside, then close.
      await postRows('012001', 1000, '060001', 1000);
      await repo.closeFiscalYearWithDocuments(fy.id);

      final years = await repo.getFiscalYears();
      final next = years.firstWhere((y) => y.yearNumber == fy.yearNumber + 1);

      // Exactly the new year's first day — the old boundary bug rejected it.
      final firstDay = DateTime(
        next.startDate.year,
        next.startDate.month,
        next.startDate.day,
      );
      await postRows('010', 5000, '060001', 5000, date: firstDay);
    });

    test('documents inside the CLOSED year are still rejected', () async {
      final fy = await seededYear();
      await postRows('012001', 1000, '060001', 1000);
      await repo.closeFiscalYearWithDocuments(fy.id);

      expect(
        () => postRows('010', 1000, '060001', 1000, date: fy.startDate),
        throwsStateError,
      );
    });
  });

  group('document lifecycle guards (P1)', () {
    test('approveDocument on a posted document throws (no downgrade)',
        () async {
      await postRows('010', 1000, '060001', 1000);
      final doc = (await repo.getDocuments()).first;

      // Reach the posted status directly (nothing in the app sets it yet —
      // the guard is defensive for when posting ships).
      await (db.update(db.accountingDocumentsTable)
            ..where((t) => t.id.equals(doc.id)))
          .write(const AccountingDocumentsTableCompanion(
        status: Value('posted'),
      ));
      expect(
        () => repo.approveDocument(doc.id),
        throwsStateError,
      );
    });

    test('approveDocument is idempotent for already-approved docs', () async {
      // Create as DRAFT, approve once → exactly one approve log; approve
      // again → still one (no duplicate audit spam).
      final now = DateTime.now();
      final dr = await repo.getSubjectByCode('010');
      final cr = await repo.getSubjectByCode('060001');
      final draft = AccountingDocumentEntity(
        id: '',
        number: 0,
        date: now,
        title: 'پیش‌نویس متوازن',
        status: DocumentStatus.draft,
        isManual: true,
        createdAt: now,
        updatedAt: now,
        transactions: [
          AccountingTransactionEntity(
            id: testUid(),
            documentId: '',
            subjectId: dr!.id,
            debit: Money.fromMinor(1000),
            credit: const Money.zero(),
            description: 'بد',
            createdAt: now,
            updatedAt: now,
          ),
          AccountingTransactionEntity(
            id: testUid(),
            documentId: '',
            subjectId: cr!.id,
            debit: const Money.zero(),
            credit: Money.fromMinor(1000),
            description: 'بس',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      final saved = await repo.createDocument(draft);
      await repo.approveDocument(saved.id);
      await repo.approveDocument(saved.id); // idempotent re-approval

      final logs = await repo.watchAuditLogs().first;
      final approveLogs = logs
          .where((l) =>
              l.entityId == saved.id && l.action == AuditLogAction.approve)
          .toList();
      expect(approveLogs, hasLength(1));
    });

    test('updateDocument cannot edit a document dated in a closed year',
        () async {
      final fy = await seededYear();
      await postRows('010', 1000, '060001', 1000, date: fy.startDate);
      final doc = (await repo.getDocuments()).first;

      await repo.closeFiscalYearWithDocuments(fy.id);

      final edited = doc.copyWith(title: 'دستکاری دوره بسته');
      expect(
        () => repo.updateDocument(edited),
        throwsStateError,
      );
    });

    test('empty approved voucher and both-sides rows are rejected', () async {
      final now = DateTime.now();
      // Empty non-draft
      expect(
        () => repo.createDocument(AccountingDocumentEntity(
          id: '',
          number: 0,
          date: now,
          title: 'خالی',
          status: DocumentStatus.approved,
          isManual: true,
          createdAt: now,
          updatedAt: now,
          transactions: const [],
        )),
        throwsStateError,
      );

      // A row carrying BOTH debit and credit
      final dr = await repo.getSubjectByCode('010');
      expect(
        () => repo.createDocument(AccountingDocumentEntity(
          id: '',
          number: 0,
          date: now,
          title: 'دوطرفه',
          status: DocumentStatus.approved,
          isManual: true,
          createdAt: now,
          updatedAt: now,
          transactions: [
            AccountingTransactionEntity(
              id: 'x1',
              documentId: '',
              subjectId: dr!.id,
              debit: Money.fromMinor(1000),
              credit: Money.fromMinor(1000),
              description: '',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        )),
        throwsStateError,
      );
    });
  });

  group('manual documents: year resolution + numbering (P1)', () {
    test('manual doc without fiscalYearId gets the year of its date', () async {
      await postRows('010', 1000, '060001', 1000);
      final doc = (await repo.getDocuments()).first;
      expect(doc.fiscalYearId, isNotNull,
          reason: 'manual docs must not float with a null fiscal year');
      expect(doc.fiscalYearId, equals((await repo.getActiveFiscalYear())!.id));
    });

    test('document numbers stay unique per year across manual + auto docs',
        () async {
      final fy = await seededYear();
      await postRows('010', 1000, '060001', 1000); // manual #1
      await postRows('010', 2000, '060001', 2000); // manual #2
      final numbers = (await repo.getDocuments(fiscalYearId: fy.id))
          .map((d) => d.number)
          .toList();
      expect(numbers.length, equals(numbers.toSet().length),
          reason: 'no duplicate document numbers within the year');
    });
  });

  group('reports exclude drafts (P1)', () {
    test('unbalanced draft does not break the trial balance', () async {
      await postRows('010', 5000, '060001', 5000);
      // Unbalanced DRAFT — allowed to exist, must not pollute reports.
      final now = DateTime.now();
      final dr = await repo.getSubjectByCode('010');
      await repo.createDocument(AccountingDocumentEntity(
        id: '',
        number: 0,
        date: now,
        title: 'پیش‌نویس ناقص',
        status: DocumentStatus.draft,
        isManual: true,
        createdAt: now,
        updatedAt: now,
        transactions: [
          AccountingTransactionEntity(
            id: 'd1',
            documentId: '',
            subjectId: dr!.id,
            debit: Money.fromMinor(999999),
            credit: const Money.zero(),
            description: '',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ));

      final tb = await repo.getTrialBalanceReport();
      expect(tb.isBalanced, isTrue,
          reason: 'a draft must be invisible to the trial balance');
      final journal = await repo.getJournalTransactions();
      expect(journal, hasLength(2),
          reason: 'journal shows only the balanced final doc rows');
    });
  });

  group('income statement (P1: no clamping)', () {
    test('negative revenue (refunds > sales) is not clamped to zero',
        () async {
      final now = DateTime.now();
      // Refund: DR sales 800,000 / CR bank — leaves sales with a DEBIT net.
      await postRows('060001', 800000, '010', 800000, date: now);

      final report = await repo.getIncomeStatementReport(
        startDate: DateTime(now.year, now.month - 1, 1),
        endDate: now,
      );
      final revenueRows = report.revenues
          .where((r) => (r.subject?.code ?? '').startsWith('060'))
          .toList();
      expect(revenueRows, isNotEmpty);
      expect(revenueRows.first.amount.minorUnits, equals(-800000),
          reason: 'a debit (negative) revenue balance must flow through');
    });
  });
}
