import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/sync_operation_entity.dart';

sealed class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

final class SyncInitRequested extends SyncEvent {
  const SyncInitRequested();
}

final class SyncTriggered extends SyncEvent {
  final bool isManual;
  const SyncTriggered({this.isManual = false});

  @override
  List<Object?> get props => [isManual];
}

final class SyncRetryFailedTriggered extends SyncEvent {
  const SyncRetryFailedTriggered();
}

final class SyncClearQueueTriggered extends SyncEvent {
  const SyncClearQueueTriggered();
}

final class SyncConnectivityChanged extends SyncEvent {
  final List<ConnectivityResult> results;
  const SyncConnectivityChanged(this.results);

  @override
  List<Object?> get props => [results];
}

final class SyncPendingCountUpdated extends SyncEvent {
  final int count;
  const SyncPendingCountUpdated(this.count);

  @override
  List<Object?> get props => [count];
}

final class SyncFailedOperationsUpdated extends SyncEvent {
  final List<SyncOperationEntity> failedOperations;
  const SyncFailedOperationsUpdated(this.failedOperations);

  @override
  List<Object?> get props => [failedOperations];
}
