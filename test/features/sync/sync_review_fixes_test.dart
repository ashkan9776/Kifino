import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:kifino/features/sync/domain/entities/sync_operation_entity.dart';
import 'package:kifino/features/sync/domain/services/remote_sync_client.dart';
import 'package:kifino/features/sync/domain/services/sync_engine.dart';

void main() {
  late AppDatabase db;
  late SyncRepositoryImpl repository;

  SyncOperationEntity op(String id, DateTime queuedAt) => SyncOperationEntity(
    syncEntityName: 'transactions',
    entityId: id,
    operation: SyncOperationType.insert,
    payloadJson: '{}',
    idempotencyKey: 'key-$id',
    queuedAt: queuedAt,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = SyncRepositoryImpl(db);
  });
  tearDown(() => db.close());

  test('a failed push records when it was attempted', () async {
    await repository.enqueueOperation(op('a', DateTime(2026, 1, 1)));
    final queued = (await repository.getPendingOperations()).dataOrNull!.single;
    expect(queued.lastAttemptAt, isNull);

    final before = DateTime.now();
    await repository.recordOperationFailure(queued.queueId!, 'boom');

    final failed = (await repository.getPendingOperations()).dataOrNull!.single;
    expect(failed.retryCount, 1);
    expect(failed.lastAttemptAt, isNotNull);
    expect(
      failed.lastAttemptAt!.isBefore(
        before.subtract(const Duration(seconds: 1)),
      ),
      isFalse,
    );
  });

  test(
    'backoff is measured from the last attempt, not from queuedAt',
    () async {
      // Queued an hour ago: under the old rule its backoff window had long
      // passed, so it was retried on every cycle right after failing.
      await repository.enqueueOperation(
        op('b', DateTime.now().subtract(const Duration(hours: 1))),
      );
      final engine = SyncEngine(
        syncRepository: repository,
        remoteClient: const FakeRemoteSyncClient(simulateSuccess: false),
      );

      final first = await engine.runSyncCycle();
      expect(first.failedCount, 1);

      // Immediately again: still inside the 5 s backoff after that failure.
      final second = await engine.runSyncCycle();
      expect(second.failedCount, 0);
      expect(second.syncedCount, 0);
      final pending = (await repository.getPendingOperations()).dataOrNull!;
      expect(pending.single.retryCount, 1);
    },
  );

  group('offline queue pruning', () {
    test(
      'drops operations older than 30 days when no backend exists',
      () async {
        final now = DateTime(2026, 11, 24);
        await repository.enqueueOperation(
          op('old', now.subtract(const Duration(days: 45))),
        );
        await repository.enqueueOperation(
          op('recent', now.subtract(const Duration(days: 2))),
        );
        final engine = SyncEngine(
          syncRepository: repository,
          remoteClient: const UnavailableRemoteSyncClient(),
        );

        expect(await engine.pruneIfNoBackend(now: now), 1);

        final left = (await repository.getPendingOperations()).dataOrNull!;
        expect(left.map((o) => o.entityId), ['recent']);
      },
    );

    test('keeps everything when a backend is configured', () async {
      final now = DateTime(2026, 11, 24);
      await repository.enqueueOperation(
        op('old', now.subtract(const Duration(days: 400))),
      );
      final engine = SyncEngine(
        syncRepository: repository,
        remoteClient: const FakeRemoteSyncClient(),
      );

      expect(await engine.pruneIfNoBackend(now: now), 0);
      expect(
        (await repository.getPendingOperations()).dataOrNull,
        hasLength(1),
      );
    });
  });
}
