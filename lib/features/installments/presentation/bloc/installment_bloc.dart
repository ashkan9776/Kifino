import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../notifications/domain/services/notification_service.dart';
import '../../domain/entities/installment_entity.dart';
import '../../domain/entities/installment_payment_entity.dart';
import '../../domain/repositories/installment_repository.dart';

// Events
sealed class InstallmentEvent extends Equatable {
  const InstallmentEvent();
  @override
  List<Object?> get props => [];
}

final class WatchInstallmentsStarted extends InstallmentEvent {
  const WatchInstallmentsStarted();
}

final class _InstallmentsUpdated extends InstallmentEvent {
  final List<InstallmentEntity> installments;
  const _InstallmentsUpdated(this.installments);
  @override
  List<Object?> get props => [installments];
}

final class InstallmentCreateSubmitted extends InstallmentEvent {
  final InstallmentEntity installment;
  const InstallmentCreateSubmitted(this.installment);
  @override
  List<Object?> get props => [installment];
}

final class InstallmentPaySubmitted extends InstallmentEvent {
  final String id;
  const InstallmentPaySubmitted(this.id);
  @override
  List<Object?> get props => [id];
}

final class InstallmentDeleteSubmitted extends InstallmentEvent {
  final String id;
  const InstallmentDeleteSubmitted(this.id);
  @override
  List<Object?> get props => [id];
}

/// Phase 3 rework — edits the plan fields of an installment (title, amounts,
/// count, interval, next due date, notes). Past payments are never touched.
final class InstallmentUpdateSubmitted extends InstallmentEvent {
  final InstallmentEntity installment;
  const InstallmentUpdateSubmitted(this.installment);
  @override
  List<Object?> get props => [installment];
}

/// Phase 3 rework — تسویه زودهنگام: pays ALL remaining installments at once
/// (one summary ledger row, balance deducted in a single shot).
final class InstallmentPayRemainingSubmitted extends InstallmentEvent {
  final String id;
  const InstallmentPayRemainingSubmitted(this.id);
  @override
  List<Object?> get props => [id];
}

/// Phase 3 rework — corrects a wrong payment: money returns to the account,
/// the linked ledger row is reverted and the paid counter recomputes.
/// When [installmentId] is given (history sheet open), the sheet's data is
/// refreshed after the revert.
final class InstallmentPaymentDeleted extends InstallmentEvent {
  final String paymentId;
  final String? installmentId;
  const InstallmentPaymentDeleted(this.paymentId, {this.installmentId});
  @override
  List<Object?> get props => [paymentId, installmentId];
}

/// Phase 3 rework — loads the payment history of one installment into the
/// state so the history sheet can render it.
final class InstallmentHistoryRequested extends InstallmentEvent {
  final String installmentId;
  const InstallmentHistoryRequested(this.installmentId);
  @override
  List<Object?> get props => [installmentId];
}

/// Emitted when the history sheet closes, restoring the plain loaded state.
final class InstallmentHistoryClosed extends InstallmentEvent {
  const InstallmentHistoryClosed();
}

// States
sealed class InstallmentState extends Equatable {
  const InstallmentState();
  @override
  List<Object?> get props => [];
}

final class InstallmentInitial extends InstallmentState {}

final class InstallmentLoading extends InstallmentState {}

final class InstallmentLoaded extends InstallmentState {
  final List<InstallmentEntity> installments;
  final Money totalDebtRemaining;
  final Money monthlyInstallmentDues;

  const InstallmentLoaded({
    required this.installments,
    required this.totalDebtRemaining,
    required this.monthlyInstallmentDues,
  });

  @override
  List<Object?> get props => [
    installments,
    totalDebtRemaining,
    monthlyInstallmentDues,
  ];
}

/// Payment history of one installment (newest first), for the history sheet.
/// Extends [InstallmentLoaded] so the page behind the sheet keeps rendering
/// the list instead of flashing an empty state.
final class InstallmentHistoryLoaded extends InstallmentLoaded {
  final String installmentId;
  final List<InstallmentPaymentEntity> history;

  const InstallmentHistoryLoaded({
    required super.installments,
    required super.totalDebtRemaining,
    required super.monthlyInstallmentDues,
    required this.installmentId,
    required this.history,
  });

