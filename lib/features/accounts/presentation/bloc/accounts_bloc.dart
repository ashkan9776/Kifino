import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_currency.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/account_entity.dart';
import '../../domain/repositories/account_repository.dart';

// Events
sealed class AccountsEvent extends Equatable {
  const AccountsEvent();
  @override
  List<Object?> get props => [];
}

final class WatchAccountsStarted extends AccountsEvent {
  final bool includeArchived;
  const WatchAccountsStarted({this.includeArchived = false});
  @override
  List<Object?> get props => [includeArchived];
}

final class _AccountsUpdated extends AccountsEvent {
  final List<AccountEntity> accounts;
  const _AccountsUpdated(this.accounts);
  @override
  List<Object?> get props => [accounts];
}

final class AccountCreateRequested extends AccountsEvent {
  final AccountEntity account;
  const AccountCreateRequested(this.account);
  @override
  List<Object?> get props => [account];
}

final class AccountArchiveToggled extends AccountsEvent {
  final String id;
  final bool archive;
  const AccountArchiveToggled(this.id, this.archive);
  @override
  List<Object?> get props => [id, archive];
}

final class AccountDeleteRequested extends AccountsEvent {
  final String id;
  const AccountDeleteRequested(this.id);
  @override
  List<Object?> get props => [id];
}

// States
sealed class AccountsState extends Equatable {
  const AccountsState();
  @override
  List<Object?> get props => [];
}

final class AccountsInitial extends AccountsState {}

final class AccountsLoading extends AccountsState {}

final class AccountsLoaded extends AccountsState {
  final List<AccountEntity> accounts;
  final Money totalBalance;

  const AccountsLoaded({required this.accounts, required this.totalBalance});

  @override
  List<Object?> get props => [accounts, totalBalance];
}

final class AccountsFailure extends AccountsState {
  final String message;
  const AccountsFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class AccountsBloc extends Bloc<AccountsEvent, AccountsState> {
  final AccountRepository _repository;
  StreamSubscription<List<AccountEntity>>? _subscription;

  AccountsBloc(this._repository) : super(AccountsInitial()) {
    on<WatchAccountsStarted>(_onWatchStarted);
    on<_AccountsUpdated>(_onAccountsUpdated);
    on<AccountCreateRequested>(_onCreateRequested);
    on<AccountArchiveToggled>(_onArchiveToggled);
    on<AccountDeleteRequested>(_onDeleteRequested);
  }

  void _onWatchStarted(
    WatchAccountsStarted event,
    Emitter<AccountsState> emit,
  ) {
    emit(AccountsLoading());
    _subscription?.cancel();
    _subscription = _repository
        .watchAccounts(includeArchived: event.includeArchived)
        .listen(
          (accounts) => add(_AccountsUpdated(accounts)),
          onError: (e) => emit(AccountsFailure(e.toString())),
        );
  }

  void _onAccountsUpdated(_AccountsUpdated event, Emitter<AccountsState> emit) {
    // Net worth speaks the base currency: Iranian balances are normalized
    // (Toman↔Rial ×10), foreign-currency accounts are listed but excluded
    // from the sum since no exchange rate is invented.
    final currency = AppCurrency.base;
    int totalMinor = 0;

    for (final acc in event.accounts) {
      if (!acc.isArchived && acc.currentBalance.isCompatibleWith(currency)) {
        totalMinor += acc.currentBalance.normalizeTo(currency).minorUnits;
      }
    }

    emit(
      AccountsLoaded(
        accounts: event.accounts,
        totalBalance: Money.fromMinor(totalMinor, currency),
      ),
    );
  }

  Future<void> _onCreateRequested(
    AccountCreateRequested event,
    Emitter<AccountsState> emit,
  ) async {
    final result = await _repository.createAccount(event.account);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(AccountsFailure(failure.message)),
    );
  }

  Future<void> _onArchiveToggled(
    AccountArchiveToggled event,
    Emitter<AccountsState> emit,
  ) async {
    final result = await _repository.archiveAccount(event.id, event.archive);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(AccountsFailure(failure.message)),
    );
  }

  Future<void> _onDeleteRequested(
    AccountDeleteRequested event,
    Emitter<AccountsState> emit,
  ) async {
    final result = await _repository.deleteAccount(event.id);
    result.fold(
      onSuccess: (_) {},
      onFailure: (failure) => emit(AccountsFailure(failure.message)),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
