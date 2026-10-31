import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/ledger_entry.dart';
import '../../domain/repositories/accounting_repository.dart';

// Events
sealed class LedgerEvent extends Equatable {
  const LedgerEvent();
  @override
  List<Object?> get props => [];
}

final class LoadLedgerReport extends LedgerEvent {
  final String subjectId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? fiscalYearId;

  const LoadLedgerReport({
    required this.subjectId,
    this.startDate,
    this.endDate,
    this.fiscalYearId,
  });

  @override
  List<Object?> get props => [subjectId, startDate, endDate, fiscalYearId];
}

// States
sealed class LedgerState extends Equatable {
  const LedgerState();
  @override
  List<Object?> get props => [];
}

final class LedgerInitial extends LedgerState {}

final class LedgerLoading extends LedgerState {}

final class LedgerLoaded extends LedgerState {
  final LedgerReport report;
  const LedgerLoaded(this.report);
  @override
  List<Object?> get props => [report];
}

final class LedgerError extends LedgerState {
  final String message;
  const LedgerError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class LedgerBloc extends Bloc<LedgerEvent, LedgerState> {
  final AccountingRepository _repository;

  LedgerBloc(this._repository) : super(LedgerInitial()) {
    on<LoadLedgerReport>(_onLoad);
  }

  Future<void> _onLoad(
    LoadLedgerReport event,
    Emitter<LedgerState> emit,
  ) async {
    emit(LedgerLoading());
    try {
      final report = await _repository.getLedgerReport(
        subjectId: event.subjectId,
        startDate: event.startDate,
        endDate: event.endDate,
        fiscalYearId: event.fiscalYearId,
      );
      emit(LedgerLoaded(report));
    } catch (e) {
      emit(LedgerError(e.toString()));
    }
  }
}
