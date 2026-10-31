import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../notifications/domain/services/notification_service.dart';
import '../../domain/entities/installment_entity.dart';
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
  List<Object?> get props => [installments, totalDebtRemaining, monthlyInstallmentDues];
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

  InstallmentBloc(this._repository, this._notifications) : super(InstallmentInitial()) {
    on<WatchInstallmentsStarted>(_onWatchStarted);
    on<_InstallmentsUpdated>(_onInstallmentsUpdated);
    on<InstallmentCreateSubmitted>(_onCreateSubmitted);
    on<InstallmentPaySubmitted>(_onPaySubmitted);
    on<InstallmentDeleteSubmitted>(_onDeleteSubmitted);
  }

  void _onWatchStarted(WatchInstallmentsStarted event, Emitter<InstallmentState> emit) {
    emit(InstallmentLoading());
    _subscription?.cancel();
    _subscription = _repository.watchInstallments().listen(
      (installments) => add(_InstallmentsUpdated(installments)),
      onError: (e) => emit(InstallmentFailure(e.toString())),
    );
  }

  void _onInstallmentsUpdated(_InstallmentsUpdated event, Emitter<InstallmentState> emit) {
    int totalRemainingMinor = 0;
    int monthlyDuesMinor = 0;
    const currency = Currency.irr;

    for (final inst in event.installments) {
      if (inst.isCompleted || inst.isDeleted) continue;
      totalRemainingMinor += inst.remainingAmount.minorUnits;
      monthlyDuesMinor += inst.installmentAmount.minorUnits;
    }

    emit(InstallmentLoaded(
      installments: event.installments,
      totalDebtRemaining: Money.fromMinor(totalRemainingMinor, currency),
      monthlyInstallmentDues: Money.fromMinor(monthlyDuesMinor, currency),
    ));
  }

  Future<void> _onCreateSubmitted(InstallmentCreateSubmitted event, Emitter<InstallmentState> emit) async {
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

  Future<void> _onPaySubmitted(InstallmentPaySubmitted event, Emitter<InstallmentState> emit) async {
    final result = await _repository.payNextInstallment(event.id);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(InstallmentFailure(failure.message)),
    );
  }

  Future<void> _onDeleteSubmitted(InstallmentDeleteSubmitted event, Emitter<InstallmentState> emit) async {
    final result = await _repository.deleteInstallment(event.id);
    result.fold(
      onSuccess: (_) => _notifications.cancelScheduled(event.id),
      onFailure: (failure) => emit(InstallmentFailure(failure.message)),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
