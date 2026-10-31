import 'package:drift/drift.dart';

@DataClassName('BusinessContactData')
class BusinessContactsTable extends Table {
  @override
  String get tableName => 'business_contacts';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get companyName => text().nullable()();
  TextColumn get type => text()(); // customer, supplier, both
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get taxNumber => text().nullable()();
  IntColumn get outstandingBalanceMinor => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ProductData')
class ProductsTable extends Table {
  @override
  String get tableName => 'products';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get barcode => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('unit'))();
  TextColumn get secondaryUnit => text().nullable()(); // e.g. 'کارتن' when unit is 'عدد'
  IntColumn get conversionFactor => integer()
      .withDefault(const Constant(1))(); // base units per secondary unit
  IntColumn get purchasePriceMinor => integer().withDefault(const Constant(0))();
  IntColumn get sellingPriceMinor => integer()();
  TextColumn get currency => text()();
  RealColumn get currentStock => real().withDefault(const Constant(0.0))();
  RealColumn get lowStockThreshold => real().withDefault(const Constant(5.0))();
  TextColumn get supplierId => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InventoryLogData')
class InventoryLogsTable extends Table {
  @override
  String get tableName => 'inventory_logs';

  TextColumn get id => text()();
  TextColumn get productId => text()();
  RealColumn get changeQuantity => real()();
  TextColumn get movementType => text()(); // purchase, sale, adjustment, return, loss
  TextColumn get referenceId => text().nullable()(); // invoiceId
  IntColumn get costPerUnitMinor => integer().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InvoiceData')
class InvoicesTable extends Table {
  @override
  String get tableName => 'invoices';

  TextColumn get id => text()();
  TextColumn get invoiceNumber => text()();
  TextColumn get contactId => text()();
  TextColumn get type => text()(); // sale, purchase, quote
  TextColumn get status => text()(); // draft, sent, partiallyPaid, paid, overdue, cancelled
  IntColumn get issueDate => integer()();
  IntColumn get dueDate => integer()();
  IntColumn get subtotalMinor => integer()();
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();
  IntColumn get taxMinor => integer().withDefault(const Constant(0))();
  IntColumn get totalMinor => integer()();
  IntColumn get paidMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get terms => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('InvoiceItemData')
class InvoiceItemsTable extends Table {
  @override
  String get tableName => 'invoice_items';

  TextColumn get id => text()();
  TextColumn get invoiceId => text()();
  TextColumn get productId => text().nullable()();
  TextColumn get description => text()();
  RealColumn get quantity => real()();
  IntColumn get unitPriceMinor => integer()();
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();
  IntColumn get taxMinor => integer().withDefault(const Constant(0))();
  IntColumn get totalMinor => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get deletedAt => integer().nullable()();
  IntColumn get syncStatus => integer().withDefault(const Constant(0))();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}
