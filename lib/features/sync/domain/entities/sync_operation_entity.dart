import 'package:equatable/equatable.dart';

enum SyncOperationType {
  insert('INSERT'),
  update('UPDATE'),
  delete('DELETE');

  final String code;
  const SyncOperationType(this.code);

  static SyncOperationType fromCode(String code) {
    for (final op in values) {
      if (op.code == code) return op;
    }
    return SyncOperationType.insert;
  }
}

class SyncOperationEntity extends Equatable {
  final int? queueId;
  final String syncEntityName;
  final String entityId;
  final SyncOperationType operation;
  final String payloadJson;
  final String idempotencyKey;
  final int retryCount;
  final String? lastError;
  final DateTime queuedAt;

  /// When the last failed push happened (null if never tried).
  final DateTime? lastAttemptAt;

  const SyncOperationEntity({
    this.queueId,
    required this.syncEntityName,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.idempotencyKey,
    this.retryCount = 0,
    this.lastError,
    required this.queuedAt,
    this.lastAttemptAt,
  });

  bool get isFailed => retryCount >= 3;

  SyncOperationEntity copyWith({
    int? queueId,
    String? syncEntityName,
    String? entityId,
    SyncOperationType? operation,
    String? payloadJson,
    String? idempotencyKey,
    int? retryCount,
    String? lastError,
    DateTime? queuedAt,
    DateTime? lastAttemptAt,
  }) {
    return SyncOperationEntity(
      queueId: queueId ?? this.queueId,
      syncEntityName: syncEntityName ?? this.syncEntityName,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      queuedAt: queuedAt ?? this.queuedAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  @override
  List<Object?> get props => [
    queueId,
    syncEntityName,
    entityId,
    operation,
    payloadJson,
    idempotencyKey,
    retryCount,
    lastError,
    queuedAt,
    lastAttemptAt,
  ];
}
