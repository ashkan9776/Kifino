import 'dart:math';
import '../repositories/sync_repository.dart';
import 'remote_sync_client.dart';

class SyncCycleResult {
  final int syncedCount;
  final int failedCount;
  final String? error;

  const SyncCycleResult({
    required this.syncedCount,
    required this.failedCount,
    this.error,
  });
}

class SyncEngine {
  final SyncRepository _syncRepository;
  final RemoteSyncClient _remoteClient;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncEngine({
    required this._syncRepository,
    required this._remoteClient,
  });

  /// Computes exponential backoff delay in seconds: min(5 * 2^retryCount, 300)
  int calculateBackoffSeconds(int retryCount) {
    if (retryCount <= 0) return 0;
    final delay = 5 * pow(2, retryCount - 1).toInt();
    return min(delay, 300);
  }

  /// Drains the pending outbox queue
  Future<SyncCycleResult> runSyncCycle() async {
    if (_isSyncing) {
      return const SyncCycleResult(syncedCount: 0, failedCount: 0, error: 'Sync already in progress');
    }

    _isSyncing = true;
    int synced = 0;
    int failed = 0;
    String? lastErr;

    try {
      final operationsResult = await _syncRepository.getPendingOperations(limit: 100);
      if (operationsResult.isFailure) {
        _isSyncing = false;
        return SyncCycleResult(syncedCount: 0, failedCount: 0, error: operationsResult.failureOrNull?.message);
      }

      final operations = operationsResult.dataOrNull ?? [];
      final now = DateTime.now();

      for (final op in operations) {
        // Check exponential backoff window
        if (op.retryCount > 0) {
          final backoffSec = calculateBackoffSeconds(op.retryCount);
          final allowedAfter = op.queuedAt.add(Duration(seconds: backoffSec));
          if (now.isBefore(allowedAfter)) {
            // Still in cooldown, skip this cycle
            continue;
          }
        }

        final pushResult = await _remoteClient.pushOperation(op);

        if (pushResult.isSuccess) {
          await _syncRepository.markOperationSuccess(op.queueId!);
          synced++;
        } else {
          final errMsg = pushResult.failureOrNull?.message ?? 'Unknown sync failure';
          lastErr = errMsg;
          failed++;
          await _syncRepository.recordOperationFailure(op.queueId!, errMsg);
        }
      }

      return SyncCycleResult(
        syncedCount: synced,
        failedCount: failed,
        error: lastErr,
      );
    } catch (e) {
      return SyncCycleResult(syncedCount: synced, failedCount: failed, error: e.toString());
    } finally {
      _isSyncing = false;
    }
  }
}
