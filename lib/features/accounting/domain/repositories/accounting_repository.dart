import '../entities/accounting_audit_entity.dart';
import '../entities/accounting_document_entity.dart';
import '../entities/accounting_subject_entity.dart';
import '../entities/accounting_transaction_entity.dart';
import '../entities/financial_statement_report.dart';
import '../entities/fiscal_year_entity.dart';
import '../entities/ledger_entry.dart';
import '../entities/trial_balance_entry.dart';

abstract class AccountingRepository {
  // Chart of accounts
  Future<void> seedChartOfAccountsIfNotExists();
  Future<List<AccountingSubjectEntity>> getAllSubjects();
  Future<List<AccountingSubjectEntity>> getRootSubjects();
  Future<List<AccountingSubjectEntity>> getChildSubjects(String parentId);
  Future<AccountingSubjectEntity?> getSubjectByCode(String code);
  Future<AccountingSubjectEntity?> getSubjectById(String id);
  Future<AccountingSubjectEntity> createSubject(AccountingSubjectEntity subject);
  Future<AccountingSubjectEntity> updateSubject(AccountingSubjectEntity subject);
  Future<void> deleteSubject(String id);

  // Accounting Documents
  Future<List<AccountingDocumentEntity>> getDocuments({
    DateTime? startDate,
    DateTime? endDate,
    DocumentStatus? status,
    String? fiscalYearId,
  });
  Future<AccountingDocumentEntity?> getDocumentById(String id);
  Future<int> getNextDocumentNumber(String? fiscalYearId);
  Future<AccountingDocumentEntity> createDocument(AccountingDocumentEntity document);
  Future<AccountingDocumentEntity> updateDocument(AccountingDocumentEntity document);
  Future<void> approveDocument(String documentId);
  Future<void> deleteDocument(String documentId);

  // Official Reports
  Future<List<AccountingTransactionEntity>> getJournalTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? fiscalYearId,
  });
  Future<LedgerReport> getLedgerReport({
    required String subjectId,
    DateTime? startDate,
    DateTime? endDate,
    String? fiscalYearId,
  });
  Future<TrialBalanceReport> getTrialBalanceReport({
    AccountingSubjectLevel level = AccountingSubjectLevel.kol,
    DateTime? startDate,
    DateTime? endDate,
    String? fiscalYearId,
  });
  Future<BalanceSheetReport> getBalanceSheetReport({
    required DateTime asOfDate,
    String? fiscalYearId,
  });
  Future<IncomeStatementReport> getIncomeStatementReport({
    required DateTime startDate,
    required DateTime endDate,
    String? fiscalYearId,
  });

  // Fiscal Years
  Future<List<FiscalYearEntity>> getFiscalYears();
  Future<FiscalYearEntity?> getActiveFiscalYear();
  Future<FiscalYearEntity> createFiscalYear(FiscalYearEntity fiscalYear);
  Future<void> setActiveFiscalYear(String id);
  Future<void> closeFiscalYear(String id);

  // ── Phase 1: integrity, audit, floating details, fiscal close/open ──

  /// Audit trail for accounting documents, newest first.
    Stream<List<AccountingAuditLogEntity>> watchAuditLogs({int limit});

  /// Audit entries for one entity (e.g. a check's status history), newest first.
  Stream<List<AccountingAuditLogEntity>> watchEntityAuditLogs({
    required String entityType,
    required String entityId,
  });

  /// تفصیلی شناور — dimension ledgers with their values.
  Future<String> createDetailLedger({
    required String title,
    required String code,
  });
  Future<void> updateDetailLedger({
    required String id,
    required String title,
    bool? isActive,
  });
  Future<void> deleteDetailLedger(String id);
  Future<List<DetailLedgerWithValues>> getDetailLedgers();
  Future<String> createDetailValue({
    required String ledgerId,
    required String title,
    String? code,
  });
  Future<void> deleteDetailValue(String id);

  /// Replaces the detail tags of a document (one value per ledger).
  Future<void> setDocumentDetails({
    required String documentId,
    required List<DocumentDetailTag> tags,
  });
  Future<List<DocumentDetailTag>> getDocumentDetails(String documentId);

  /// تفصیلی شناور report: entries of every approved document tagged with the
  /// given value, with running balance.
  Future<DetailReport> getDetailReport({
    required String ledgerId,
    required String valueId,
    String? subjectId,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Closes the fiscal year: builds the balanced closing voucher (temporary
  /// accounts → accumulated profit/loss), locks the period, creates the next
  /// fiscal year and its balanced opening voucher. Returns the closing doc.
  Future<AccountingDocumentEntity> closeFiscalYearWithDocuments(String fiscalYearId);
}
