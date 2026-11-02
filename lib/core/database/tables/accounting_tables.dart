import 'package:drift/drift.dart';

@DataClassName('AccountingSubjectData')
class AccountingSubjectsTable extends Table {
  @override
  String get tableName => 'accounting_subjects';

  TextColumn get id => text()();
  TextColumn get code => text()(); // e.g., '010', '011001', '011001001'
  TextColumn get name => text()(); // e.g., 'بانکها', 'صندوق', 'بدهکاران تجاری'
  TextColumn get parentId => text().nullable()();
  TextColumn get type => text()(); // 'debtor', 'creditor', 'both'
  TextColumn get level => text()(); // 'group', 'kol', 'moein', 'tafsili'
  BoolColumn get isPermanent => boolean().withDefault(const Constant(true))();
  TextColumn get fiscalYearId => text().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AccountingDocumentData')
class AccountingDocumentsTable extends Table {
  @override
  String get tableName => 'accounting_documents';

  TextColumn get id => text()();
  IntColumn get number => integer()(); // Document number (1, 2, 3...)
  IntColumn get date => integer()(); // timestamp
  TextColumn get title => text()();
  TextColumn get status => text()(); // 'draft', 'approved', 'posted'
  BoolColumn get isManual => boolean().withDefault(const Constant(true))();
  TextColumn get referenceType =>
      text().nullable()(); // 'invoice', 'cheque', 'payment', 'transfer'
  TextColumn get referenceId => text().nullable()();
  TextColumn get fiscalYearId => text().nullable()();
  IntColumn get approvedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AccountingTransactionData')
class AccountingTransactionsTable extends Table {
  @override
  String get tableName => 'accounting_transactions';

  TextColumn get id => text()();
  TextColumn get documentId => text()();
  TextColumn get subjectId => text()();
  TextColumn get detailSubjectId => text().nullable()();
  IntColumn get debitMinorUnits => integer().withDefault(const Constant(0))();
  IntColumn get creditMinorUnits => integer().withDefault(const Constant(0))();
  TextColumn get description => text()();
  IntColumn get rowOrder => integer().withDefault(const Constant(1))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('FiscalYearData')
class FiscalYearsTable extends Table {
  @override
  String get tableName => 'fiscal_years';

  TextColumn get id => text()();
  TextColumn get title => text()(); // e.g. 'سال مالی 1403'
  IntColumn get yearNumber => integer()(); // e.g. 1403
  IntColumn get startDate => integer()();
  IntColumn get endDate => integer()();
  BoolColumn get isClosed => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get openingDocumentId => text().nullable()();
  TextColumn get closingDocumentId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AccountingAuditLogData')
class AccountingAuditLogsTable extends Table {
  @override
  String get tableName => 'accounting_audit_logs';

  TextColumn get id => text()();
  TextColumn get entityType => text()(); // 'document'
  TextColumn get entityId => text()();
  TextColumn get action => text()(); // 'create', 'update', 'approve', 'delete'
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get performedAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// تفصیلی شناور — a named analysis dimension (customers, projects, cost
/// centers) that tags documents without duplicating accounts. Max 10 ledgers.
@DataClassName('AccountingDetailLedgerData')
class AccountingDetailLedgersTable extends Table {
  @override
  String get tableName => 'accounting_detail_ledgers';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get code => text()(); // 'customer', 'project', 'cost_center', ...
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AccountingDetailValueData')
class AccountingDetailValuesTable extends Table {
  @override
  String get tableName => 'accounting_detail_values';

  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  TextColumn get title => text()();
  TextColumn get code => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Links a document to one detail value per ledger (max one per ledger).
@DataClassName('AccountingDocumentDetailLinkData')
class AccountingDocumentDetailLinksTable extends Table {
  @override
  String get tableName => 'accounting_document_detail_links';

  TextColumn get id => text()();
  TextColumn get documentId => text()();
  TextColumn get ledgerId => text()();
  TextColumn get valueId => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
