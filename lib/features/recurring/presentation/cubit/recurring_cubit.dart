import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/recurring_rule_entity.dart';
import '../../domain/repositories/recurring_repository.dart';
import '../../domain/services/recurring_service.dart';

class RecurringState extends Equatable {
  final bool loading;
  final List<RecurringRuleEntity> rules;

  /// One-shot feedback for a snackbar (success or error).
  final String? message;
  final bool messageIsError;

  const RecurringState({
    this.loading = true,
    this.rules = const [],
    this.message,
    this.messageIsError = false,
  });

  List<RecurringRuleEntity> get active =>
      rules.where((r) => r.isActive && !r.isFinished).toList();

  List<RecurringRuleEntity> get paused =>
      rules.where((r) => !r.isActive || r.isFinished).toList();

  /// Fixed monthly outflow of active expense rules, in the base currency.
  Money get monthlyCommitments => _monthly(TransactionType.expense);

  /// Fixed monthly inflow of active income rules, in the base currency.
  Money get monthlyIncome => _monthly(TransactionType.income);

  Money _monthly(TransactionType type) {
    final base = AppCurrency.base;
    var total = 0;
    for (final r in active) {
      if (r.type != type || !r.amount.isCompatibleWith(base)) continue;
      total += r.monthlyEquivalent.normalizeTo(base).minorUnits;
    }
    return Money.fromMinor(total, base);
  }

  RecurringState copyWith({
    bool? loading,
    List<RecurringRuleEntity>? rules,
    String? message,
    bool messageIsError = false,
  }) => RecurringState(
    loading: loading ?? this.loading,
    rules: rules ?? this.rules,
    message: message,
    messageIsError: messageIsError,
  );

  @override
  List<Object?> get props => [loading, rules, message, messageIsError];
}

class RecurringCubit extends Cubit<RecurringState> {
  final RecurringRepository _repository;
  final RecurringService _service;
  StreamSubscription<List<RecurringRuleEntity>>? _sub;

  RecurringCubit({required this._repository, required this._service})
    : super(const RecurringState());

  void watch() {
    _sub?.cancel();
    _sub = _repository.watchRules().listen(
      (rules) => emit(state.copyWith(loading: false, rules: rules)),
    );
  }

  Future<bool> save(RecurringRuleEntity rule, {required bool isNew}) async {
    final result = isNew
        ? await _repository.createRule(rule)
        : await _repository.updateRule(rule);
    if (result.isFailure) {
      emit(
        state.copyWith(
          message: result.failureOrNull!.message,
          messageIsError: true,
        ),
      );
      return false;
    }
    // A rule starting today (or in the past) posts right away.
    final run = await _service.postDue();
    emit(
      state.copyWith(
        message: run.posted > 0
            ? TextNormalizer.auto(
                'ذخیره شد و ${run.posted} مورد سررسیدشده ثبت شد.',
              )
            : 'ذخیره شد.',
      ),
    );
    return true;
  }

  Future<void> delete(String id) async {
    final result = await _repository.deleteRule(id);
    emit(
      state.copyWith(
        message: result.isFailure ? result.failureOrNull!.message : 'حذف شد.',
        messageIsError: result.isFailure,
      ),
    );
  }

  Future<void> setActive(String id, bool active) async {
    final result = await _repository.setActive(id, active);
    if (result.isFailure) {
      emit(
        state.copyWith(
          message: result.failureOrNull!.message,
          messageIsError: true,
        ),
      );
    }
  }

  /// Confirms (posts) the current occurrence now.
  Future<void> postNow(String id) async {
    final error = await _service.postNow(id);
    emit(
      state.copyWith(
        message: error ?? 'ثبت شد.',
        messageIsError: error != null,
      ),
    );
  }

  Future<void> skip(String id) async {
    await _service.skip(id);
    emit(state.copyWith(message: 'این نوبت رد شد.'));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
