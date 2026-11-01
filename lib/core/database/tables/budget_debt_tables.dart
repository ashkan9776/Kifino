import 'package:drift/drift.dart';

@DataClassName('BudgetData')
class BudgetsTable extends Table {
  @override
  String get tableName => 'budgets';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get amountLimitMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get periodType => text()(); // monthly, weekly, custom
  IntColumn get startDate => integer()();
  IntColumn get endDate => integer()();
  RealColumn get alertThresholdPercent => real().withDefault(const Constant(80.0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('BudgetCategoryData')
class BudgetCategoriesTable extends Table {
  @override
  String get tableName => 'budget_categories';

  TextColumn get budgetId => text()();
  TextColumn get categoryId => text()();

  @override
  Set<Column> get primaryKey => {budgetId, categoryId};
}

@DataClassName('DebtReceivableData')
class DebtsReceivablesTable extends Table {
  @override
  String get tableName => 'debts_receivables';

  TextColumn get id => text()();
  TextColumn get contactName => text()();
  TextColumn get contactPhone => text().nullable()();
  TextColumn get type => text()(); // debt, receivable
  IntColumn get totalAmountMinor => integer()();
  IntColumn get paidAmountMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text()();
  IntColumn get dueDate => integer().nullable()();
  TextColumn get status => text()(); // active, settled, overdue, writtenOff
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InstallmentData')
class InstallmentsTable extends Table {
  @override
  String get tableName => 'installments';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get accountId => text()();
  IntColumn get totalAmountMinor => integer()();
  TextColumn get currency => text()();
  IntColumn get numberOfInstallments => integer()();
  IntColumn get paidInstallmentsCount => integer().withDefault(const Constant(0))();
  IntColumn get installmentAmountMinor => integer()();
  IntColumn get startDate => integer()();
  IntColumn get recurrenceIntervalDays => integer().withDefault(const Constant(30))();
  IntColumn get nextDueDate => integer()();
  TextColumn get status => text()(); // ongoing, completed, overdue
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CheckData')
class ChecksTable extends Table {
  @override
  String get tableName => 'checks';

  TextColumn get id => text()();
  TextColumn get checkNumber => text()();
  TextColumn get sayadiId => text().nullable()();
  TextColumn get bankName => text()();
  TextColumn get type => text()(); // issued, received
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get partyName => text()();
  IntColumn get dueDate => integer()();
  TextColumn get accountId => text().nullable()();
  TextColumn get status => text()(); // pending, cleared, bounced, cancelled, transferred
  TextColumn get frontImagePath => text().nullable()();
  TextColumn get backImagePath => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('AssetData')
class AssetsTable extends Table {
  @override
  String get tableName => 'assets';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text()(); // gold, currency, crypto, stock, property, vehicle, other
  TextColumn get customTypeName => text().nullable()(); // user-defined type when category = other
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  IntColumn get costBasisMinor => integer()();
  IntColumn get currentValueMinor => integer()();
  TextColumn get currency => text()();
  IntColumn get purchaseDate => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}


/// Payment history for one installment plan (Phase 3 rework): every «پرداخت
/// قسط» records a row here so users can review and correct payments.
@DataClassName('InstallmentPaymentData')
class InstallmentPaymentsTable extends Table {
  @override
  String get tableName => 'installment_payments';

  TextColumn get id => text()();
  TextColumn get installmentId => text()();
  IntColumn get amountMinor => integer()();
  IntColumn get installmentIndex => integer()(); // which قسط (1-based)
  TextColumn? get ledgerTransactionId => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get paidAt => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
