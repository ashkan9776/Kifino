import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/features/sync/data/repositories/sync_repository_impl.dart';
import 'package:kifino/features/sync/domain/entities/sync_operation_entity.dart';
import 'package:kifino/features/sync/domain/services/remote_sync_client.dart';
import 'package:kifino/features/sync/domain/services/sync_engine.dart';
import 'package:kifino/features/sync/presentation/bloc/sync_bloc.dart';
import 'package:kifino/features/sync/presentation/bloc/sync_event.dart';
import 'package:kifino/features/sync/presentation/bloc/sync_state.dart';

void main() {
  late AppDatabase db;
  late SyncRepositoryImpl repository;
  late ProductionRemoteSyncClient remoteClient;
  late SyncEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = SyncRepositoryImpl(db);
    remoteClient = const ProductionRemoteSyncClient(simulateSuccess: true);
    engine = SyncEngine(syncRepository: repository, remoteClient: remoteClient);
  });

  tearDown(() async {
    await db.close();
  });

  group('SyncRepositoryImpl Tests', () {
    test('enqueues operation, counts pending, records failure, and marks success', () async {
      final op = SyncOperationEntity(
        syncEntityName: 'transactions',
        entityId: 'tx-100',
        operation: SyncOperationType.insert,
        payloadJson: '{"id": "tx-100", "amount": 1000}',
        idempotencyKey: 'idemp-100',
        queuedAt: DateTime.now(),
      );

      final enqueueRes = await repository.enqueueOperation(op);
      expect(enqueueRes.isSuccess, isTrue);

      final pendingRes = await repository.getPendingOperations();
      expect(pendingRes.isSuccess, isTrue);
      final items = pendingRes.dataOrNull ?? [];
      expect(items.length, equals(1));
      expect(items.first.entityId, equals('tx-100'));

      // Record failure
      final queueId = items.first.queueId!;
      await repository.recordOperationFailure(queueId, '500 Server Error');
      final afterFail = (await repository.getPendingOperations()).dataOrNull!;
      expect(afterFail.first.retryCount, equals(1));
      expect(afterFail.first.lastError, equals('500 Server Error'));

      // Mark success
      await repository.markOperationSuccess(queueId);
      final afterSuccess = (await repository.getPendingOperations()).dataOrNull!;
      expect(afterSuccess, isEmpty);
    });

    test('retryAllFailed resets retry counts for operations with >=3 failures', () async {
      final op = SyncOperationEntity(
        syncEntityName: 'accounts',
        entityId: 'acc-200',
        operation: SyncOperationType.insert,
        payloadJson: '{}',
        idempotencyKey: 'idemp-200',
        retryCount: 3,
        lastError: 'Permanent network drop',
        queuedAt: DateTime.now(),
      );

      await repository.enqueueOperation(op);

      // Pending should be empty (since retryCount >= 3)
      final pendingBefore = (await repository.getPendingOperations()).dataOrNull!;
      expect(pendingBefore, isEmpty);

      // Retry all
      await repository.retryAllFailed();

      final pendingAfter = (await repository.getPendingOperations()).dataOrNull!;
      expect(pendingAfter.length, equals(1));
      expect(pendingAfter.first.retryCount, equals(0));
      expect(pendingAfter.first.lastError, isNull);
    });
  });

  group('SyncEngine Tests', () {
    test('calculateBackoffSeconds scales exponentially and caps at 300', () {
      expect(engine.calculateBackoffSeconds(0), equals(0));
      expect(engine.calculateBackoffSeconds(1), equals(5));
      expect(engine.calculateBackoffSeconds(2), equals(10));
      expect(engine.calculateBackoffSeconds(3), equals(20));
      expect(engine.calculateBackoffSeconds(4), equals(40));
      expect(engine.calculateBackoffSeconds(10), equals(300));
    });

    test('runSyncCycle drains pending items and calls remote push', () async {
      await repository.enqueueOperation(
        SyncOperationEntity(
          syncEntityName: 'categories',
          entityId: 'cat-1',
          operation: SyncOperationType.insert,
          payloadJson: '{}',
          idempotencyKey: 'idemp-cat-1',
          queuedAt: DateTime.now(),
        ),
      );

      final cycleRes = await engine.runSyncCycle();
      expect(cycleRes.syncedCount, equals(1));
      expect(cycleRes.failedCount, equals(0));

      final remaining = (await repository.getPendingOperations()).dataOrNull!;
      expect(remaining, isEmpty);
    });
  });

  group('SyncBloc Tests', () {
    blocTest<SyncBloc, SyncState>(
      'runs sync cycle when SyncTriggered is added',
      build: () => SyncBloc(
        syncRepository: repository,
        syncEngine: engine,
      ),
      act: (bloc) => bloc.add(const SyncTriggered(isManual: true)),
      expect: () => [
        predicate<SyncState>((s) => s.isSyncing == true),
        predicate<SyncState>((s) => s.isSyncing == false && s.lastSyncTime != null),
      ],
    );
  });
}