  @override
  List<Object?> get props => [
    installments,
    totalDebtRemaining,
    monthlyInstallmentDues,
    installmentId,
    history,
  ];
}

/// Transient success state — the page maps [op] to a localized SnackBar
/// message (same pattern as GoalBloc's GoalOperationSuccess).
final class InstallmentOperationSuccess extends InstallmentState {
  /// pay | payRemaining | update | delete | deletePayment
  final String op;
  final String message;
  const InstallmentOperationSuccess(this.message, {required this.op});
  @override
  List<Object?> get props => [message, op];
}

final class InstallmentFailure extends InstallmentState {
  final String message;
  const InstallmentFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class InstallmentBloc extends Bloc<InstallmentEvent, InstallmentState> {
  final InstallmentRepository _repository;
  final NotificationService _notifications;
  StreamSubscription<List<InstallmentEntity>>? _subscription;

  /// Latest snapshot from the watch stream — used to restore the loaded state
  /// when the history sheet closes.
  List<InstallmentEntity> _lastInstallments = const [];

  InstallmentBloc(this._repository, this._notifications)
    : super(InstallmentInitial()) {
    on<WatchInstallmentsStarted>(_onWatchStarted);
    on<_InstallmentsUpdated>(_onInstallmentsUpdated);
    on<InstallmentCreateSubmitted>(_onCreateSubmitted);
    on<InstallmentPaySubmitted>(_onPaySubmitted);
    on<InstallmentDeleteSubmitted>(_onDeleteSubmitted);
    on<InstallmentUpdateSubmitted>(_onUpdateSubmitted);
    on<InstallmentPayRemainingSubmitted>(_onPayRemainingSubmitted);
    on<InstallmentPaymentDeleted>(_onPaymentDeleted);
    on<InstallmentHistoryRequested>(_onHistoryRequested);
    on<InstallmentHistoryClosed>(_onHistoryClosed);
  }

  void _onWatchStarted(
    WatchInstallmentsStarted event,
    Emitter<InstallmentState> emit,
  ) {
    emit(InstallmentLoading());
    _subscription?.cancel();
    _subscription = _repository.watchInstallments().listen(
      (installments) => add(_InstallmentsUpdated(installments)),
      onError: (e) => emit(InstallmentFailure(e.toString())),
    );
  }

  Future<void> _onInstallmentsUpdated(
    _InstallmentsUpdated event,
    Emitter<InstallmentState> emit,
  ) async {
    _lastInstallments = event.installments;
    final loaded = _computeLoaded(event.installments);

    // While the history sheet is open, keep its data in sync with the fresh
    // snapshot instead of clobbering it with a plain loaded state.
    final current = state;
    if (current is InstallmentHistoryLoaded) {
      try {
        final history = await _repository.getPaymentHistory(
          current.installmentId,
        );
        if (!emit.isDone) {
          emit(
            InstallmentHistoryLoaded(
              installments: loaded.installments,
              totalDebtRemaining: loaded.totalDebtRemaining,
              monthlyInstallmentDues: loaded.monthlyInstallmentDues,
              installmentId: current.installmentId,
              history: history,
            ),
          );
        }
      } catch (_) {
        if (!emit.isDone) emit(loaded);
      }
      return;
    }

    if (!emit.isDone) emit(loaded);
  }

  InstallmentLoaded _computeLoaded(List<InstallmentEntity> installments) {
    int totalRemainingMinor = 0;
    int monthlyDuesMinor = 0;
    const currency = Currency.irr;

    for (final inst in installments) {
      if (inst.isCompleted || inst.isDeleted) continue;
      totalRemainingMinor += inst.remainingAmount.minorUnits;
      monthlyDuesMinor += inst.installmentAmount.minorUnits;
    }

    return InstallmentLoaded(
      installments: installments,
      totalDebtRemaining: Money.fromMinor(totalRemainingMinor, currency),
      monthlyInstallmentDues: Money.fromMinor(monthlyDuesMinor, currency),
    );
  }

  Future<void> _onCreateSubmitted(
    InstallmentCreateSubmitted event,
    Emitter<InstallmentState> emit,
  ) async {
    final result = await _repository.createInstallment(event.installment);
    result.fold(
      onSuccess: (_) => _scheduleDueReminder(event.installment),
      onFailure: (failure) => emit(InstallmentFailure(failure.message)),
    );
  }

  /// Schedules the next due-date reminder. Fires at 09:00 local time
  /// on the due date.
  void _scheduleDueReminder(InstallmentEntity installment) {
    final due = installment.nextDueDate;
    final reminderDate = DateTime(due.year, due.month, due.day, 9, 0);
    _notifications.scheduleNotification(
      title: 'قسط «${installment.title}» سررسید شد',
      body: 'قسط بعدی وام ${installment.title} سررسید شد.',
      type: NotificationType.installmentDue,
      referenceId: installment.id,
      scheduledFor: reminderDate,
    );
  }

  Future<void> _onPaySubmitted(
    InstallmentPaySubmitted event,
    Emitter<InstallmentState> emit,
  ) async {
    final result = await _repository.payNextInstallment(event.id);
    result.fold(
      onSuccess: (_) =>
          emit(const InstallmentOperationSuccess('قسط پرداخت شد', op: 'pay')),
      onFailure: (failure) => emit(InstallmentFailure(failure.message)),
    );
  }

  Future<void> _onDeleteSubmitted(
    InstallmentDeleteSubmitted event,
    Emitter<InstallmentState> emit,
  ) async {
    final result = await _repository.deleteInstallment(event.id);
    result.fold(
      onSuccess: (_) {
        _notifications.cancelScheduled(event.id);
        emit(const InstallmentOperationSuccess('قسط حذف شد', op: 'delete'));
      },
      onFailure: (failure) => emit(InstallmentFailure(failure.message)),
    );
  }

  Future<void> _onUpdateSubmitted(
    InstallmentUpdateSubmitted event,
    Emitter<InstallmentState> emit,
  ) async {
    final result = await _repository.updateInstallment(event.installment);
    result.fold(
      onSuccess: (_) {
        _scheduleDueReminder(event.installment);
        emit(
          const InstallmentOperationSuccess('تغییرات ذخیره شد', op: 'update'),
        );
      },
      onFailure: (failure) => emit(InstallmentFailure(failure.message)),
    );
  }

  Future<void> _onPayRemainingSubmitted(
    InstallmentPayRemainingSubmitted event,
    Emitter<InstallmentState> emit,
  ) async {
    final result = await _repository.payRemaining(event.id);
    result.fold(
      onSuccess: (_) => emit(
        const InstallmentOperationSuccess(
          'تسویه کامل انجام شد',
          op: 'payRemaining',
        ),
      ),
      onFailure: (failure) => emit(InstallmentFailure(failure.message)),
    );
  }

  Future<void> _onPaymentDeleted(
    InstallmentPaymentDeleted event,
    Emitter<InstallmentState> emit,
  ) async {
    final result = await _repository.deletePayment(event.paymentId);
    result.fold(
      onSuccess: (_) {
        emit(
          const InstallmentOperationSuccess(
            'پرداخت حذف شد و مبلغ به حساب برگشت',
            op: 'deletePayment',
          ),
        );
        // Keep the open history sheet in sync with the reverted counters.
        final installmentId = event.installmentId;
        if (installmentId != null) {
          add(InstallmentHistoryRequested(installmentId));
        }
      },
      onFailure: (failure) => emit(InstallmentFailure(failure.message)),
    );
  }

  Future<void> _onHistoryRequested(
    InstallmentHistoryRequested event,
    Emitter<InstallmentState> emit,
  ) async {
    try {
      final history = await _repository.getPaymentHistory(event.installmentId);
      if (!emit.isDone) {
        final loaded = _computeLoaded(_lastInstallments);
        emit(
          InstallmentHistoryLoaded(
            installments: loaded.installments,
            totalDebtRemaining: loaded.totalDebtRemaining,
            monthlyInstallmentDues: loaded.monthlyInstallmentDues,
            installmentId: event.installmentId,
            history: history,
          ),
        );
      }
    } catch (e) {
      if (!emit.isDone) emit(InstallmentFailure(e.toString()));
    }
  }

  void _onHistoryClosed(
    InstallmentHistoryClosed event,
    Emitter<InstallmentState> emit,
  ) {
    if (state is InstallmentHistoryLoaded) {
      emit(_computeLoaded(_lastInstallments));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
