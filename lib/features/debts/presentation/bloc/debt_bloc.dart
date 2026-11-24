import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_currency.dart';
import '../../../../core/utils/money.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../notifications/domain/services/notification_service.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
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
  final String? accountId;
  const DebtPaymentSubmitted({
    required this.id,
    required this.amount,
    this.accountId,
  });
  @override
  List<Object?> get props => [id, amount, accountId];
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
  final TransactionRepository? transactionRepository;
  StreamSubscription<List<DebtEntity>>? _subscription;
  List<DebtEntity> _lastDebts = const [];
  bool _hasLoaded = false;

  DebtBloc(this._repository, this._notifications, {this.transactionRepository})
    : super(DebtInitial()) {
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
    _lastDebts = event.debts;
    _hasLoaded = true;
    emit(_computeLoaded(event.debts));
  }

  DebtLoaded _computeLoaded(List<DebtEntity> debts) {
    final baseCurrency = AppCurrency.base;
    int totalDebtMinor = 0;
    int totalReceivableMinor = 0;

    for (final d in debts) {
      if (d.isSettled || d.isDeleted) continue;
      final remaining = d.remainingAmount;
      if (!remaining.isCompatibleWith(baseCurrency)) continue;
      final normalizedMinor = remaining.currency == baseCurrency
          ? remaining.minorUnits
          : remaining.normalizeTo(baseCurrency).minorUnits;
      if (d.type == DebtType.debt) {
        totalDebtMinor += normalizedMinor;
      } else {
        totalReceivableMinor += normalizedMinor;
      }
    }

    final totalDebt = Money.fromMinor(totalDebtMinor, baseCurrency);
    final totalReceivable = Money.fromMinor(totalReceivableMinor, baseCurrency);
    final net = totalReceivable - totalDebt;

    return DebtLoaded(
      debts: debts,
      totalDebtRemaining: totalDebt,
      totalReceivableRemaining: totalReceivable,
      netBalance: net,
    );
  }

  void _emitFailurePreservingLoaded(Emitter<DebtState> emit, String message) {
    emit(DebtFailure(message));
    if (_hasLoaded) {
      emit(_computeLoaded(_lastDebts));
    }
  }

  Future<void> _onCreateSubmitted(
    DebtCreateSubmitted event,
    Emitter<DebtState> emit,
  ) async {
    final result = await _repository.createDebt(event.debt);
    result.fold(
      onSuccess: (created) => _scheduleDueReminder(created),
      onFailure: (failure) =>
          _emitFailurePreservingLoaded(emit, failure.message),
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
    await result.fold(
      onSuccess: (_) async {
        final listRes = await _repository.getDebts();
        final updated = listRes.dataOrNull
            ?.where((d) => d.id == event.id)
            .firstOrNull;
        if (updated != null && updated.isSettled) {
          await _notifications.cancelScheduled(event.id);
        }

        if (event.accountId != null &&
            event.accountId!.isNotEmpty &&
            transactionRepository != null) {
          final debtInfo =
              updated ?? _lastDebts.where((d) => d.id == event.id).firstOrNull;
          final isDebt = (debtInfo?.type ?? DebtType.debt) == DebtType.debt;
          final contact = debtInfo?.contactName ?? '';
          final description = contact.isNotEmpty
              ? (isDebt ? 'پرداخت بدهی به $contact' : 'دریافت طلب از $contact')
              : (isDebt ? 'پرداخت بدهی' : 'دریافت طلب');
          final now = DateTime.now();
          final tx = TransactionEntity(
            id: const Uuid().v4(),
            accountId: event.accountId!,
            amount: event.amount,
            type: isDebt
                ? TransactionType.debtPayment
                : TransactionType.receivablePayment,
            date: now,
            description: description,
            createdAt: now,
            updatedAt: now,
            source: TransactionSource.debt,
            sourceId: event.id,
          );
          final txResult = await transactionRepository!.createTransaction(tx);
          if (txResult.isFailure) {
            _emitFailurePreservingLoaded(emit, txResult.failureOrNull!.message);
          }
        }
      },
      onFailure: (failure) async =>
          _emitFailurePreservingLoaded(emit, failure.message),
    );
  }

  Future<void> _onDeleteSubmitted(
    DebtDeleteSubmitted event,
    Emitter<DebtState> emit,
  ) async {
    final result = await _repository.deleteDebt(event.id);
    await result.fold(
      onSuccess: (_) => _notifications.cancelScheduled(event.id),
      onFailure: (failure) async =>
          _emitFailurePreservingLoaded(emit, failure.message),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
