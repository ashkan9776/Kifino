import 'package:drift/drift.dart';

@DataClassName('FinancialGoalData')
class FinancialGoalsTable extends Table {
  @override
  String get tableName => 'financial_goals';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get targetAmountMinor => integer()();
  IntColumn get currentAmountMinor =>
      integer().withDefault(const Constant(0))();
  TextColumn get currency => text()();
  IntColumn get targetDate => integer().nullable()();
  TextColumn get status => text()(); // active, achieved, cancelled
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
