import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../analytics/domain/services/financial_calculators.dart';
import '../../domain/entities/budget_entity.dart';
import '../../domain/repositories/budget_repository.dart';

// Events
sealed class BudgetEvent extends Equatable {
  const BudgetEvent();
  @override
  List<Object?> get props => [];
}

final class WatchBudgetsStarted extends BudgetEvent {
  final DateTime? forDate;
  const WatchBudgetsStarted({this.forDate});
  @override
  List<Object?> get props => [forDate];
}

final class _BudgetsUpdated extends BudgetEvent {
  final List<BudgetEntity> budgets;
  const _BudgetsUpdated(this.budgets);
  @override
  List<Object?> get props => [budgets];
}

final class BudgetCreateSubmitted extends BudgetEvent {
  final BudgetEntity budget;
  const BudgetCreateSubmitted(this.budget);
  @override
  List<Object?> get props => [budget];
}

final class BudgetDeleteSubmitted extends BudgetEvent {
  final String id;
  const BudgetDeleteSubmitted(this.id);
  @override
  List<Object?> get props => [id];
}

// States
sealed class BudgetState extends Equatable {
  const BudgetState();
  @override
  List<Object?> get props => [];
}

final class BudgetInitial extends BudgetState {}

final class BudgetLoading extends BudgetState {}

final class BudgetLoaded extends BudgetState {
  final List<BudgetEntity> budgets;
  final BudgetHealthResult health;

  const BudgetLoaded({required this.budgets, required this.health});

  @override
  List<Object?> get props => [budgets, health];
}

final class BudgetFailure extends BudgetState {
  final String message;
  const BudgetFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  final BudgetRepository _repository;
  StreamSubscription<List<BudgetEntity>>? _subscription;

  BudgetBloc(this._repository) : super(BudgetInitial()) {
    on<WatchBudgetsStarted>(_onWatchStarted);
    on<_BudgetsUpdated>(_onBudgetsUpdated);
    on<BudgetCreateSubmitted>(_onCreateSubmitted);
    on<BudgetDeleteSubmitted>(_onDeleteSubmitted);
  }

  void _onWatchStarted(WatchBudgetsStarted event, Emitter<BudgetState> emit) {
    emit(BudgetLoading());
    _subscription?.cancel();
    _subscription = _repository
        .watchActiveBudgets(forDate: event.forDate)
        .listen(
          (budgets) => add(_BudgetsUpdated(budgets)),
          onError: (e) => emit(BudgetFailure(e.toString())),
        );
  }

  void _onBudgetsUpdated(_BudgetsUpdated event, Emitter<BudgetState> emit) {
    final health = BudgetAdherenceCalculator.calculate(event.budgets);
    emit(BudgetLoaded(budgets: event.budgets, health: health));
  }

  Future<void> _onCreateSubmitted(
    BudgetCreateSubmitted event,
    Emitter<BudgetState> emit,
  ) async {
    final result = await _repository.createBudget(event.budget);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(BudgetFailure(failure.message)),
    );
  }

  Future<void> _onDeleteSubmitted(
    BudgetDeleteSubmitted event,
    Emitter<BudgetState> emit,
  ) async {
    final result = await _repository.deleteBudget(event.id);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(BudgetFailure(failure.message)),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
