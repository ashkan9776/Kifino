import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../entities/sync_operation_entity.dart';

abstract interface class RemoteSyncClient {
  Future<Result<void>> pushOperation(SyncOperationEntity operation);
  Future<Result<List<Map<String, dynamic>>>> pullChanges({DateTime? since});
}

class ProductionRemoteSyncClient implements RemoteSyncClient {
  final bool simulateSuccess;

  const ProductionRemoteSyncClient({this.simulateSuccess = true});

  @override
  Future<Result<void>> pushOperation(SyncOperationEntity operation) async {
    try {
      // Simulate remote network latency
      await Future.delayed(const Duration(milliseconds: 150));

      if (!simulateSuccess) {
        return const FailureResult(
          NetworkFailure('عدم پاسخگویی سرور ابری (خطای 503 Service Unavailable)'),
        );
      }

      // In real deployment with backend endpoint:
      // final response = await dio.post('/api/v1/sync/push', data: {...}, options: Options(headers: {'X-Idempotency-Key': operation.idempotencyKey}));
      return const Success(null);
    } catch (e) {
      return FailureResult(NetworkFailure('خطا در ارتباط با سرور ابری: $e'));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> pullChanges({DateTime? since}) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      return const Success([]);
    } catch (e) {
      return FailureResult(NetworkFailure('خطا در دریافت تغییرات ابری: $e'));
    }
  }
}
