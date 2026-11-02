import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/accounting_audit_entity.dart';
import '../../domain/repositories/accounting_repository.dart';

sealed class AuditLogState extends Equatable {
  const AuditLogState();
  @override
  List<Object?> get props => [];
}

final class AuditLogInitial extends AuditLogState {}

final class AuditLogLoading extends AuditLogState {}

/// Live view of the audit trail — the repository stream pushes updates, so
/// this state is re-emitted whenever a document changes.
final class AuditLogLoaded extends AuditLogState {
  final List<AccountingAuditLogEntity> logs;

  const AuditLogLoaded(this.logs);

  @override
  List<Object?> get props => [logs];
}

final class AuditLogError extends AuditLogState {
  final String message;

  const AuditLogError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Watches the accounting audit trail (newest first) as a live stream.
class AuditLogCubit extends Cubit<AuditLogState> {
  final AccountingRepository _repository;
  StreamSubscription<List<AccountingAuditLogEntity>>? _subscription;

  AuditLogCubit(this._repository) : super(AuditLogInitial());

  /// Starts (or restarts) watching the audit log stream.
  void watch({int limit = 200}) {
    _subscription?.cancel();
    if (state is! AuditLogLoaded) emit(AuditLogLoading());
    try {
      _subscription = _repository
          .watchAuditLogs(limit: limit)
          .listen(
            (logs) => emit(AuditLogLoaded(logs)),
            onError: (e) => emit(AuditLogError(_message(e))),
          );
    } catch (e) {
      emit(AuditLogError(_message(e)));
    }
  }

  static String _message(Object e) =>
      e.toString().replaceFirst(RegExp(r'^(Bad state|StateError):\s*'), '');

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
