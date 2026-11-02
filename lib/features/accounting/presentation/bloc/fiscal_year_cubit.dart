import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/fiscal_year_entity.dart';
import '../../domain/repositories/accounting_repository.dart';

sealed class FiscalYearState extends Equatable {
  const FiscalYearState();
  @override
  List<Object?> get props => [];
}

final class FiscalYearInitial extends FiscalYearState {}

final class FiscalYearLoading extends FiscalYearState {}

/// Fiscal years with a [isBusy] flag while a long close/define operation runs.
/// [message] / [messageIsError] carry the last feedback (Persian) and
/// [messageStamp] keeps it unique so identical messages re-trigger listeners.
final class FiscalYearLoaded extends FiscalYearState {
  final List<FiscalYearEntity> years;
  final bool isBusy;
  final String? message;
  final bool messageIsError;
  final int messageStamp;

  const FiscalYearLoaded({
    required this.years,
    this.isBusy = false,
    this.message,
    this.messageIsError = false,
    this.messageStamp = 0,
  });

  @override
  List<Object?> get props => [
    years,
    isBusy,
    message,
    messageIsError,
    messageStamp,
  ];
}

final class FiscalYearError extends FiscalYearState {
  final String message;

  const FiscalYearError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Fiscal year management: listing, closing with vouchers, defining next year.
class FiscalYearCubit extends Cubit<FiscalYearState> {
  final AccountingRepository _repository;

  FiscalYearCubit(this._repository) : super(FiscalYearInitial());

  Future<void> load() async {
    emit(FiscalYearLoading());
    try {
      final years = await _repository.getFiscalYears();
      emit(FiscalYearLoaded(years: years));
    } catch (e) {
      emit(FiscalYearError(_message(e)));
    }
  }

  /// Closes the year with the full voucher flow (closing voucher, next year,
  /// opening voucher) — the repository performs everything atomically.
  Future<void> closeYear(String fiscalYearId) async {
    await _mutate(
      () => _repository.closeFiscalYearWithDocuments(fiscalYearId),
      successMessage: 'سال مالی با موفقیت بسته شد',
    );
  }

  /// Defines the next fiscal year (N+1) right after the latest one — or the
  /// first Jalali year when no year exists yet.
  Future<void> createNextYear() async {
    final current = state;
    if (current is! FiscalYearLoaded) return;
    if (current.isBusy) return;
    final now = DateTime.now();
    final FiscalYearEntity next;

    if (current.years.isEmpty) {
      final jNow = JalaliDate.fromDateTime(now);
      final start = JalaliDate(jNow.year, 1, 1).toDateTime();
      final end = JalaliDate(
        jNow.year + 1,
        1,
        1,
      ).toDateTime().subtract(const Duration(days: 1));
      next = FiscalYearEntity(
        id: const Uuid().v4(),
        title: 'سال مالی ۱',
        yearNumber: 1,
        startDate: start,
        endDate: end,
        createdAt: now,
        updatedAt: now,
      );
    } else {
      final latest = current.years.reduce(
        (a, b) => a.yearNumber >= b.yearNumber ? a : b,
      );
      final start = latest.endDate.add(const Duration(days: 1));
      final end = DateTime(
        start.year + 1,
        start.month,
        start.day,
      ).subtract(const Duration(days: 1));
      next = FiscalYearEntity(
        id: const Uuid().v4(),
        title: 'سال مالی ${latest.yearNumber + 1}',
        yearNumber: latest.yearNumber + 1,
        startDate: start,
        endDate: end,
        createdAt: now,
        updatedAt: now,
      );
    }

    await _mutate(
      () => _repository.createFiscalYear(next),
      successMessage: '${next.title} تعریف شد',
    );
  }

  Future<void> _mutate(
    Future<Object?> Function() action, {
    required String successMessage,
  }) async {
    final current = state;
    final years = current is FiscalYearLoaded
        ? current.years
        : const <FiscalYearEntity>[];
    if (current is FiscalYearLoaded && current.isBusy) return;
    emit(FiscalYearLoaded(years: years, isBusy: true));
    try {
      await action();
      final fresh = await _repository.getFiscalYears();
      emit(
        FiscalYearLoaded(
          years: fresh,
          message: successMessage,
          messageStamp: DateTime.now().microsecondsSinceEpoch,
        ),
      );
    } catch (e) {
      emit(
        FiscalYearLoaded(
          years: years,
          message: _message(e),
          messageIsError: true,
          messageStamp: DateTime.now().microsecondsSinceEpoch,
        ),
      );
    }
  }

  static String _message(Object e) =>
      e.toString().replaceFirst(RegExp(r'^(Bad state|StateError):\s*'), '');
}
