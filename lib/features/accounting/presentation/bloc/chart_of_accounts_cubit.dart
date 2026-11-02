import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/accounting_subject_entity.dart';
import '../../domain/repositories/accounting_repository.dart';

sealed class ChartOfAccountsState extends Equatable {
  const ChartOfAccountsState();
  @override
  List<Object?> get props => [];
}

final class ChartOfAccountsInitial extends ChartOfAccountsState {}

final class ChartOfAccountsLoading extends ChartOfAccountsState {}

final class ChartOfAccountsLoaded extends ChartOfAccountsState {
  final List<AccountingSubjectEntity> allSubjects;
  final List<AccountingSubjectEntity> filteredSubjects;
  final AccountingSubjectLevel? selectedLevel;
  final String searchQuery;

  const ChartOfAccountsLoaded({
    required this.allSubjects,
    required this.filteredSubjects,
    this.selectedLevel,
    this.searchQuery = '',
  });

  @override
  List<Object?> get props => [
    allSubjects,
    filteredSubjects,
    selectedLevel,
    searchQuery,
  ];
}

final class ChartOfAccountsError extends ChartOfAccountsState {
  final String message;
  const ChartOfAccountsError(this.message);
  @override
  List<Object?> get props => [message];
}

class ChartOfAccountsCubit extends Cubit<ChartOfAccountsState> {
  final AccountingRepository _repository;

  ChartOfAccountsCubit(this._repository) : super(ChartOfAccountsInitial());

  Future<void> loadChartOfAccounts() async {
    emit(ChartOfAccountsLoading());
    try {
      await _repository.seedChartOfAccountsIfNotExists();
      final subjects = await _repository.getAllSubjects();
      emit(
        ChartOfAccountsLoaded(
          allSubjects: subjects,
          filteredSubjects: subjects,
        ),
      );
    } catch (e) {
      emit(ChartOfAccountsError(e.toString()));
    }
  }

  void filterByLevel(AccountingSubjectLevel? level) {
    final current = state;
    if (current is! ChartOfAccountsLoaded) return;

    final filtered = _applyFilters(
      current.allSubjects,
      level,
      current.searchQuery,
    );

    emit(
      ChartOfAccountsLoaded(
        allSubjects: current.allSubjects,
        filteredSubjects: filtered,
        selectedLevel: level,
        searchQuery: current.searchQuery,
      ),
    );
  }

  void search(String query) {
    final current = state;
    if (current is! ChartOfAccountsLoaded) return;

    final filtered = _applyFilters(
      current.allSubjects,
      current.selectedLevel,
      query,
    );

    emit(
      ChartOfAccountsLoaded(
        allSubjects: current.allSubjects,
        filteredSubjects: filtered,
        selectedLevel: current.selectedLevel,
        searchQuery: query,
      ),
    );
  }

  List<AccountingSubjectEntity> _applyFilters(
    List<AccountingSubjectEntity> subjects,
    AccountingSubjectLevel? level,
    String query,
  ) {
    return subjects.where((s) {
      final matchesLevel = level == null || s.level == level;
      final q = query.trim().toLowerCase();
      final matchesQuery =
          q.isEmpty || s.name.toLowerCase().contains(q) || s.code.contains(q);
      return matchesLevel && matchesQuery;
    }).toList();
  }

  Future<void> addSubject(AccountingSubjectEntity subject) async {
    try {
      await _repository.createSubject(subject);
      await loadChartOfAccounts();
    } catch (e) {
      emit(ChartOfAccountsError(e.toString()));
    }
  }
}
