import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/financial_statement_report.dart';
import '../../domain/repositories/accounting_repository.dart';

// Events
sealed class FinancialStatementsEvent extends Equatable {
  const FinancialStatementsEvent();
  @override
  List<Object?> get props => [];
}

final class LoadFinancialStatements extends FinancialStatementsEvent {
  final DateTime asOfDate;
  final DateTime startDate;
  final String? fiscalYearId;

  const LoadFinancialStatements({
    required this.asOfDate,
    required this.startDate,
    this.fiscalYearId,
  });

  @override
  List<Object?> get props => [asOfDate, startDate, fiscalYearId];
}

// States
sealed class FinancialStatementsState extends Equatable {
  const FinancialStatementsState();
  @override
  List<Object?> get props => [];
}

final class FinancialStatementsInitial extends FinancialStatementsState {}

final class FinancialStatementsLoading extends FinancialStatementsState {}

final class FinancialStatementsLoaded extends FinancialStatementsState {
  final BalanceSheetReport balanceSheet;
  final IncomeStatementReport incomeStatement;

  const FinancialStatementsLoaded({
    required this.balanceSheet,
    required this.incomeStatement,
  });

  @override
  List<Object?> get props => [balanceSheet, incomeStatement];
}

final class FinancialStatementsError extends FinancialStatementsState {
  final String message;
  const FinancialStatementsError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class FinancialStatementsBloc
    extends Bloc<FinancialStatementsEvent, FinancialStatementsState> {
  final AccountingRepository _repository;

  FinancialStatementsBloc(this._repository) : super(FinancialStatementsInitial()) {
    on<LoadFinancialStatements>(_onLoad);
  }

  Future<void> _onLoad(
    LoadFinancialStatements event,
    Emitter<FinancialStatementsState> emit,
  ) async {
    emit(FinancialStatementsLoading());
    try {
      await _repository.seedChartOfAccountsIfNotExists();
      final balanceSheet = await _repository.getBalanceSheetReport(
        asOfDate: event.asOfDate,
        fiscalYearId: event.fiscalYearId,
      );
      final incomeStatement = await _repository.getIncomeStatementReport(
        startDate: event.startDate,
        endDate: event.asOfDate,
        fiscalYearId: event.fiscalYearId,
      );
      emit(
        FinancialStatementsLoaded(
          balanceSheet: balanceSheet,
          incomeStatement: incomeStatement,
        ),
      );
    } catch (e) {
      emit(FinancialStatementsError(e.toString()));
    }
  }
}
