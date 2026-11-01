import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../entities/sync_operation_entity.dart';

abstract interface class RemoteSyncClient {
  Future<Result<void>> pushOperation(SyncOperationEntity operation);
  Future<Result<List<Map<String, dynamic>>>> pullChanges({DateTime? since});
}

/// Simulated client for testing and debug scenarios only.
class FakeRemoteSyncClient implements RemoteSyncClient {
  final bool simulateSuccess;

  const FakeRemoteSyncClient({this.simulateSuccess = true});

  @override
  Future<Result<void>> pushOperation(SyncOperationEntity operation) async {
    try {
      // Simulate remote network latency in debug
      await Future.delayed(const Duration(milliseconds: 150));

      if (!simulateSuccess) {
        return const FailureResult(
          NetworkFailure('عدم پاسخگویی سرور شبیه‌سازی‌شده (خطای 503)'),
        );
      }
      return const Success(null);
    } catch (e) {
      return FailureResult(NetworkFailure('خطا در شبیه‌ساز سرور: $e'));
    }
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> pullChanges({
    DateTime? since,
  }) async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      return const Success([]);
    } catch (e) {
      return FailureResult(
        NetworkFailure('خطا در دریافت تغییرات شبیه‌ساز: $e'),
      );
    }
  }
}

/// Backward compatibility alias for tests.
typedef ProductionRemoteSyncClient = FakeRemoteSyncClient;

/// Production client when no remote backend URL is configured.
/// Rejects operations explicitly with "Coming Soon / Not configured" error so
/// the queue is never falsely marked as synced to a phantom cloud server.
class UnavailableRemoteSyncClient implements RemoteSyncClient {
  const UnavailableRemoteSyncClient();

  @override
  Future<Result<void>> pushOperation(SyncOperationEntity operation) async {
    return const FailureResult(
      NetworkFailure('سرور همگام‌سازی ابری هنوز متصل نشده است (به‌زودی).'),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> pullChanges({
    DateTime? since,
  }) async {
    return const FailureResult(
      NetworkFailure('سرور همگام‌سازی ابری هنوز متصل نشده است (به‌زودی).'),
    );
  }
}
