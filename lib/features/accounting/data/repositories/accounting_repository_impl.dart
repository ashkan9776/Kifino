import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';

import 'dart:convert';

import '../../domain/entities/accounting_audit_entity.dart';
import '../../domain/entities/accounting_document_entity.dart';
import '../../domain/entities/accounting_subject_entity.dart';
import '../../domain/entities/accounting_transaction_entity.dart';
import '../../domain/entities/financial_statement_report.dart';
import '../../domain/entities/fiscal_year_entity.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../domain/entities/trial_balance_entry.dart';
import '../../domain/repositories/accounting_repository.dart';
import '../datasources/standard_chart_of_accounts_seed.dart';

class AccountingRepositoryImpl implements AccountingRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  AccountingRepositoryImpl(this._db, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  @override
  Future<void> seedChartOfAccountsIfNotExists() async {
    final existingCount = await (_db.selectOnly(
      _db.accountingSubjectsTable,
    )..addColumns([_db.accountingSubjectsTable.id.count()])).getSingle();
    final count =
        existingCount.read(_db.accountingSubjectsTable.id.count()) ?? 0;
    if (count > 0) return;

    // Check or create default active fiscal year
    final existingFiscalYear =
        await (_db.select(_db.fiscalYearsTable)
              ..where((tbl) => tbl.isActive.equals(true))
              ..limit(1))
            .getSingleOrNull();

    String fiscalYearId;
    final now = DateTime.now();
    if (existingFiscalYear == null) {
      fiscalYearId = _uuid.v4();
      // The seeded year must follow the Jalali calendar (1 فروردین تا پایان
      // اسفند) — a Gregorian-aligned default period mislocks every document
      // date in a Persian-first app.
      await _db
          .into(_db.fiscalYearsTable)
          .insert(
            FiscalYearsTableCompanion.insert(
              id: fiscalYearId,
              title: 'سال مالی جاری',
              yearNumber: JalaliDate.fromDateTime(now).year,
              startDate: startOfJalaliYear(now).millisecondsSinceEpoch,
              endDate: endOfJalaliYear(now).millisecondsSinceEpoch,
              isClosed: const Value(false),
              isActive: const Value(true),
              createdAt: now.millisecondsSinceEpoch,
              updatedAt: now.millisecondsSinceEpoch,
            ),
          );
    } else {
      fiscalYearId = existingFiscalYear.id;
    }

    // Seed roots first, then children
    final Map<String, String> codeToIdMap = {};

    for (final seed in standardIranianChartOfAccounts) {
      final id = _uuid.v4();
      codeToIdMap[seed.code] = id;
    }

    final List<AccountingSubjectsTableCompanion> companions = [];
    final nowMs = now.millisecondsSinceEpoch;

    for (final seed in standardIranianChartOfAccounts) {
      final id = codeToIdMap[seed.code]!;
      final parentId = seed.parentCode != null
          ? codeToIdMap[seed.parentCode]
          : null;

      companions.add(
        AccountingSubjectsTableCompanion.insert(
          id: id,
          code: seed.code,
          name: seed.name,
          parentId: Value(parentId),
          type: seed.type.code,
          level: seed.level.code,
          isPermanent: Value(seed.isPermanent),
          fiscalYearId: Value(fiscalYearId),
          createdAt: nowMs,
          updatedAt: nowMs,
        ),
      );
    }

    await _db.batch((batch) {
      batch.insertAll(_db.accountingSubjectsTable, companions);
    });
  }

  AccountingSubjectEntity _mapSubject(AccountingSubjectData data) {
    return AccountingSubjectEntity(
      id: data.id,
      code: data.code,
      name: data.name,
      parentId: data.parentId,
      type: AccountingSubjectType.fromCode(data.type),
      level: AccountingSubjectLevel.fromCode(data.level),
      isPermanent: data.isPermanent,
      fiscalYearId: data.fiscalYearId,
      description: data.description,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
    );
  }

  @override
  Future<List<AccountingSubjectEntity>> getAllSubjects() async {
    final query = _db.select(_db.accountingSubjectsTable)
      ..where((tbl) => tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.code)]);
    final rows = await query.get();
    return rows.map(_mapSubject).toList();
  }

  @override
  Future<List<AccountingSubjectEntity>> getRootSubjects() async {
    final query = _db.select(_db.accountingSubjectsTable)
      ..where((tbl) => tbl.parentId.isNull() & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.code)]);
    final rows = await query.get();
    return rows.map(_mapSubject).toList();
  }

  @override
  Future<List<AccountingSubjectEntity>> getChildSubjects(
    String parentId,
  ) async {
    final query = _db.select(_db.accountingSubjectsTable)
      ..where((tbl) => tbl.parentId.equals(parentId) & tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.code)]);
    final rows = await query.get();
    return rows.map(_mapSubject).toList();
  }

  @override
  Future<AccountingSubjectEntity?> getSubjectByCode(String code) async {
    final query = _db.select(_db.accountingSubjectsTable)
      ..where((tbl) => tbl.code.equals(code) & tbl.deletedAt.isNull())
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row != null ? _mapSubject(row) : null;
  }

  @override
  Future<AccountingSubjectEntity?> getSubjectById(String id) async {
    final query = _db.select(_db.accountingSubjectsTable)
      ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull())
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row != null ? _mapSubject(row) : null;
  }

  @override
  Future<AccountingSubjectEntity> createSubject(
    AccountingSubjectEntity subject,
  ) async {
    final id = subject.id.isEmpty ? _uuid.v4() : subject.id;
    final now = DateTime.now();
    await _db
        .into(_db.accountingSubjectsTable)
        .insert(
          AccountingSubjectsTableCompanion.insert(
            id: id,
            code: subject.code,
            name: subject.name,
            parentId: Value(subject.parentId),
            type: subject.type.code,
            level: subject.level.code,
            isPermanent: Value(subject.isPermanent),
            fiscalYearId: Value(subject.fiscalYearId),
            description: Value(subject.description),
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    return subject.copyWith(id: id, createdAt: now, updatedAt: now);
  }

  @override
  Future<AccountingSubjectEntity> updateSubject(
    AccountingSubjectEntity subject,
  ) async {
    final now = DateTime.now();
    await (_db.update(
      _db.accountingSubjectsTable,
    )..where((tbl) => tbl.id.equals(subject.id))).write(
      AccountingSubjectsTableCompanion(
        code: Value(subject.code),
        name: Value(subject.name),
        parentId: Value(subject.parentId),
        type: Value(subject.type.code),
        level: Value(subject.level.code),
        isPermanent: Value(subject.isPermanent),
        description: Value(subject.description),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
    return subject.copyWith(updatedAt: now);
  }

  @override
  Future<void> deleteSubject(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.accountingSubjectsTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(AccountingSubjectsTableCompanion(deletedAt: Value(now)));
  }

  // ─── Documents ───

  @override
  Future<int> getNextDocumentNumber(String? fiscalYearId) async {
    final maxQuery = _db.selectOnly(_db.accountingDocumentsTable)
      ..addColumns([_db.accountingDocumentsTable.number.max()]);
    if (fiscalYearId != null) {
      maxQuery.where(
        _db.accountingDocumentsTable.fiscalYearId.equals(fiscalYearId),
      );
    }
    final result = await maxQuery.getSingle();
    final maxNum = result.read(_db.accountingDocumentsTable.number.max()) ?? 0;
    return maxNum + 1;
  }

  @override
  Future<List<AccountingDocumentEntity>> getDocuments({
    DateTime? startDate,
    DateTime? endDate,
    DocumentStatus? status,
    String? fiscalYearId,
  }) async {
    var query = _db.select(_db.accountingDocumentsTable)
      ..where((tbl) => tbl.deletedAt.isNull());

    if (startDate != null) {
      query = query
        ..where(
          (tbl) =>
              tbl.date.isBiggerOrEqualValue(startDate.millisecondsSinceEpoch),
        );
    }
    if (endDate != null) {
      query = query
        ..where(
          (tbl) =>
              tbl.date.isSmallerOrEqualValue(endDate.millisecondsSinceEpoch),
        );
    }
    if (status != null) {
      query = query..where((tbl) => tbl.status.equals(status.code));
    }
    if (fiscalYearId != null) {
      query = query..where((tbl) => tbl.fiscalYearId.equals(fiscalYearId));
    }

    query = query..orderBy([(tbl) => OrderingTerm.desc(tbl.number)]);
    final docRows = await query.get();

    final List<AccountingDocumentEntity> result = [];
    for (final doc in docRows) {
      final txRows =
          await (_db.select(_db.accountingTransactionsTable)
                ..where((tbl) => tbl.documentId.equals(doc.id))
                ..orderBy([(tbl) => OrderingTerm.asc(tbl.rowOrder)]))
              .get();

      final transactions = <AccountingTransactionEntity>[];
      for (final tx in txRows) {
        final subjectData = await getSubjectById(tx.subjectId);
        transactions.add(
          AccountingTransactionEntity(
            id: tx.id,
            documentId: tx.documentId,
            subjectId: tx.subjectId,
            subject: subjectData,
            detailSubjectId: tx.detailSubjectId,
            debit: Money.fromMinor(tx.debitMinorUnits),
            credit: Money.fromMinor(tx.creditMinorUnits),
            description: tx.description,
            rowOrder: tx.rowOrder,
            createdAt: DateTime.fromMillisecondsSinceEpoch(tx.createdAt),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(tx.updatedAt),
          ),
        );
      }

      result.add(
        AccountingDocumentEntity(
          id: doc.id,
          number: doc.number,
          date: DateTime.fromMillisecondsSinceEpoch(doc.date),
          title: doc.title,
          status: DocumentStatus.fromCode(doc.status),
          isManual: doc.isManual,
          referenceType: doc.referenceType,
          referenceId: doc.referenceId,
          fiscalYearId: doc.fiscalYearId,
          approvedAt: doc.approvedAt != null
              ? DateTime.fromMillisecondsSinceEpoch(doc.approvedAt!)
              : null,
          transactions: transactions,
          createdAt: DateTime.fromMillisecondsSinceEpoch(doc.createdAt),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(doc.updatedAt),
        ),
      );
    }

    return result;
  }

  @override
  Future<AccountingDocumentEntity?> getDocumentById(String id) async {
    final doc =
        await (_db.select(_db.accountingDocumentsTable)
              ..where((tbl) => tbl.id.equals(id) & tbl.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();

    if (doc == null) return null;

    final txRows =
        await (_db.select(_db.accountingTransactionsTable)
              ..where((tbl) => tbl.documentId.equals(doc.id))
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.rowOrder)]))
            .get();

    final transactions = <AccountingTransactionEntity>[];
    for (final tx in txRows) {
      final subjectData = await getSubjectById(tx.subjectId);
      transactions.add(
        AccountingTransactionEntity(
          id: tx.id,
          documentId: tx.documentId,
          subjectId: tx.subjectId,
          subject: subjectData,
          detailSubjectId: tx.detailSubjectId,
          debit: Money.fromMinor(tx.debitMinorUnits),
          credit: Money.fromMinor(tx.creditMinorUnits),
          description: tx.description,
          rowOrder: tx.rowOrder,
          createdAt: DateTime.fromMillisecondsSinceEpoch(tx.createdAt),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(tx.updatedAt),
        ),
      );
    }

    return AccountingDocumentEntity(
      id: doc.id,
      number: doc.number,
      date: DateTime.fromMillisecondsSinceEpoch(doc.date),
      title: doc.title,
      status: DocumentStatus.fromCode(doc.status),
      isManual: doc.isManual,
      referenceType: doc.referenceType,
      referenceId: doc.referenceId,
      fiscalYearId: doc.fiscalYearId,
      approvedAt: doc.approvedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(doc.approvedAt!)
          : null,
      transactions: transactions,
      createdAt: DateTime.fromMillisecondsSinceEpoch(doc.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(doc.updatedAt),
    );
  }

  @override
  Future<AccountingDocumentEntity> createDocument(
    AccountingDocumentEntity document, {
    List<DocumentDetailTag> details = const [],
  }) async {
    final docId = document.id.isEmpty ? _uuid.v4() : document.id;

    // Manual documents never carry a fiscal year — resolve it from the
    // document date (falling back to the active year) so they are sequenced
    // per-year and visible in every year-scoped report instead of floating
    // with a null year (which also caused duplicate document numbers).
    var fiscalYearId = document.fiscalYearId;
    if (fiscalYearId == null) {
      final years = await getFiscalYears();
      for (final fy in years) {
        if (dateWithinFiscalYear(document.date, fy)) {
          fiscalYearId = fy.id;
          break;
        }
      }
      fiscalYearId ??= (await getActiveFiscalYear())?.id;
    }

    final docNumber = document.number > 0
        ? document.number
        : await getNextDocumentNumber(fiscalYearId);
    final now = DateTime.now();

    // Integrity lock: only drafts may register unbalanced; official statuses
    // (approved/posted) must be balanced before they touch the ledger.
    if (document.status != DocumentStatus.draft && !document.isBalanced) {
      throw StateError(
        'سند ناموازنه قابل ثبت نیست. مجموع بدهکار و بستانکار برابر نیست.',
      );
    }
    if (document.status != DocumentStatus.draft &&
        document.transactions.isEmpty) {
      throw StateError('سند بدون ردیف تراکنش قابل تأیید نیست.');
    }
    // Each row must carry exactly one side; a both-sides row silently
    // inflates both turnover columns of the trial balance.
    for (final tx in document.transactions) {
      if (tx.debit.minorUnits > 0 && tx.credit.minorUnits > 0) {
        throw StateError(
          'هر ردیف سند باید فقط یک طرف بدهکار یا بستانکار داشته باشد.',
        );
      }
    }
    await _ensurePeriodOpen(document.date);

    final afterJson = _documentSnapshotJson(docId, docNumber, document);

    await _db.transaction(() async {
      await _db
          .into(_db.accountingDocumentsTable)
          .insert(
            AccountingDocumentsTableCompanion.insert(
              id: docId,
              number: docNumber,
              date: document.date.millisecondsSinceEpoch,
              title: document.title,
              status: document.status.code,
              isManual: Value(document.isManual),
              referenceType: Value(document.referenceType),
              referenceId: Value(document.referenceId),
              fiscalYearId: Value(fiscalYearId),
              approvedAt: Value(document.approvedAt?.millisecondsSinceEpoch),
              createdAt: now.millisecondsSinceEpoch,
              updatedAt: now.millisecondsSinceEpoch,
            ),
          );

      int order = 1;
      for (final tx in document.transactions) {
        final txId = tx.id.isEmpty ? _uuid.v4() : tx.id;
        await _db
            .into(_db.accountingTransactionsTable)
            .insert(
              AccountingTransactionsTableCompanion.insert(
                id: txId,
                documentId: docId,
                subjectId: tx.subjectId,
                detailSubjectId: Value(tx.detailSubjectId),
                debitMinorUnits: Value(tx.debit.minorUnits),
                creditMinorUnits: Value(tx.credit.minorUnits),
                description: tx.description,
                rowOrder: Value(tx.rowOrder > 0 ? tx.rowOrder : order++),
                createdAt: now.millisecondsSinceEpoch,
                updatedAt: now.millisecondsSinceEpoch,
              ),
            );
      }

      await _insertAuditLog(
        action: AuditLogAction.create,
        entityId: docId,
        beforeJson: null,
        afterJson: afterJson,
        description: 'ثبت سند شماره $docNumber — ${document.title}',
        at: now,
      );

      // Floating detail tags (one value per ledger, max 10 ledgers).
      if (details.isNotEmpty) {
        await _applyDetailTags(docId, details, now);
      }
    });

    return (await getDocumentById(docId))!;
  }

  @override
  Future<AccountingDocumentEntity> updateDocument(
    AccountingDocumentEntity document, {
    List<DocumentDetailTag>? details,
  }) async {
    final now = DateTime.now();
    final existing = await getDocumentById(document.id);
    if (existing == null) throw StateError('سند حسابداری پیدا نشد.');
    if (existing.status == DocumentStatus.posted) {
      throw StateError('سند قطعی‌شده قابل ویرایش نیست.');
    }
    if (document.status != DocumentStatus.draft && !document.isBalanced) {
      throw StateError(
        'سند ناموازنه قابل تأیید نیست. مجموع بدهکار و بستانکار برابر نیست.',
      );
    }
    // Both the document's CURRENT date and its NEW date must sit in open
    // periods — otherwise an edit could silently rewrite a closed year.
    await _ensurePeriodOpen(existing.date);
    await _ensurePeriodOpen(document.date);
    final beforeJson = _documentSnapshotJson(
      existing.id,
      existing.number,
      existing,
    );
    final afterJson = _documentSnapshotJson(
      document.id,
      existing.number,
      document,
    );

    await _db.transaction(() async {
      await (_db.update(
        _db.accountingDocumentsTable,
      )..where((tbl) => tbl.id.equals(document.id))).write(
        AccountingDocumentsTableCompanion(
          date: Value(document.date.millisecondsSinceEpoch),
          title: Value(document.title),
          status: Value(document.status.code),
          referenceType: Value(document.referenceType),
          referenceId: Value(document.referenceId),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ),
      );

      // Re-create transactions
      await (_db.delete(
        _db.accountingTransactionsTable,
      )..where((tbl) => tbl.documentId.equals(document.id))).go();

      int order = 1;
      for (final tx in document.transactions) {
        final txId = tx.id.isEmpty ? _uuid.v4() : tx.id;
        await _db
            .into(_db.accountingTransactionsTable)
            .insert(
              AccountingTransactionsTableCompanion.insert(
                id: txId,
                documentId: document.id,
                subjectId: tx.subjectId,
                detailSubjectId: Value(tx.detailSubjectId),
                debitMinorUnits: Value(tx.debit.minorUnits),
                creditMinorUnits: Value(tx.credit.minorUnits),
                description: tx.description,
                rowOrder: Value(tx.rowOrder > 0 ? tx.rowOrder : order++),
                createdAt: now.millisecondsSinceEpoch,
                updatedAt: now.millisecondsSinceEpoch,
              ),
            );
      }

      await _insertAuditLog(
        action: AuditLogAction.update,
        entityId: document.id,
        beforeJson: beforeJson,
        afterJson: afterJson,
        description: 'ویرایش سند شماره ${existing.number} — ${document.title}',
        at: now,
      );

      if (details != null) {
        await (_db.delete(
          _db.accountingDocumentDetailLinksTable,
        )..where((tbl) => tbl.documentId.equals(document.id))).go();
        if (details.isNotEmpty) {
          await _applyDetailTags(document.id, details, now);
        }
      }
    });

    return (await getDocumentById(document.id))!;
  }

  @override
  Future<void> approveDocument(String documentId) async {
    final doc = await getDocumentById(documentId);
    if (doc == null) throw StateError('سند حسابداری پیدا نشد.');
    // A posted document is immutable — approving it again must not silently
    // downgrade it back to approved (which would reopen edit/delete paths).
    if (doc.status == DocumentStatus.posted) {
      throw StateError('سند قطعی‌شده دیگر قابل تأیید یا تغییر نیست.');
    }
    if (doc.status == DocumentStatus.approved) {
      return; // Idempotent re-approval: no duplicate audit spam.
    }
    if (!doc.isBalanced) {
      throw StateError(
        'سند متوازن نیست. مجموع بدهکار و بستانکار باید برابر باشد.',
      );
    }
    await _ensurePeriodOpen(doc.date);

    final now = DateTime.now();
    final beforeJson = _documentSnapshotJson(doc.id, doc.number, doc);
    await (_db.update(
      _db.accountingDocumentsTable,
    )..where((tbl) => tbl.id.equals(documentId))).write(
      AccountingDocumentsTableCompanion(
        status: const Value('approved'),
        approvedAt: Value(now.millisecondsSinceEpoch),
        updatedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
    final after = doc.copyWith(status: DocumentStatus.approved);
    await _insertAuditLog(
      action: AuditLogAction.approve,
      entityId: documentId,
      beforeJson: beforeJson,
      afterJson: _documentSnapshotJson(after.id, after.number, after),
      description: 'تأیید سند شماره ${doc.number} — ${doc.title}',
      at: now,
    );
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    final doc = await getDocumentById(documentId);
    if (doc == null) return;
    if (doc.status == DocumentStatus.posted) {
      throw StateError('سند قطعی‌شده قابل حذف نیست.');
    }
    await _ensurePeriodOpen(doc.date);

    final now = DateTime.now();
    final beforeJson = _documentSnapshotJson(doc.id, doc.number, doc);
    await (_db.update(
      _db.accountingDocumentsTable,
    )..where((tbl) => tbl.id.equals(documentId))).write(
      AccountingDocumentsTableCompanion(
        deletedAt: Value(now.millisecondsSinceEpoch),
      ),
    );
    await (_db.delete(
      _db.accountingDocumentDetailLinksTable,
    )..where((tbl) => tbl.documentId.equals(documentId))).go();
    await _insertAuditLog(
      action: AuditLogAction.delete,
      entityId: documentId,
      beforeJson: beforeJson,
      afterJson: null,
      description: 'حذف سند شماره ${doc.number} — ${doc.title}',
      at: now,
    );
  }

  // ─── Reports ───

  /// Reports (journal/ledger/trial balance/statements) must only see FINAL
  /// documents. Drafts are work-in-progress — an unbalanced draft in the
  /// trial balance would break the debit==credit identity.
  static bool _isFinalDoc(AccountingDocumentEntity d) =>
      d.status == DocumentStatus.approved || d.status == DocumentStatus.posted;

  @override
  Future<List<AccountingTransactionEntity>> getJournalTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? fiscalYearId,
  }) async {
    final docs = (await getDocuments(
      startDate: startDate,
      endDate: endDate,
      fiscalYearId: fiscalYearId,
    ))
        .where(_isFinalDoc)
        .toList();

    final List<AccountingTransactionEntity> allTxs = [];
    for (final doc in docs.reversed) {
      allTxs.addAll(doc.transactions);
    }
    return allTxs;
  }

  @override
  Future<LedgerReport> getLedgerReport({
    required String subjectId,
    DateTime? startDate,
    DateTime? endDate,
    String? fiscalYearId,
  }) async {
    final subject = await getSubjectById(subjectId);
    if (subject == null) throw Exception('سرفصل حسابداری پیدا نشد.');

    // Find all descendant subject IDs
    final allSubjects = await getAllSubjects();
    final targetIds = _getDescendantSubjectIds(subject.id, allSubjects);
    targetIds.add(subject.id);

    // Opening balance (transactions prior to startDate)
    int openingMinor = 0;
    if (startDate != null) {
      final priorDocs = (await getDocuments(
        endDate: startDate.subtract(const Duration(milliseconds: 1)),
        fiscalYearId: fiscalYearId,
      ))
          .where(_isFinalDoc)
          .toList();
      for (final doc in priorDocs) {
        for (final tx in doc.transactions) {
          if (targetIds.contains(tx.subjectId)) {
            openingMinor += (tx.debit.minorUnits - tx.credit.minorUnits);
          }
        }
      }
    }

    // Period documents
    final periodDocs = (await getDocuments(
      startDate: startDate,
      endDate: endDate,
      fiscalYearId: fiscalYearId,
    ))
        .where(_isFinalDoc)
        .toList();
    // Sort ascending for ledger
    final sortedDocs = periodDocs.reversed.toList();

    int runningMinor = openingMinor;
    final List<LedgerEntry> entries = [];
    int rowIndex = 1;

    for (final doc in sortedDocs) {
      for (final tx in doc.transactions) {
        if (targetIds.contains(tx.subjectId)) {
          runningMinor += (tx.debit.minorUnits - tx.credit.minorUnits);
          final balanceSide = runningMinor > 0
              ? 'بد'
              : runningMinor < 0
              ? 'بس'
              : '-';

          entries.add(
            LedgerEntry(
              rowIndex: rowIndex++,
              transactionId: tx.id,
              documentId: doc.id,
              documentNumber: doc.number,
              date: doc.date,
              description: tx.description.isNotEmpty
                  ? tx.description
                  : doc.title,
              debit: tx.debit,
              credit: tx.credit,
              runningBalance: Money.fromMinor(runningMinor.abs()),
              balanceSide: balanceSide,
            ),
          );
        }
      }
    }

    final openingSide = openingMinor > 0
        ? 'بد'
        : openingMinor < 0
        ? 'بس'
        : '-';

    return LedgerReport(
      subject: subject,
      openingBalance: Money.fromMinor(openingMinor.abs()),
      openingSide: openingSide,
      entries: entries,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Set<String> _getDescendantSubjectIds(
    String parentId,
    List<AccountingSubjectEntity> all, [
    Set<String>? ancestors,
  ]) {
    // Guard against a malformed parent cycle: a subject already on the
    // recursion path contributes nothing new and must not loop forever.
    ancestors ??= <String>{};
    if (!ancestors.add(parentId)) return <String>{};
    final set = <String>{};
    for (final s in all) {
      if (s.parentId == parentId) {
        set.add(s.id);
        set.addAll(_getDescendantSubjectIds(s.id, all, ancestors));
      }
    }
    ancestors.remove(parentId);
    return set;
  }

  @override
  Future<TrialBalanceReport> getTrialBalanceReport({
    AccountingSubjectLevel level = AccountingSubjectLevel.kol,
    DateTime? startDate,
    DateTime? endDate,
    String? fiscalYearId,
  }) async {
    final allSubjects = await getAllSubjects();
    final targetSubjects = allSubjects.where((s) => s.level == level).toList();

    final allDocs = (await getDocuments(fiscalYearId: fiscalYearId))
        .where(_isFinalDoc)
        .toList();

    final List<TrialBalanceEntry> entries = [];

    for (final subject in targetSubjects) {
      final descendantIds = _getDescendantSubjectIds(subject.id, allSubjects);
      descendantIds.add(subject.id);

      int openingDeb = 0;
      int openingCred = 0;
      int periodDeb = 0;
      int periodCred = 0;

      for (final doc in allDocs) {
        final isPrior = startDate != null && doc.date.isBefore(startDate);
        final isInPeriod =
            (startDate == null || !doc.date.isBefore(startDate)) &&
            (endDate == null || !doc.date.isAfter(endDate));

        for (final tx in doc.transactions) {
          if (descendantIds.contains(tx.subjectId)) {
            if (isPrior) {
              openingDeb += tx.debit.minorUnits;
              openingCred += tx.credit.minorUnits;
            } else if (isInPeriod) {
              periodDeb += tx.debit.minorUnits;
              periodCred += tx.credit.minorUnits;
            }
          }
        }
      }

      entries.add(
        TrialBalanceEntry(
          subject: subject,
          openingDebit: Money.fromMinor(openingDeb),
          openingCredit: Money.fromMinor(openingCred),
          periodDebit: Money.fromMinor(periodDeb),
          periodCredit: Money.fromMinor(periodCred),
        ),
      );
    }

    return TrialBalanceReport(
      entries: entries,
      startDate: startDate,
      endDate: endDate,
      level: level,
    );
  }

  @override
  Future<BalanceSheetReport> getBalanceSheetReport({
    required DateTime asOfDate,
    String? fiscalYearId,
  }) async {
    final trialBalance = await getTrialBalanceReport(
      level: AccountingSubjectLevel.kol,
      endDate: asOfDate,
      fiscalYearId: fiscalYearId,
    );

    final List<StatementItem> currentAssets = [];
    final List<StatementItem> nonCurrentAssets = [];
    final List<StatementItem> currentLiabilities = [];
    final List<StatementItem> nonCurrentLiabilities = [];
    final List<StatementItem> equityItems = [];

    int netRevenueMinor = 0;
    int cogsMinor = 0;
    int expensesMinor = 0;

    for (final entry in trialBalance.entries) {
      final code = entry.subject.code;
      final balance =
          entry.netMinorUnits; // positive = debit, negative = credit

      if (entry.subject.isPermanent) {
        if (code.startsWith('010') ||
            code.startsWith('011') ||
            code.startsWith('012') ||
            code.startsWith('013') ||
            code.startsWith('014') ||
            code.startsWith('015') ||
            code.startsWith('016') ||
            code.startsWith('018') ||
            code.startsWith('019')) {
          currentAssets.add(
            StatementItem(
              subject: entry.subject,
              title: entry.subject.name,
              amount: Money.fromMinor(balance.abs()),
            ),
          );
        } else if (code.startsWith('017')) {
          nonCurrentAssets.add(
            StatementItem(
              subject: entry.subject,
              title: entry.subject.name,
              amount: Money.fromMinor(balance.abs()),
            ),
          );
        } else if (code.startsWith('021') || code.startsWith('025')) {
          nonCurrentLiabilities.add(
            StatementItem(
              subject: entry.subject,
              title: entry.subject.name,
              amount: Money.fromMinor(balance.abs()),
            ),
          );
        } else if (code.startsWith('020') ||
            code.startsWith('022') ||
            code.startsWith('023')) {
          currentLiabilities.add(
            StatementItem(
              subject: entry.subject,
              title: entry.subject.name,
              amount: Money.fromMinor(balance.abs()),
            ),
          );
        } else if (code.startsWith('030') ||
            code.startsWith('067') ||
            code.startsWith('068')) {
          equityItems.add(
            StatementItem(
              subject: entry.subject,
              title: entry.subject.name,
              amount: Money.fromMinor(balance.abs()),
              isNegative: balance > 0, // debit equity is negative
            ),
          );
        }
      } else {
        // Temporary accounts (for period net income)
        if (code.startsWith('060') || code.startsWith('050')) {
          netRevenueMinor += -balance; // credit is revenue
        } else if (code.startsWith('070') || code.startsWith('041')) {
          cogsMinor += balance; // debit is cogs
        } else if (code.startsWith('040') ||
            code.startsWith('061') ||
            code.startsWith('066')) {
          expensesMinor += balance; // debit is expense
        }
      }
    }

    final netIncomeMinor = netRevenueMinor - cogsMinor - expensesMinor;

    return BalanceSheetReport(
      asOfDate: asOfDate,
      currentAssets: currentAssets,
      nonCurrentAssets: nonCurrentAssets,
      currentLiabilities: currentLiabilities,
      nonCurrentLiabilities: nonCurrentLiabilities,
      equityItems: equityItems,
      netIncomeForPeriod: Money.fromMinor(netIncomeMinor),
    );
  }

  @override
  Future<IncomeStatementReport> getIncomeStatementReport({
    required DateTime startDate,
    required DateTime endDate,
    String? fiscalYearId,
  }) async {
    final trialBalance = await getTrialBalanceReport(
      level: AccountingSubjectLevel.kol,
      startDate: startDate,
      endDate: endDate,
      fiscalYearId: fiscalYearId,
    );

    final List<StatementItem> revenues = [];
    final List<StatementItem> salesDiscountsReturns = [];
    final List<StatementItem> cogsItems = [];
    final List<StatementItem> operatingExpenses = [];
    final List<StatementItem> otherIncomes = [];
    final List<StatementItem> otherExpenses = [];

    for (final entry in trialBalance.entries) {
      if (entry.subject.isPermanent) continue;

      final code = entry.subject.code;
      final periodNet = entry.periodNetMinorUnits;

      if (code.startsWith('060')) {
        revenues.add(
          StatementItem(
            subject: entry.subject,
            title: entry.subject.name,
            amount: Money.fromMinor((-periodNet)),
          ),
        );
      } else if (code.startsWith('061')) {
        salesDiscountsReturns.add(
          StatementItem(
            subject: entry.subject,
            title: entry.subject.name,
            amount: Money.fromMinor(periodNet),
          ),
        );
      } else if (code.startsWith('070') || code.startsWith('041')) {
        cogsItems.add(
          StatementItem(
            subject: entry.subject,
            title: entry.subject.name,
            amount: Money.fromMinor(periodNet),
          ),
        );
      } else if (code.startsWith('040')) {
        operatingExpenses.add(
          StatementItem(
            subject: entry.subject,
            title: entry.subject.name,
            amount: Money.fromMinor(periodNet),
          ),
        );
      } else if (code.startsWith('050')) {
        otherIncomes.add(
          StatementItem(
            subject: entry.subject,
            title: entry.subject.name,
            amount: Money.fromMinor((-periodNet)),
          ),
        );
      } else if (code.startsWith('066')) {
        otherExpenses.add(
          StatementItem(
            subject: entry.subject,
            title: entry.subject.name,
            amount: Money.fromMinor(periodNet),
          ),
        );
      }
    }

    return IncomeStatementReport(
      startDate: startDate,
      endDate: endDate,
      revenues: revenues,
      salesDiscountsReturns: salesDiscountsReturns,
      cogsItems: cogsItems,
      operatingExpenses: operatingExpenses,
      otherIncomes: otherIncomes,
      otherExpenses: otherExpenses,
    );
  }

  // ─── Fiscal Years ───

  @override
  Future<List<FiscalYearEntity>> getFiscalYears() async {
    final rows = await (_db.select(
      _db.fiscalYearsTable,
    )..orderBy([(tbl) => OrderingTerm.desc(tbl.yearNumber)])).get();
    return rows
        .map(
          (r) => FiscalYearEntity(
            id: r.id,
            title: r.title,
            yearNumber: r.yearNumber,
            startDate: DateTime.fromMillisecondsSinceEpoch(r.startDate),
            endDate: DateTime.fromMillisecondsSinceEpoch(r.endDate),
            isClosed: r.isClosed,
            isActive: r.isActive,
            openingDocumentId: r.openingDocumentId,
            closingDocumentId: r.closingDocumentId,
            createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
          ),
        )
        .toList();
  }

  @override
  Future<FiscalYearEntity?> getActiveFiscalYear() async {
    final r =
        await (_db.select(_db.fiscalYearsTable)
              ..where((tbl) => tbl.isActive.equals(true))
              ..limit(1))
            .getSingleOrNull();
    if (r == null) return null;
    return FiscalYearEntity(
      id: r.id,
      title: r.title,
      yearNumber: r.yearNumber,
      startDate: DateTime.fromMillisecondsSinceEpoch(r.startDate),
      endDate: DateTime.fromMillisecondsSinceEpoch(r.endDate),
      isClosed: r.isClosed,
      isActive: r.isActive,
      openingDocumentId: r.openingDocumentId,
      closingDocumentId: r.closingDocumentId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAt),
    );
  }

  @override
  Future<FiscalYearEntity> createFiscalYear(FiscalYearEntity fiscalYear) async {
    final id = fiscalYear.id.isEmpty ? _uuid.v4() : fiscalYear.id;
    final now = DateTime.now();
    await _db
        .into(_db.fiscalYearsTable)
        .insert(
          FiscalYearsTableCompanion.insert(
            id: id,
            title: fiscalYear.title,
            yearNumber: fiscalYear.yearNumber,
            startDate: fiscalYear.startDate.millisecondsSinceEpoch,
            endDate: fiscalYear.endDate.millisecondsSinceEpoch,
            isClosed: Value(fiscalYear.isClosed),
            isActive: Value(fiscalYear.isActive),
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
    return fiscalYear.copyWith(id: id, createdAt: now, updatedAt: now);
  }

  @override
  Future<void> setActiveFiscalYear(String id) async {
    await _db.transaction(() async {
      await _db
          .update(_db.fiscalYearsTable)
          .write(const FiscalYearsTableCompanion(isActive: Value(false)));
      await (_db.update(_db.fiscalYearsTable)
            ..where((tbl) => tbl.id.equals(id)))
          .write(const FiscalYearsTableCompanion(isActive: Value(true)));
    });
  }

  @override
  Future<void> closeFiscalYear(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.fiscalYearsTable,
    )..where((tbl) => tbl.id.equals(id))).write(
      FiscalYearsTableCompanion(
        isClosed: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  // ─── Phase 1: integrity, audit, floating details, fiscal close/open ───

  /// Throws when [date] falls inside a CLOSED fiscal year. Documents in open
  /// or unassigned periods pass. The closed window is inclusive of the whole
  /// last day — the first day of the NEXT year must stay registrable.
  Future<void> _ensurePeriodOpen(DateTime date) async {
    final years = await getFiscalYears();
    for (final fy in years) {
      if (!fy.isClosed) continue;
      final endOfLastDay = DateTime(
        fy.endDate.year,
        fy.endDate.month,
        fy.endDate.day,
        23,
        59,
        59,
        999,
      );
      if (!date.isBefore(fy.startDate) && !date.isAfter(endOfLastDay)) {
        throw StateError(
          'دوره مالی ${fy.title} بسته شده است و ثبت در آن مجاز نیست.',
        );
      }
    }
  }

  /// End-of-day helper matching [_ensurePeriodOpen]'s inclusive boundary.
  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// True when [date] falls inside [fy] (whole last day inclusive).
  bool dateWithinFiscalYear(DateTime date, FiscalYearEntity fy) {
    return !date.isBefore(fy.startDate) && !date.isAfter(_endOfDay(fy.endDate));
  }

  String _documentSnapshotJson(
    String id,
    int number,
    AccountingDocumentEntity document,
  ) {
    return jsonEncode({
      'id': id,
      'number': number,
      'title': document.title,
      'date': document.date.toIso8601String(),
      'status': document.status.code,
      'totalDebitMinor': document.totalDebit.minorUnits,
      'totalCreditMinor': document.totalCredit.minorUnits,
      'lines': document.transactions
          .map(
            (t) => {
              'subjectId': t.subjectId,
              'debit': t.debit.minorUnits,
              'credit': t.credit.minorUnits,
              'description': t.description,
            },
          )
          .toList(),
    });
  }

  Future<void> _insertAuditLog({
    required AuditLogAction action,
    required String entityId,
    String? beforeJson,
    String? afterJson,
    String? description,
    required DateTime at,
  }) async {
    await _db
        .into(_db.accountingAuditLogsTable)
        .insert(
          AccountingAuditLogsTableCompanion.insert(
            id: _uuid.v4(),
            entityType: 'document',
            entityId: entityId,
            action: action.code,
            beforeJson: Value(beforeJson),
            afterJson: Value(afterJson),
            description: Value(description),
            performedAt: at.millisecondsSinceEpoch,
            createdAt: at.millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> _applyDetailTags(
    String documentId,
    List<DocumentDetailTag> tags,
    DateTime now,
  ) async {
    for (final tag in tags) {
      await _db
          .into(_db.accountingDocumentDetailLinksTable)
          .insert(
            AccountingDocumentDetailLinksTableCompanion.insert(
              id: _uuid.v4(),
              documentId: documentId,
              ledgerId: tag.ledgerId,
              valueId: tag.valueId,
              createdAt: now.millisecondsSinceEpoch,
            ),
          );
    }
  }

  @override
  Stream<List<AccountingAuditLogEntity>> watchAuditLogs({int limit = 200}) {
    final query = _db.select(_db.accountingAuditLogsTable)
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.performedAt)])
      ..limit(limit);
    return query.watch().map((rows) {
      return rows.map((r) {
        return AccountingAuditLogEntity(
          id: r.id,
          entityType: r.entityType,
          entityId: r.entityId,
          action: AuditLogAction.fromCode(r.action),
          beforeJson: r.beforeJson,
          afterJson: r.afterJson,
          description: r.description,
          performedAt: DateTime.fromMillisecondsSinceEpoch(r.performedAt),
        );
      }).toList();
    });
  }

  @override
  Stream<List<AccountingAuditLogEntity>> watchEntityAuditLogs({
    required String entityType,
    required String entityId,
  }) {
    final query = _db.select(_db.accountingAuditLogsTable)
      ..where(
        (tbl) =>
            tbl.entityType.equals(entityType) & tbl.entityId.equals(entityId),
      )
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.performedAt)]);
    return query.watch().map((rows) {
      return rows.map((r) {
        return AccountingAuditLogEntity(
          id: r.id,
          entityType: r.entityType,
          entityId: r.entityId,
          action: AuditLogAction.fromCode(r.action),
          beforeJson: r.beforeJson,
          afterJson: r.afterJson,
          description: r.description,
          performedAt: DateTime.fromMillisecondsSinceEpoch(r.performedAt),
        );
      }).toList();
    });
  }

  @override
  Future<String> createDetailLedger({
    required String title,
    required String code,
  }) async {
    // Floating detail dimension limit: max 10 ledgers.
    final existing = await (_db.select(
      _db.accountingDetailLedgersTable,
    )..where((tbl) => tbl.deletedAt.isNull())).get();
    if (existing.length >= 10) {
      throw StateError('حداکثر ۱۰ تفصیلی شناور قابل تعریف است.');
    }
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.accountingDetailLedgersTable)
        .insert(
          AccountingDetailLedgersTableCompanion.insert(
            id: id,
            title: title,
            code: code,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  @override
  Future<void> updateDetailLedger({
    required String id,
    required String title,
    bool? isActive,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(
      _db.accountingDetailLedgersTable,
    )..where((tbl) => tbl.id.equals(id))).write(
      AccountingDetailLedgersTableCompanion(
        title: Value(title),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> deleteDetailLedger(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.accountingDetailLedgersTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(AccountingDetailLedgersTableCompanion(deletedAt: Value(now)));
    await (_db.update(_db.accountingDetailValuesTable)
          ..where((tbl) => tbl.ledgerId.equals(id)))
        .write(AccountingDetailValuesTableCompanion(deletedAt: Value(now)));
  }

  @override
  Future<List<DetailLedgerWithValues>> getDetailLedgers() async {
    final ledgers =
        await (_db.select(_db.accountingDetailLedgersTable)
              ..where((tbl) => tbl.deletedAt.isNull())
              ..orderBy([(tbl) => OrderingTerm.asc(tbl.sortOrder)]))
            .get();
    final result = <DetailLedgerWithValues>[];
    for (final l in ledgers) {
      final values =
          await (_db.select(_db.accountingDetailValuesTable)..where(
                (tbl) => tbl.ledgerId.equals(l.id) & tbl.deletedAt.isNull(),
              ))
              .get();
      result.add(
        DetailLedgerWithValues(
          ledger: DetailLedgerEntity(
            id: l.id,
            title: l.title,
            code: l.code,
            isActive: l.isActive,
            sortOrder: l.sortOrder,
          ),
          values: values
              .map(
                (v) => DetailValueEntity(
                  id: v.id,
                  ledgerId: v.ledgerId,
                  title: v.title,
                  code: v.code,
                  isActive: v.isActive,
                ),
              )
              .toList(),
        ),
      );
    }
    return result;
  }

  @override
  Future<String> createDetailValue({
    required String ledgerId,
    required String title,
    String? code,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.accountingDetailValuesTable)
        .insert(
          AccountingDetailValuesTableCompanion.insert(
            id: id,
            ledgerId: ledgerId,
            title: title,
            code: Value(code),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  @override
  Future<void> deleteDetailValue(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.accountingDetailValuesTable)
          ..where((tbl) => tbl.id.equals(id)))
        .write(AccountingDetailValuesTableCompanion(deletedAt: Value(now)));
  }

  @override
  Future<void> setDocumentDetails({
    required String documentId,
    required List<DocumentDetailTag> tags,
  }) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.delete(
        _db.accountingDocumentDetailLinksTable,
      )..where((tbl) => tbl.documentId.equals(documentId))).go();
      await _applyDetailTags(documentId, tags, now);
    });
  }

  @override
  Future<List<DocumentDetailTag>> getDocumentDetails(String documentId) async {
    final rows = await (_db.select(
      _db.accountingDocumentDetailLinksTable,
    )..where((tbl) => tbl.documentId.equals(documentId))).get();
    return rows
        .map((r) => DocumentDetailTag(ledgerId: r.ledgerId, valueId: r.valueId))
        .toList();
  }

  @override
  Future<DetailReport> getDetailReport({
    required String ledgerId,
    required String valueId,
    String? subjectId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final ledgers = await getDetailLedgers();
    final ledgerMatches = ledgers
        .where((l) => l.ledger.id == ledgerId)
        .map((l) => l.ledger)
        .toList();
    if (ledgerMatches.isEmpty) {
      throw StateError('دفتر تفصیلی پیدا نشد.');
    }
    final ledger = ledgerMatches.first;
    DetailValueEntity? value;
    for (final l in ledgers) {
      for (final v in l.values) {
        if (v.id == valueId) value = v;
      }
    }
    if (value == null) throw StateError('مقدار تفصیلی پیدا نشد.');

    // Approved documents tagged with this value, chronological.
    final links =
        await (_db.select(_db.accountingDocumentDetailLinksTable).join([
              innerJoin(
                _db.accountingDocumentsTable,
                _db.accountingDocumentsTable.id.equalsExp(
                  _db.accountingDocumentDetailLinksTable.documentId,
                ),
              ),
            ])..where(
              _db.accountingDocumentDetailLinksTable.valueId.equals(valueId) &
                  _db.accountingDocumentDetailLinksTable.ledgerId.equals(
                    ledgerId,
                  ) &
                  // Final documents only — posted must count too, and drafts
                  // must not (same rule as every other report).
                  _db.accountingDocumentsTable.status.isIn(
                    const ['approved', 'posted'],
                  ) &
                  _db.accountingDocumentsTable.deletedAt.isNull(),
            ))
            .get();

    final docIds =
        links.map((l) => l.readTable(_db.accountingDocumentsTable)).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final rows = <DetailReportRow>[];
    int running = 0;
    int totalDebit = 0;
    int totalCredit = 0;

    for (final doc in docIds) {
      if (startDate != null &&
          DateTime.fromMillisecondsSinceEpoch(doc.date).isBefore(startDate)) {
        continue;
      }
      if (endDate != null &&
          DateTime.fromMillisecondsSinceEpoch(doc.date).isAfter(endDate)) {
        continue;
      }
      final txs =
          await (_db.select(_db.accountingTransactionsTable)..where(
                (tbl) => tbl.documentId.equals(doc.id) & tbl.deletedAt.isNull(),
              ))
              .get();
      for (final tx in txs) {
        if (subjectId != null && tx.subjectId != subjectId) continue;
        final subject = await getSubjectById(tx.subjectId);
        running += tx.debitMinorUnits - tx.creditMinorUnits;
        totalDebit += tx.debitMinorUnits;
        totalCredit += tx.creditMinorUnits;
        rows.add(
          DetailReportRow(
            date: DateTime.fromMillisecondsSinceEpoch(doc.date),
            documentNumber: doc.number,
            documentTitle: doc.title,
            subjectName: subject?.name ?? tx.subjectId,
            description: tx.description,
            debitMinorUnits: tx.debitMinorUnits,
            creditMinorUnits: tx.creditMinorUnits,
            runningBalanceMinorUnits: running,
          ),
        );
      }
    }

    return DetailReport(
      ledger: ledger,
      value: value,
      rows: rows,
      totalDebitMinorUnits: totalDebit,
      totalCreditMinorUnits: totalCredit,
    );
  }

  /// Direct signed net (debit − credit) per subject over a document range,
  /// FINAL documents only, counted once per posting (no hierarchy rollup).
  Future<Map<String, int>> _directNetsForRange({
    required DateTime startDate,
    required DateTime endDate,
    String? fiscalYearId,
  }) async {
    final docs = (await getDocuments(
      startDate: startDate,
      endDate: endDate,
      fiscalYearId: fiscalYearId,
    ))
        .where(_isFinalDoc)
        .toList();
    final nets = <String, int>{};
    for (final doc in docs) {
      for (final tx in doc.transactions) {
        nets[tx.subjectId] =
            (nets[tx.subjectId] ?? 0) +
                (tx.debit.minorUnits - tx.credit.minorUnits);
      }
    }
    return nets;
  }

  @override
  Future<AccountingDocumentEntity> closeFiscalYearWithDocuments(
    String fiscalYearId,
  ) async {
    final fy = (await getFiscalYears())
        .where((f) => f.id == fiscalYearId)
        .firstOrNull;
    if (fy == null) throw StateError('سال مالی پیدا نشد.');
    if (fy.isClosed) throw StateError('این سال مالی قبلاً بسته شده است.');

    final now = DateTime.now();
    final subjects = await getAllSubjects();

    // One pass over the year's FINAL documents: DIRECT net per subject —
    // no descendant aggregation. Aggregating kols AND their moein children
    // counts every balance twice; leaf-only aggregation drops postings made
    // directly on a kol. Direct nets partition every posting exactly once,
    // so Σ over ALL subjects is zero by the double-entry identity — which
    // makes BOTH the closing and the opening voucher balanced by
    // construction.
    final netBySubject = await _directNetsForRange(
      startDate: fy.startDate,
      endDate: fy.endDate,
      fiscalYearId: fiscalYearId,
    );

    // Balanced closing voucher: temporary accounts → accumulated P/L.
    final closingDoc = AccountingDocumentEntity(
      id: _uuid.v4(),
      number: await getNextDocumentNumber(fiscalYearId),
      date: fy.endDate,
      title: 'سند اختتامیه ${fy.title}',
      status: DocumentStatus.approved,
      isManual: false,
      referenceType: 'closing',
      referenceId: fiscalYearId,
      fiscalYearId: fiscalYearId,
      approvedAt: now,
      createdAt: now,
      updatedAt: now,
      transactions: const [],
    );

    final rows = <AccountingTransactionEntity>[];
    int netMinor = 0;
    for (final subject in subjects) {
      if (subject.isPermanent) continue;
      final net = netBySubject[subject.id] ?? 0;
      if (net == 0) continue;
      netMinor += net;
      // net > 0 = debit balance (expense) → CREDIT it to zero it out.
      // net < 0 = credit balance (revenue) → DEBIT it.
      rows.add(
        AccountingTransactionEntity(
          id: _uuid.v4(),
          documentId: closingDoc.id,
          subjectId: subject.id,
          debit: Money.fromMinor(net < 0 ? -net : 0),
          credit: Money.fromMinor(net > 0 ? net : 0),
          description: 'بستن حساب ${subject.name}',
          rowOrder: rows.length + 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // Accumulated profit/loss lands on equity (030): loss (netMinor > 0)
    // debits equity, profit (netMinor < 0) credits it — balancing the rows
    // above (D − C = −netMinor).
    final plSubject =
        await getSubjectByCode('030001') ?? await getSubjectByCode('030');
    if (plSubject != null && netMinor != 0) {
      rows.add(
        AccountingTransactionEntity(
          id: _uuid.v4(),
          documentId: closingDoc.id,
          subjectId: plSubject.id,
          debit: Money.fromMinor(netMinor > 0 ? netMinor : 0),
          credit: Money.fromMinor(netMinor < 0 ? -netMinor : 0),
          description: 'سود (زیان) ویژه دوره',
          rowOrder: rows.length + 1,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    AccountingDocumentEntity? savedClosing;
    await _db.transaction(() async {
      // The whole close is atomic: closing voucher, next fiscal year,
      // opening voucher and the close/activate flags succeed or roll back
      // together — no orphan documents, no half-open year.
      if (rows.isNotEmpty) {
        savedClosing = await createDocument(
          closingDoc.copyWith(transactions: rows),
        );
        await approveDocument(savedClosing!.id);
      }

      // Create the next fiscal year aligned to the same calendar as the one
      // being closed (Jalali-aligned years stay Jalali-aligned).
      final nextStart = fy.endDate.add(const Duration(days: 1));
      final nextEnd = endOfJalaliYear(nextStart);
      final nextId = _uuid.v4();
      final nextYear = FiscalYearEntity(
        id: nextId,
        title: 'سال مالی ${fy.yearNumber + 1}',
        yearNumber: fy.yearNumber + 1,
        startDate: nextStart,
        endDate: nextEnd,
        createdAt: now,
        updatedAt: now,
      );
      await createFiscalYear(nextYear);

      // Opening balances read AFTER the closing voucher is saved, so equity
      // (030001) already carries the period's P/L transfer. Direct nets of
      // PERMANENT subjects only — their sum is exactly zero post-close
      // (Σ temporary was folded into 030001), so the opening voucher is
      // balanced by construction.
      final postCloseNets = await _directNetsForRange(
        startDate: fy.startDate,
        endDate: fy.endDate,
        fiscalYearId: fiscalYearId,
      );
      final openingRows = <AccountingTransactionEntity>[];
      for (final subject in subjects) {
        if (!subject.isPermanent) continue;
        final net = postCloseNets[subject.id] ?? 0;
        if (net == 0) continue;
        openingRows.add(
          AccountingTransactionEntity(
            id: _uuid.v4(),
            documentId: 'opening-$nextId',
            subjectId: subject.id,
            debit: Money.fromMinor(net > 0 ? net : 0),
            credit: Money.fromMinor(net < 0 ? -net : 0),
            description: 'مانده افتتاحیه ${subject.name}',
            rowOrder: openingRows.length + 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      if (openingRows.isNotEmpty) {
        final openingDoc = AccountingDocumentEntity(
          id: 'opening-$nextId',
          number: await getNextDocumentNumber(nextId),
          date: nextStart,
          title: 'سند افتتاحیه ${nextYear.title}',
          status: DocumentStatus.approved,
          isManual: false,
          referenceType: 'opening',
          referenceId: nextId,
          fiscalYearId: nextId,
          approvedAt: now,
          createdAt: now,
          updatedAt: now,
          transactions: openingRows,
        );
        await createDocument(openingDoc);
        await approveDocument(openingDoc.id);
      }

      // Mark the old year closed with its closing document, activate the new
      // one — AFTER the opening voucher exists, so the new period's first
      // day is already registrable when the lock engages.
      await (_db.update(
        _db.fiscalYearsTable,
      )..where((tbl) => tbl.id.equals(fiscalYearId))).write(
        FiscalYearsTableCompanion(
          isClosed: const Value(true),
          isActive: const Value(false),
          closingDocumentId: Value(savedClosing?.id),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ),
      );
      await setActiveFiscalYear(nextId);
      await (_db.update(
        _db.fiscalYearsTable,
      )..where((tbl) => tbl.id.equals(nextId))).write(
        FiscalYearsTableCompanion(
          openingDocumentId: openingRows.isNotEmpty
              ? Value('opening-$nextId')
              : const Value(null),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ),
      );
    });

    return savedClosing ?? closingDoc;
  }
}
