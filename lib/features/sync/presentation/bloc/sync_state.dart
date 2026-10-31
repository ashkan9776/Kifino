import 'package:equatable/equatable.dart';
import '../../domain/entities/sync_operation_entity.dart';

class SyncState extends Equatable {
  final bool isSyncing;
  final bool isOnline;
  final int pendingCount;
  final List<SyncOperationEntity> failedOperations;
  final DateTime? lastSyncTime;
  final int lastSyncCount;
  final String? errorMessage;

  const SyncState({
    this.isSyncing = false,
    this.isOnline = true,
    this.pendingCount = 0,
    this.failedOperations = const [],
    this.lastSyncTime,
    this.lastSyncCount = 0,
    this.errorMessage,
  });

  int get failedCount => failedOperations.length;

  SyncState copyWith({
    bool? isSyncing,
    bool? isOnline,
    int? pendingCount,
    List<SyncOperationEntity>? failedOperations,
    DateTime? lastSyncTime,
    int? lastSyncCount,
    String? errorMessage,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      isOnline: isOnline ?? this.isOnline,
      pendingCount: pendingCount ?? this.pendingCount,
      failedOperations: failedOperations ?? this.failedOperations,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSyncCount: lastSyncCount ?? this.lastSyncCount,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        isSyncing,
        isOnline,
        pendingCount,
        failedOperations,
        lastSyncTime,
        lastSyncCount,
        errorMessage,
      ];
}
