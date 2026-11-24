import 'package:drift/drift.dart';

/// A rule that produces a transaction on a schedule: rent, salary,
/// subscriptions, phone bills (v11).
///
/// Occurrence `n` (0-based) falls on `step(startDate, n)`; [nextIndex] is the
/// first occurrence not yet posted or skipped, and [nextRunDate] caches its
/// date so "what is due" is a single indexed query.
@DataClassName('RecurringRuleData')
class RecurringRulesTable extends Table {
  @override
  String get tableName => 'recurring_rules';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get type => text()(); // income, expense, transfer
  TextColumn get accountId => text()();
  TextColumn get destinationAccountId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get frequency => text()(); // daily, weekly, monthly, yearly
  IntColumn get intervalCount => integer().withDefault(const Constant(1))();
  IntColumn get startDate => integer()();
  IntColumn get nextIndex => integer().withDefault(const Constant(0))();
  IntColumn get nextRunDate => integer()();
  IntColumn get endDate => integer().nullable()();
  IntColumn get maxOccurrences => integer().nullable()();
  IntColumn get postedCount => integer().withDefault(const Constant(0))();

  /// True: post automatically when due. False: remind, the user confirms.
  BoolColumn get autoPost => boolean().withDefault(const Constant(true))();
  IntColumn get remindDaysBefore => integer().withDefault(const Constant(1))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get notes => text().nullable()();
  TextColumn get lastError => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
