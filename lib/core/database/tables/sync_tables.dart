import 'package:drift/drift.dart';

@DataClassName('SyncQueueData')
class SyncQueueTable extends Table {
  @override
  String get tableName => 'sync_queue';

  IntColumn get queueId => integer().autoIncrement()();
  TextColumn get syncEntityName => text().named('entity_name')();
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // INSERT, UPDATE, DELETE
  TextColumn get payloadJson => text()();
  TextColumn get idempotencyKey => text().unique()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  IntColumn get queuedAt => integer()();
}

@DataClassName('NotificationData')
class NotificationsTable extends Table {
  @override
  String get tableName => 'audit_notifications';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get type =>
      text()(); // installmentDue, checkDue, debtDue, budgetAlert, lowStock
  TextColumn get referenceId => text().nullable()();
  IntColumn get scheduledFor => integer()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
