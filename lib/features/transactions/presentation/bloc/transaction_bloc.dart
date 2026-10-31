import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_currency.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

// Events
sealed class TransactionEvent extends Equatable {
  const TransactionEvent();
  @override
  List<Object?> get props => [];
}

final class WatchTransactionsStarted extends TransactionEvent {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? accountId;
  final String? categoryId;
  final int? limit;

  const WatchTransactionsStarted({
    this.startDate,
    this.endDate,
    this.accountId,
    this.categoryId,
    this.limit,
  });

  @override
  List<Object?> get props => [startDate, endDate, accountId, categoryId, limit];
}

final class _TransactionsUpdated extends TransactionEvent {
  final List<TransactionEntity> transactions;
  const _TransactionsUpdated(this.transactions);
  @override
  List<Object?> get props => [transactions];
}

final class TransactionCreateSubmitted extends TransactionEvent {
  final TransactionEntity transaction;
  const TransactionCreateSubmitted(this.transaction);
  @override
  List<Object?> get props => [transaction];
}

final class TransactionUpdateSubmitted extends TransactionEvent {
  final TransactionEntity transaction;
  const TransactionUpdateSubmitted(this.transaction);
  @override
  List<Object?> get props => [transaction];
}

final class TransactionDeleteSubmitted extends TransactionEvent {
  final String id;
  const TransactionDeleteSubmitted(this.id);
  @override
  List<Object?> get props => [id];
}

final class TransactionRestoreSubmitted extends TransactionEvent {
  final String id;
  const TransactionRestoreSubmitted(this.id);
  @override
  List<Object?> get props => [id];
}

// States
sealed class TransactionState extends Equatable {
  const TransactionState();
  @override
  List<Object?> get props => [];
}

final class TransactionInitial extends TransactionState {}

final class TransactionLoading extends TransactionState {}

final class TransactionLoaded extends TransactionState {
  final List<TransactionEntity> transactions;
  final Money totalIncome;
  final Money totalExpense;
  final Money netCashFlow;

  const TransactionLoaded({
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashFlow,
  });

  @override
  List<Object?> get props => [transactions, totalIncome, totalExpense, netCashFlow];
}

final class TransactionFailure extends TransactionState {
  final String message;
  const TransactionFailure(this.message);
  @override
  List<Object?> get props => [message];
}

final class TransactionOperationSuccess extends TransactionState {
  final String message;
  final String? deletedTransactionId;

  const TransactionOperationSuccess(this.message, {this.deletedTransactionId});

  @override
  List<Object?> get props => [message, deletedTransactionId];
}

// Bloc
class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionRepository _repository;
  StreamSubscription<List<TransactionEntity>>? _subscription;

  TransactionBloc(this._repository) : super(TransactionInitial()) {
    on<WatchTransactionsStarted>(_onWatchStarted);
    on<_TransactionsUpdated>(_onTransactionsUpdated);
    on<TransactionCreateSubmitted>(_onCreateSubmitted);
    on<TransactionUpdateSubmitted>(_onUpdateSubmitted);
    on<TransactionDeleteSubmitted>(_onDeleteSubmitted);
    on<TransactionRestoreSubmitted>(_onRestoreSubmitted);
  }

  void _onWatchStarted(WatchTransactionsStarted event, Emitter<TransactionState> emit) {
    // Only show the loading skeleton on first load or after a failure —
    // re-watching after a write must keep the current data on screen.
    if (state is TransactionInitial || state is TransactionFailure) {
      emit(TransactionLoading());
    }
    _subscription?.cancel();
    _subscription = _repository.watchTransactions(
      startDate: event.startDate,
      endDate: event.endDate,
      accountId: event.accountId,
      categoryId: event.categoryId,
      limit: event.limit,
    ).listen(
      (transactions) => add(_TransactionsUpdated(transactions)),
      onError: (e) => emit(TransactionFailure(e.toString())),
    );
  }

  void _onTransactionsUpdated(_TransactionsUpdated event, Emitter<TransactionState> emit) {
    // Totals speak the base currency: Iranian amounts are normalized
    // (Toman↔Rial ×10); foreign-currency rows are excluded from the sums.
    final currency = AppCurrency.base;
    int incomeMinor = 0;
    int expenseMinor = 0;

    for (final tx in event.transactions) {
      if (!tx.amount.isCompatibleWith(currency)) continue;
      final normalized = tx.amount.normalizeTo(currency).minorUnits;
      if (tx.type == TransactionType.income) {
        incomeMinor += normalized;
      } else if (tx.type == TransactionType.expense) {
        expenseMinor += normalized;
      }
    }

    final totalIncome = Money.fromMinor(incomeMinor, currency);
    final totalExpense = Money.fromMinor(expenseMinor, currency);
    final netCashFlow = totalIncome - totalExpense;

    emit(TransactionLoaded(
      transactions: event.transactions,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netCashFlow: netCashFlow,
    ));
  }

  Future<void> _onCreateSubmitted(TransactionCreateSubmitted event, Emitter<TransactionState> emit) async {
    final result = await _repository.createTransaction(event.transaction);
    result.fold(
      onSuccess: (_) {
        emit(const TransactionOperationSuccess('Transaction saved successfully'));
        // Belt-and-suspenders: re-arm the watch so the UI always returns to
        // TransactionLoaded even if a drift stream update was missed.
        add(const WatchTransactionsStarted());
      },
      onFailure: (failure) => emit(TransactionFailure(failure.message)),
    );
  }

  Future<void> _onUpdateSubmitted(TransactionUpdateSubmitted event, Emitter<TransactionState> emit) async {
    final result = await _repository.updateTransaction(event.transaction);
    result.fold(
      onSuccess: (_) {
        emit(const TransactionOperationSuccess('Transaction updated successfully'));
        add(const WatchTransactionsStarted());
      },
      onFailure: (failure) => emit(TransactionFailure(failure.message)),
    );
  }

  Future<void> _onDeleteSubmitted(TransactionDeleteSubmitted event, Emitter<TransactionState> emit) async {
    final result = await _repository.softDeleteTransaction(event.id);
    result.fold(
      onSuccess: (_) {
        emit(TransactionOperationSuccess('Transaction deleted', deletedTransactionId: event.id));
        add(const WatchTransactionsStarted());
      },
      onFailure: (failure) => emit(TransactionFailure(failure.message)),
    );
  }

  Future<void> _onRestoreSubmitted(TransactionRestoreSubmitted event, Emitter<TransactionState> emit) async {
    final result = await _repository.restoreTransaction(event.id);
    result.fold(
      onSuccess: (_) {
        emit(const TransactionOperationSuccess('Transaction restored'));
        add(const WatchTransactionsStarted());
      },
      onFailure: (failure) => emit(TransactionFailure(failure.message)),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
