import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/sync_operation_entity.dart';
import '../../domain/repositories/sync_repository.dart';

class SyncRepositoryImpl implements SyncRepository {
  final AppDatabase _db;

  const SyncRepositoryImpl(this._db);

  SyncOperationEntity _toEntity(SyncQueueData row) {
    return SyncOperationEntity(
      queueId: row.queueId,
      syncEntityName: row.syncEntityName,
      entityId: row.entityId,
      operation: SyncOperationType.fromCode(row.operation),
      payloadJson: row.payloadJson,
      idempotencyKey: row.idempotencyKey,
      retryCount: row.retryCount,
      lastError: row.lastError,
      queuedAt: DateTime.fromMillisecondsSinceEpoch(row.queuedAt),
    );
  }

  @override
  Stream<int> watchPendingCount() {
    final query = _db.selectOnly(_db.syncQueueTable)
      ..addColumns([_db.syncQueueTable.queueId.count()]);
    return query
        .map((row) => row.read(_db.syncQueueTable.queueId.count()) ?? 0)
        .watchSingle();
  }

  @override
  Stream<List<SyncOperationEntity>> watchPendingOperations() {
    final query = _db.select(_db.syncQueueTable)
      ..where((tbl) => tbl.retryCount.isSmallerThanValue(3))
      ..orderBy([(t) => OrderingTerm(expression: t.queuedAt, mode: OrderingMode.asc)]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Stream<List<SyncOperationEntity>> watchFailedOperations() {
    final query = _db.select(_db.syncQueueTable)
      ..where((tbl) => tbl.retryCount.isBiggerOrEqualValue(3))
      ..orderBy([(t) => OrderingTerm(expression: t.queuedAt, mode: OrderingMode.desc)]);
    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Result<List<SyncOperationEntity>>> getPendingOperations({int limit = 50}) async {
    try {
      final query = _db.select(_db.syncQueueTable)
        ..where((tbl) => tbl.retryCount.isSmallerThanValue(3))
        ..orderBy([(t) => OrderingTerm(expression: t.queuedAt, mode: OrderingMode.asc)])
        ..limit(limit);
      final rows = await query.get();
      return Success(rows.map(_toEntity).toList());
    } catch (e) {
      return FailureResult(DatabaseFailure('خطا در دریافت صف همگام‌سازی: $e'));
    }
  }

  @override
  Future<Result<void>> markOperationSuccess(int queueId) async {
    try {
      await (_db.delete(_db.syncQueueTable)..where((tbl) => tbl.queueId.equals(queueId))).go();
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('خطا در حذف عملیات موفق از صف: $e'));
    }
  }

  @override
  Future<Result<void>> recordOperationFailure(int queueId, String error) async {
    try {
      final row = await (_db.select(_db.syncQueueTable)..where((t) => t.queueId.equals(queueId))).getSingleOrNull();
      if (row != null) {
        await (_db.update(_db.syncQueueTable)..where((t) => t.queueId.equals(queueId))).write(
          SyncQueueTableCompanion(
            retryCount: Value(row.retryCount + 1),
            lastError: Value(error),
          ),
        );
      }
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('خطا در ثبت خطای عملیات همگام‌سازی: $e'));
    }
  }

  @override
  Future<Result<void>> retryAllFailed() async {
    try {
      await (_db.update(_db.syncQueueTable)..where((t) => t.retryCount.isBiggerOrEqualValue(3))).write(
        const SyncQueueTableCompanion(
          retryCount: Value(0),
          lastError: Value(null),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('خطا در بازنشانی صف خطاها: $e'));
    }
  }

  @override
  Future<Result<void>> clearQueue() async {
    try {
      await _db.delete(_db.syncQueueTable).go();
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('خطا در پاکسازی صف همگام‌سازی: $e'));
    }
  }

  @override
  Future<Result<void>> enqueueOperation(SyncOperationEntity operation) async {
    try {
      await _db.into(_db.syncQueueTable).insertOnConflictUpdate(
            SyncQueueTableCompanion.insert(
              syncEntityName: operation.syncEntityName,
              entityId: operation.entityId,
              operation: operation.operation.code,
              payloadJson: operation.payloadJson,
              idempotencyKey: operation.idempotencyKey,
              retryCount: Value(operation.retryCount),
              lastError: Value(operation.lastError),
              queuedAt: operation.queuedAt.millisecondsSinceEpoch,
            ),
          );
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('خطا در درج در صف همگام‌سازی: $e'));
    }
  }
}
