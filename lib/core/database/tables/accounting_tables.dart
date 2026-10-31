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
  TextColumn get referenceType => text().nullable()(); // 'invoice', 'cheque', 'payment', 'transfer'
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
