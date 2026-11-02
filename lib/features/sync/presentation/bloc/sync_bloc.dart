import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../domain/services/sync_engine.dart';
import 'sync_event.dart';
import 'sync_state.dart';

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncRepository _syncRepository;
  final SyncEngine _syncEngine;
  final Connectivity _connectivity;

  StreamSubscription<int>? _pendingSub;
  StreamSubscription<dynamic>? _failedSub;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _autoSyncTimer;

  SyncBloc({
    required this._syncRepository,
    required this._syncEngine,
    Connectivity? connectivity,
  }) : _connectivity = connectivity ?? Connectivity(),
       super(const SyncState()) {
    on<SyncInitRequested>(_onInitRequested);
    on<SyncTriggered>(_onSyncTriggered);
    on<SyncRetryFailedTriggered>(_onRetryFailedTriggered);
    on<SyncClearQueueTriggered>(_onClearQueueTriggered);
    on<SyncConnectivityChanged>(_onConnectivityChanged);
    on<SyncPendingCountUpdated>(_onPendingCountUpdated);
    on<SyncFailedOperationsUpdated>(_onFailedOperationsUpdated);
  }

  void _onInitRequested(SyncInitRequested event, Emitter<SyncState> emit) {
    _pendingSub?.cancel();
    _pendingSub = _syncRepository.watchPendingCount().listen((count) {
      add(SyncPendingCountUpdated(count));
    });

    _failedSub?.cancel();
    _failedSub = _syncRepository.watchFailedOperations().listen((failed) {
      add(SyncFailedOperationsUpdated(failed));
    });

    _connSub?.cancel();
    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      add(SyncConnectivityChanged(results));
    });

    // Check initial connectivity
    _connectivity.checkConnectivity().then((results) {
      add(SyncConnectivityChanged(results));
    });

    // Background auto-sync: drain the outbox periodically while online.
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(
      const Duration(minutes: AppConstants.defaultSyncIntervalMinutes),
      (_) {
        if (state.isOnline && state.pendingCount > 0 && !state.isSyncing) {
          add(const SyncTriggered(isManual: false));
        }
      },
    );
  }

  void _onPendingCountUpdated(
    SyncPendingCountUpdated event,
    Emitter<SyncState> emit,
  ) {
    emit(state.copyWith(pendingCount: event.count));
  }

  void _onFailedOperationsUpdated(
    SyncFailedOperationsUpdated event,
    Emitter<SyncState> emit,
  ) {
    emit(state.copyWith(failedOperations: event.failedOperations));
  }

  void _onConnectivityChanged(
    SyncConnectivityChanged event,
    Emitter<SyncState> emit,
  ) {
    final isOnline = event.results.any((r) => r != ConnectivityResult.none);
    final wasOffline = !state.isOnline;
    emit(state.copyWith(isOnline: isOnline));

    // If we just regained connectivity, trigger auto sync
    if (wasOffline && isOnline && state.pendingCount > 0) {
      add(const SyncTriggered(isManual: false));
    }
  }

  Future<void> _onSyncTriggered(
    SyncTriggered event,
    Emitter<SyncState> emit,
  ) async {
    if (state.isSyncing) return;

    emit(state.copyWith(isSyncing: true, errorMessage: null));

    final result = await _syncEngine.runSyncCycle();

    emit(
      state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        lastSyncCount: result.syncedCount,
        errorMessage: result.error,
      ),
    );
  }

  Future<void> _onRetryFailedTriggered(
    SyncRetryFailedTriggered event,
    Emitter<SyncState> emit,
  ) async {
    emit(state.copyWith(isSyncing: true));
    await _syncRepository.retryAllFailed();
    final result = await _syncEngine.runSyncCycle();
    emit(
      state.copyWith(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        lastSyncCount: result.syncedCount,
        errorMessage: result.error,
      ),
    );
  }

  Future<void> _onClearQueueTriggered(
    SyncClearQueueTriggered event,
    Emitter<SyncState> emit,
  ) async {
    await _syncRepository.clearQueue();
  }

  @override
  Future<void> close() {
    _pendingSub?.cancel();
    _failedSub?.cancel();
    _connSub?.cancel();
    _autoSyncTimer?.cancel();
    return super.close();
  }
}
