import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_currency.dart';
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

/// Transient success state — extends [GoalLoaded] so the UI list keeps
/// rendering without flashing [AppEmptyState].
final class GoalOperationSuccess extends GoalLoaded {
  final String message;
  final String op; // create, contribute, achieve, delete

  const GoalOperationSuccess(
    this.message, {
    required this.op,
    required super.goals,
    required super.totalSaved,
    required super.totalTarget,
    required super.overallPercent,
  });

  @override
  List<Object?> get props => [...super.props, message, op];
}

// Bloc
class GoalBloc extends Bloc<GoalEvent, GoalState> {
  final GoalRepository _repository;
  StreamSubscription<List<GoalEntity>>? _subscription;
  List<GoalEntity> _lastGoals = const [];
  bool _hasLoaded = false;

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
    _lastGoals = event.goals;
    _hasLoaded = true;
    emit(_computeLoaded(event.goals));
  }

  GoalLoaded _computeLoaded(List<GoalEntity> goals) {
    final baseCurrency = AppCurrency.base;

    int savedMinor = 0;
    int targetMinor = 0;
    for (final g in goals) {
      if (g.currentAmount.isCompatibleWith(baseCurrency)) {
        savedMinor += g.currentAmount.currency == baseCurrency
            ? g.currentAmount.minorUnits
            : g.currentAmount.normalizeTo(baseCurrency).minorUnits;
      }
      if (g.targetAmount.isCompatibleWith(baseCurrency)) {
        targetMinor += g.targetAmount.currency == baseCurrency
            ? g.targetAmount.minorUnits
            : g.targetAmount.normalizeTo(baseCurrency).minorUnits;
      }
    }

    final totalSaved = Money.fromMinor(savedMinor, baseCurrency);
    final totalTarget = Money.fromMinor(targetMinor, baseCurrency);

    final overallPercent = targetMinor <= 0
        ? 0.0
        : ((savedMinor / targetMinor) * 100).clamp(0.0, 100.0);

    return GoalLoaded(
      goals: goals,
      totalSaved: totalSaved,
      totalTarget: totalTarget,
      overallPercent: overallPercent,
    );
  }

  void _emitSuccess(
    Emitter<GoalState> emit,
    String message, {
    required String op,
  }) {
    final loaded = _computeLoaded(_lastGoals);
    emit(
      GoalOperationSuccess(
        message,
        op: op,
        goals: loaded.goals,
        totalSaved: loaded.totalSaved,
        totalTarget: loaded.totalTarget,
        overallPercent: loaded.overallPercent,
      ),
    );
  }

  void _emitFailurePreservingLoaded(Emitter<GoalState> emit, String message) {
    emit(GoalFailure(message));
    if (_hasLoaded) {
      emit(_computeLoaded(_lastGoals));
    }
  }

  Future<void> _onCreateSubmitted(
    GoalCreateSubmitted event,
    Emitter<GoalState> emit,
  ) async {
    final result = await _repository.createGoal(event.goal);
    result.fold(
      onSuccess: (created) {
        if (!_lastGoals.any((g) => g.id == created.id)) {
          _lastGoals = [created, ..._lastGoals];
          _hasLoaded = true;
        }
        _emitSuccess(emit, 'Goal created', op: 'create');
      },
      onFailure: (failure) =>
          _emitFailurePreservingLoaded(emit, failure.message),
    );
  }

  Future<void> _onContributeSubmitted(
    GoalContributeSubmitted event,
    Emitter<GoalState> emit,
  ) async {
    final result = await _repository.contributeToGoal(event.id, event.amount);
    result.fold(
      onSuccess: (goal) {
        _lastGoals = [
          for (final g in _lastGoals) g.id == goal.id ? goal : g,
        ];
        if (goal.isAchieved) {
          _emitSuccess(emit, 'Goal achieved', op: 'achieve');
        } else {
          _emitSuccess(emit, 'Contribution saved', op: 'contribute');
        }
      },
      onFailure: (failure) =>
          _emitFailurePreservingLoaded(emit, failure.message),
    );
  }

  Future<void> _onDeleteSubmitted(
    GoalDeleteSubmitted event,
    Emitter<GoalState> emit,
  ) async {
    final result = await _repository.deleteGoal(event.id);
    result.fold(
      onSuccess: (_) {
        _lastGoals = _lastGoals.where((g) => g.id != event.id).toList();
        _emitSuccess(emit, 'Goal deleted', op: 'delete');
      },
      onFailure: (failure) =>
          _emitFailurePreservingLoaded(emit, failure.message),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
