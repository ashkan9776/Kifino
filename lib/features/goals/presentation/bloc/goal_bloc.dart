import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/utils/money.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/repositories/goal_repository.dart';

// Events
sealed class GoalEvent extends Equatable {
  const GoalEvent();
  @override
  List<Object?> get props => [];
}

final class WatchGoalsStarted extends GoalEvent {
  const WatchGoalsStarted();
  @override
  List<Object?> get props => [];
}

final class _GoalsUpdated extends GoalEvent {
  final List<GoalEntity> goals;
  const _GoalsUpdated(this.goals);
  @override
  List<Object?> get props => [goals];
}

final class GoalCreateSubmitted extends GoalEvent {
  final GoalEntity goal;
  const GoalCreateSubmitted(this.goal);
  @override
  List<Object?> get props => [goal];
}

final class GoalContributeSubmitted extends GoalEvent {
  final String id;
  final Money amount;
  const GoalContributeSubmitted(this.id, this.amount);
  @override
  List<Object?> get props => [id, amount];
}

final class GoalDeleteSubmitted extends GoalEvent {
  final String id;
  const GoalDeleteSubmitted(this.id);
  @override
  List<Object?> get props => [id];
}

// States
sealed class GoalState extends Equatable {
  const GoalState();
  @override
  List<Object?> get props => [];
}

final class GoalInitial extends GoalState {}

final class GoalLoading extends GoalState {}

final class GoalLoaded extends GoalState {
  final List<GoalEntity> goals;
  final Money totalSaved;
  final Money totalTarget;
  final double overallPercent;

  const GoalLoaded({
    required this.goals,
    required this.totalSaved,
    required this.totalTarget,
    required this.overallPercent,
  });

  @override
  List<Object?> get props => [goals, totalSaved, totalTarget, overallPercent];
}

final class GoalFailure extends GoalState {
  final String message;
  const GoalFailure(this.message);
  @override
  List<Object?> get props => [message];
}

final class GoalOperationSuccess extends GoalState {
  final String message;
  final String op; // create, contribute, achieve, delete

  const GoalOperationSuccess(this.message, {required this.op});
  @override
  List<Object?> get props => [message, op];
}

// Bloc
class GoalBloc extends Bloc<GoalEvent, GoalState> {
  final GoalRepository _repository;
  StreamSubscription<List<GoalEntity>>? _subscription;

  GoalBloc(this._repository) : super(GoalInitial()) {
    on<WatchGoalsStarted>(_onWatchStarted);
    on<_GoalsUpdated>(_onGoalsUpdated);
    on<GoalCreateSubmitted>(_onCreateSubmitted);
    on<GoalContributeSubmitted>(_onContributeSubmitted);
    on<GoalDeleteSubmitted>(_onDeleteSubmitted);
  }

  void _onWatchStarted(WatchGoalsStarted event, Emitter<GoalState> emit) {
    emit(GoalLoading());
    _subscription?.cancel();
    _subscription = _repository.watchGoals().listen(
          (goals) => add(_GoalsUpdated(goals)),
          onError: (e) => emit(GoalFailure(e.toString())),
        );
  }

  void _onGoalsUpdated(_GoalsUpdated event, Emitter<GoalState> emit) {
    emit(_computeLoaded(event.goals));
  }

  GoalLoaded _computeLoaded(List<GoalEntity> goals) {
    // Totals assume all goals share the same currency (the wallet default).
    final currency = goals.isNotEmpty
        ? goals.first.targetAmount.currency
        : Currency.fromCode('TOMAN');

    int savedMinor = 0;
    int targetMinor = 0;
    for (final g in goals) {
      savedMinor += g.currentAmount.minorUnits;
      targetMinor += g.targetAmount.minorUnits;
    }

    final totalSaved = Money.fromMinor(savedMinor, currency);
    final totalTarget = Money.fromMinor(targetMinor, currency);

    final overallPercent =
        targetMinor <= 0 ? 0.0 : ((savedMinor / targetMinor) * 100).clamp(0.0, 100.0);

    return GoalLoaded(
      goals: goals,
      totalSaved: totalSaved,
      totalTarget: totalTarget,
      overallPercent: overallPercent,
    );
  }

  Future<void> _onCreateSubmitted(GoalCreateSubmitted event, Emitter<GoalState> emit) async {
    final result = await _repository.createGoal(event.goal);
    result.fold(
      onSuccess: (_) => emit(const GoalOperationSuccess('Goal created', op: 'create')),
      onFailure: (failure) => emit(GoalFailure(failure.message)),
    );
  }

  Future<void> _onContributeSubmitted(GoalContributeSubmitted event, Emitter<GoalState> emit) async {
    final result = await _repository.contributeToGoal(event.id, event.amount);
    result.fold(
      onSuccess: (goal) => emit(
        goal.isAchieved
            ? const GoalOperationSuccess('Goal achieved', op: 'achieve')
            : const GoalOperationSuccess('Contribution saved', op: 'contribute'),
      ),
      onFailure: (failure) => emit(GoalFailure(failure.message)),
    );
  }

  Future<void> _onDeleteSubmitted(GoalDeleteSubmitted event, Emitter<GoalState> emit) async {
    final result = await _repository.deleteGoal(event.id);
    result.fold(
      onSuccess: (_) => emit(const GoalOperationSuccess('Goal deleted', op: 'delete')),
      onFailure: (failure) => emit(GoalFailure(failure.message)),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
