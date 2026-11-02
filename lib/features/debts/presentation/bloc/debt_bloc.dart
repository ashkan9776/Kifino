import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../notifications/domain/services/notification_service.dart';
import '../../domain/entities/debt_entity.dart';
import '../../domain/repositories/debt_repository.dart';

// Events
sealed class DebtEvent extends Equatable {
  const DebtEvent();
  @override
  List<Object?> get props => [];
}

final class WatchDebtsStarted extends DebtEvent {
  final DebtType? type;
  const WatchDebtsStarted({this.type});
  @override
  List<Object?> get props => [type];
}

final class _DebtsUpdated extends DebtEvent {
  final List<DebtEntity> debts;
  const _DebtsUpdated(this.debts);
  @override
  List<Object?> get props => [debts];
}

final class DebtCreateSubmitted extends DebtEvent {
  final DebtEntity debt;
  const DebtCreateSubmitted(this.debt);
  @override
  List<Object?> get props => [debt];
}

final class DebtPaymentSubmitted extends DebtEvent {
  final String id;
  final Money amount;
  const DebtPaymentSubmitted({required this.id, required this.amount});
  @override
  List<Object?> get props => [id, amount];
}

final class DebtDeleteSubmitted extends DebtEvent {
  final String id;
  const DebtDeleteSubmitted(this.id);
  @override
  List<Object?> get props => [id];
}

// States
sealed class DebtState extends Equatable {
  const DebtState();
  @override
  List<Object?> get props => [];
}

final class DebtInitial extends DebtState {}

final class DebtLoading extends DebtState {}

final class DebtLoaded extends DebtState {
  final List<DebtEntity> debts;
  final Money totalDebtRemaining;
  final Money totalReceivableRemaining;
  final Money netBalance;

  const DebtLoaded({
    required this.debts,
    required this.totalDebtRemaining,
    required this.totalReceivableRemaining,
    required this.netBalance,
  });

  @override
  List<Object?> get props => [
    debts,
    totalDebtRemaining,
    totalReceivableRemaining,
    netBalance,
  ];
}

final class DebtFailure extends DebtState {
  final String message;
  const DebtFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class DebtBloc extends Bloc<DebtEvent, DebtState> {
  final DebtRepository _repository;
  final NotificationService _notifications;
  StreamSubscription<List<DebtEntity>>? _subscription;

  DebtBloc(this._repository, this._notifications) : super(DebtInitial()) {
    on<WatchDebtsStarted>(_onWatchStarted);
    on<_DebtsUpdated>(_onDebtsUpdated);
    on<DebtCreateSubmitted>(_onCreateSubmitted);
    on<DebtPaymentSubmitted>(_onPaymentSubmitted);
    on<DebtDeleteSubmitted>(_onDeleteSubmitted);
  }

  void _onWatchStarted(WatchDebtsStarted event, Emitter<DebtState> emit) {
    emit(DebtLoading());
    _subscription?.cancel();
    _subscription = _repository
        .watchDebts(type: event.type)
        .listen(
          (debts) => add(_DebtsUpdated(debts)),
          onError: (e) => emit(DebtFailure(e.toString())),
        );
  }

  void _onDebtsUpdated(_DebtsUpdated event, Emitter<DebtState> emit) {
    int totalDebtMinor = 0;
    int totalReceivableMinor = 0;
    const currency = Currency.irr;

    for (final d in event.debts) {
      if (d.isSettled || d.isDeleted) continue;
      if (d.type == DebtType.debt) {
        totalDebtMinor += d.remainingAmount.minorUnits;
      } else {
        totalReceivableMinor += d.remainingAmount.minorUnits;
      }
    }

    final totalDebt = Money.fromMinor(totalDebtMinor, currency);
    final totalReceivable = Money.fromMinor(totalReceivableMinor, currency);
    final net = totalReceivable - totalDebt;

    emit(
      DebtLoaded(
        debts: event.debts,
        totalDebtRemaining: totalDebt,
        totalReceivableRemaining: totalReceivable,
        netBalance: net,
      ),
    );
  }

  Future<void> _onCreateSubmitted(
    DebtCreateSubmitted event,
    Emitter<DebtState> emit,
  ) async {
    final result = await _repository.createDebt(event.debt);
    result.fold(
      onSuccess: (_) => _scheduleDueReminder(event.debt),
      onFailure: (failure) => emit(DebtFailure(failure.message)),
    );
  }

  /// Optional due-date reminder at 09:00 local — only when the debt
  /// actually has a due date.
  void _scheduleDueReminder(DebtEntity debt) {
    final due = debt.dueDate;
    if (due == null) return;
    final reminderDate = DateTime(due.year, due.month, due.day, 9, 0);
    _notifications.scheduleNotification(
      title:
          'سررسید ${debt.type == DebtType.debt ? 'بدهی' : 'طلب'} ${debt.contactName}',
      body:
          'سررسید ${debt.contactName} به مبلغ ${debt.remainingAmount.formatCompact()} فرا رسید.',
      type: NotificationType.debtDue,
      referenceId: debt.id,
      scheduledFor: reminderDate,
    );
  }

  Future<void> _onPaymentSubmitted(
    DebtPaymentSubmitted event,
    Emitter<DebtState> emit,
  ) async {
    final result = await _repository.addPayment(event.id, event.amount);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(DebtFailure(failure.message)),
    );
  }

  Future<void> _onDeleteSubmitted(
    DebtDeleteSubmitted event,
    Emitter<DebtState> emit,
  ) async {
    final result = await _repository.deleteDebt(event.id);
    result.fold(
      onSuccess: (_) => _notifications.cancelScheduled(event.id),
      onFailure: (failure) => emit(DebtFailure(failure.message)),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
