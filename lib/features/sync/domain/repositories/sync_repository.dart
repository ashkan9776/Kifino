import '../../../../core/errors/result.dart';
import '../entities/sync_operation_entity.dart';

abstract interface class SyncRepository {
  Stream<int> watchPendingCount();
  Stream<List<SyncOperationEntity>> watchPendingOperations();
  Stream<List<SyncOperationEntity>> watchFailedOperations();

  Future<Result<List<SyncOperationEntity>>> getPendingOperations({int limit = 50});
  Future<Result<void>> markOperationSuccess(int queueId);
  Future<Result<void>> recordOperationFailure(int queueId, String error);
  Future<Result<void>> retryAllFailed();
  Future<Result<void>> clearQueue();
  Future<Result<void>> enqueueOperation(SyncOperationEntity operation);
}
