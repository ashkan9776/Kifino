import 'package:drift/drift.dart';

@DataClassName('AccountData')
class AccountsTable extends Table {
  @override
  String get tableName => 'accounts';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // bankCard, cashWallet, savings, credit, investment, crypto
  TextColumn get currency => text()(); // IRR, TOMAN, USD, EUR, etc.
  IntColumn get initialBalanceMinor => integer().withDefault(const Constant(0))();
  IntColumn get currentBalanceMinor => integer().withDefault(const Constant(0))();
  TextColumn get cardNumberLastFour => text().nullable()();
  TextColumn get bankName => text().nullable()();
  TextColumn get colorHex => text().nullable()();
  TextColumn get iconName => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoryData')
class CategoriesTable extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // income, expense
  IntColumn get iconCodePoint => integer()();
  TextColumn get iconFontFamily => text().nullable()();
  TextColumn get colorHex => text()();
  TextColumn get parentId => text().nullable()();
  BoolColumn get isBusiness => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TagData')
class TagsTable extends Table {
  @override
  String get tableName => 'tags';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get colorHex => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
