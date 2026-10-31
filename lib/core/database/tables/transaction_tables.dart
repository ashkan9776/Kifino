import 'package:drift/drift.dart';

@DataClassName('TransactionData')
class TransactionsTable extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get destinationAccountId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get type => text()(); // income, expense, transfer, debtPayment, receivablePayment, adjustment
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  IntColumn get transactionDate => integer()();
  TextColumn get description => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isBusiness => boolean().withDefault(const Constant(false))();
  RealColumn get locationLat => real().nullable()();
  RealColumn get locationLng => real().nullable()();
  TextColumn get locationName => text().nullable()();
  TextColumn get attachmentUri => text().nullable()();
  TextColumn get recurringRuleId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransactionTagData')
class TransactionTagsTable extends Table {
  @override
  String get tableName => 'transaction_tags';

  TextColumn get transactionId => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}
