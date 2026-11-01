import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/utils/app_logger.dart';

import '../../../../core/utils/money.dart';
import '../../../notifications/domain/entities/app_notification_entity.dart';
import '../../../notifications/domain/services/notification_service.dart';
import '../../../accounting/domain/services/auto_voucher_service.dart';
import '../../domain/entities/check_entity.dart';
import '../../domain/repositories/check_repository.dart';

// Events
sealed class CheckEvent extends Equatable {
  const CheckEvent();
  @override
  List<Object?> get props => [];
}

final class WatchChecksStarted extends CheckEvent {
  final CheckType? type;
  const WatchChecksStarted({this.type});
  @override
  List<Object?> get props => [type];
}

final class _ChecksUpdated extends CheckEvent {
  final List<CheckEntity> checks;
  const _ChecksUpdated(this.checks);
  @override
  List<Object?> get props => [checks];
}

final class CheckCreateSubmitted extends CheckEvent {
  final CheckEntity check;
  const CheckCreateSubmitted(this.check);
  @override
  List<Object?> get props => [check];
}

final class CheckStatusUpdated extends CheckEvent {
  final String id;
  final CheckStatus status;
  const CheckStatusUpdated({required this.id, required this.status});
  @override
  List<Object?> get props => [id, status];
}

final class CheckDeleteSubmitted extends CheckEvent {
  final String id;
  const CheckDeleteSubmitted(this.id);
  @override
  List<Object?> get props => [id];
}

// States
sealed class CheckState extends Equatable {
  const CheckState();
  @override
  List<Object?> get props => [];
}

final class CheckInitial extends CheckState {}

final class CheckLoading extends CheckState {}

final class CheckLoaded extends CheckState {
  final List<CheckEntity> checks;
  final Money totalPendingIssued;
  final Money totalPendingReceived;

  const CheckLoaded({
    required this.checks,
    required this.totalPendingIssued,
    required this.totalPendingReceived,
  });

  @override
  List<Object?> get props => [checks, totalPendingIssued, totalPendingReceived];
}

