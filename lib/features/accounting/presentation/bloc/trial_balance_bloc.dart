import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/accounting_subject_entity.dart';
import '../../domain/entities/trial_balance_entry.dart';
import '../../domain/repositories/accounting_repository.dart';

// Events
sealed class TrialBalanceEvent extends Equatable {
  const TrialBalanceEvent();
  @override
  List<Object?> get props => [];
}

final class LoadTrialBalance extends TrialBalanceEvent {
  final AccountingSubjectLevel level;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? fiscalYearId;

  const LoadTrialBalance({
    this.level = AccountingSubjectLevel.kol,
    this.startDate,
    this.endDate,
    this.fiscalYearId,
  });

  @override
  List<Object?> get props => [level, startDate, endDate, fiscalYearId];
}

// States
sealed class TrialBalanceState extends Equatable {
  const TrialBalanceState();
  @override
  List<Object?> get props => [];
}

final class TrialBalanceInitial extends TrialBalanceState {}

final class TrialBalanceLoading extends TrialBalanceState {}

final class TrialBalanceLoaded extends TrialBalanceState {
  final TrialBalanceReport report;
  final bool isEightColumn;

  const TrialBalanceLoaded({
    required this.report,
    this.isEightColumn = false,
  });

  TrialBalanceLoaded copyWith({
    TrialBalanceReport? report,
    bool? isEightColumn,
  }) {
    return TrialBalanceLoaded(
      report: report ?? this.report,
      isEightColumn: isEightColumn ?? this.isEightColumn,
    );
  }

  @override
  List<Object?> get props => [report, isEightColumn];
}

final class TrialBalanceError extends TrialBalanceState {
  final String message;
  const TrialBalanceError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class TrialBalanceBloc extends Bloc<TrialBalanceEvent, TrialBalanceState> {
  final AccountingRepository _repository;

  TrialBalanceBloc(this._repository) : super(TrialBalanceInitial()) {
    on<LoadTrialBalance>(_onLoad);
  }

  Future<void> _onLoad(
    LoadTrialBalance event,
    Emitter<TrialBalanceState> emit,
  ) async {
    emit(TrialBalanceLoading());
    try {
      await _repository.seedChartOfAccountsIfNotExists();
      final report = await _repository.getTrialBalanceReport(
        level: event.level,
        startDate: event.startDate,
        endDate: event.endDate,
        fiscalYearId: event.fiscalYearId,
      );
      emit(TrialBalanceLoaded(report: report));
    } catch (e) {
      emit(TrialBalanceError(e.toString()));
    }
  }
}