final class CheckFailure extends CheckState {
  final String message;
  const CheckFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class CheckBloc extends Bloc<CheckEvent, CheckState> {
  final CheckRepository _repository;
  final NotificationService _notifications;
  final AutoVoucherService _autoVoucherService;
  StreamSubscription<List<CheckEntity>>? _subscription;

  CheckBloc(this._repository, this._notifications, this._autoVoucherService)
    : super(CheckInitial()) {
    on<WatchChecksStarted>(_onWatchStarted);
    on<_ChecksUpdated>(_onChecksUpdated);
    on<CheckCreateSubmitted>(_onCreateSubmitted);
    on<CheckStatusUpdated>(_onStatusUpdated);
    on<CheckDeleteSubmitted>(_onDeleteSubmitted);
  }

  void _onWatchStarted(WatchChecksStarted event, Emitter<CheckState> emit) {
    emit(CheckLoading());
    _subscription?.cancel();
    _subscription = _repository
        .watchChecks(type: event.type)
        .listen(
          (checks) => add(_ChecksUpdated(checks)),
          onError: (e) => emit(CheckFailure(e.toString())),
        );
  }

  void _onChecksUpdated(_ChecksUpdated event, Emitter<CheckState> emit) {
    int pendingIssuedMinor = 0;
    int pendingReceivedMinor = 0;
    const currency = Currency.irr;

    for (final c in event.checks) {
      if (c.isDeleted || !c.isPending) continue;
      if (c.type == CheckType.issued) {
        pendingIssuedMinor += c.amount.minorUnits;
      } else {
        pendingReceivedMinor += c.amount.minorUnits;
      }
    }

    emit(
      CheckLoaded(
        checks: event.checks,
        totalPendingIssued: Money.fromMinor(pendingIssuedMinor, currency),
        totalPendingReceived: Money.fromMinor(pendingReceivedMinor, currency),
      ),
    );
  }

  Future<void> _onCreateSubmitted(
    CheckCreateSubmitted event,
    Emitter<CheckState> emit,
  ) async {
    final result = await _repository.createCheck(event.check);
    await result.fold(
      onSuccess: (created) async {
        _scheduleDueReminder(created);
        final eventCode = created.type == CheckType.received
            ? 'register'
            : 'issue';
        await _createVoucherQuietly(created, eventCode);
      },
      onFailure: (failure) async => emit(CheckFailure(failure.message)),
    );
  }

  /// Due-date reminder at 09:00 local on the due date.
  void _scheduleDueReminder(CheckEntity check) {
    final due = check.dueDate;
    final reminderDate = DateTime(due.year, due.month, due.day, 9, 0);
    _notifications.scheduleNotification(
      title: 'چک ${check.checkNumber} سررسید شد',
      body:
          'چک ${check.partyName} به مبلغ ${check.amount.formatCompact()} امروز سررسید می‌شود.',
      type: NotificationType.checkDue,
      referenceId: check.id,
      scheduledFor: reminderDate,
    );
  }

  Future<void> _onStatusUpdated(
    CheckStatusUpdated event,
    Emitter<CheckState> emit,
  ) async {
    final checks = await _repository.getChecks();
    final currentCheck = checks.dataOrNull
        ?.where((c) => c.id == event.id)
        .firstOrNull;
    final oldStatus = currentCheck?.status;

    final result = await _repository.updateCheckStatus(event.id, event.status);
    await result.fold(
      onSuccess: (_) async {
        if (currentCheck != null) {
          await _syncVouchersOnStatusChange(
            check: currentCheck.copyWith(status: event.status),
            oldStatus: oldStatus,
            newStatus: event.status,
          );
        }
      },
      onFailure: (failure) async => emit(CheckFailure(failure.message)),
    );
  }

  Future<void> _syncVouchersOnStatusChange({
    required CheckEntity check,
    CheckStatus? oldStatus,
    required CheckStatus newStatus,
  }) async {
    try {
      if (check.type == CheckType.received) {
        // Ensure initial register voucher exists
        await _autoVoucherService.generateChequeVoucher(check, 'register');

        switch (newStatus) {
          case CheckStatus.cleared:
            // Ensure deposited first in collection, then cleared into bank
            await _autoVoucherService.generateChequeVoucher(check, 'deposit');
            await _autoVoucherService.generateChequeVoucher(check, 'clear');
            break;
          case CheckStatus.transferred:
            if (oldStatus == CheckStatus.cleared) {
              await _autoVoucherService.voidVoucherFor(
                check.id,
                event: 'clear',
              );
            }
            await _autoVoucherService.generateChequeVoucher(check, 'deposit');
            break;
          case CheckStatus.pending:
            await _autoVoucherService.voidVoucherFor(check.id, event: 'clear');
            await _autoVoucherService.voidVoucherFor(
              check.id,
              event: 'deposit',
            );
            break;
          case CheckStatus.bounced:
          case CheckStatus.cancelled:
            await _autoVoucherService.voidVoucherFor(check.id, event: 'clear');
            await _autoVoucherService.voidVoucherFor(
              check.id,
              event: 'deposit',
            );
            break;
        }
      } else {
        // Issued check
        // Ensure initial issue voucher exists
        await _autoVoucherService.generateChequeVoucher(check, 'issue');

        switch (newStatus) {
          case CheckStatus.cleared:
            await _autoVoucherService.generateChequeVoucher(check, 'clear');
            break;
          case CheckStatus.pending:
          case CheckStatus.bounced:
          case CheckStatus.cancelled:
          case CheckStatus.transferred:
            await _autoVoucherService.voidVoucherFor(check.id, event: 'clear');
            break;
        }
      }
    } catch (e, st) {
      AppLogger.warning(
        'خطا در همگام‌سازی اسناد چک ${check.id} به وضعیت $newStatus: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _createVoucherQuietly(
    CheckEntity check,
    String eventCode,
  ) async {
    try {
      await _autoVoucherService.generateChequeVoucher(check, eventCode);
    } catch (e, st) {
      AppLogger.warning(
        'خطا در صدور سند حسابداری چک ${check.id} (رویداد $eventCode): $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _onDeleteSubmitted(
    CheckDeleteSubmitted event,
    Emitter<CheckState> emit,
  ) async {
    final result = await _repository.deleteCheck(event.id);
    await result.fold(
      onSuccess: (_) async {
        _notifications.cancelScheduled(event.id);
        try {
          await _autoVoucherService.voidVoucherFor(event.id);
        } catch (e, st) {
          AppLogger.warning(
            'خطا در ابطال اسناد چک حذف شده ${event.id}: $e',
            error: e,
            stackTrace: st,
          );
        }
      },
      onFailure: (failure) async => emit(CheckFailure(failure.message)),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
