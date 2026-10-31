import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/money.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/repositories/account_repository.dart';

// States
sealed class OnboardingState extends Equatable {
  const OnboardingState();
  @override
  List<Object?> get props => [];
}

final class OnboardingInitial extends OnboardingState {}

final class OnboardingAccountCreating extends OnboardingState {}

final class OnboardingAccountCreated extends OnboardingState {}

final class OnboardingAccountFailure extends OnboardingState {
  final String message;
  const OnboardingAccountFailure(this.message);
  @override
  List<Object?> get props => [message];
}

/// Drives the first-run wizard: creates the user's very first account
/// from the onboarding form before the main app is unlocked.
class OnboardingCubit extends Cubit<OnboardingState> {
  final AccountRepository _repository;

  OnboardingCubit(this._repository) : super(OnboardingInitial());

  /// Creates the first account from the onboarding form.
  /// Returns `true` on success and `false` on failure.
  Future<bool> createFirstAccount({
    required String name,
    required AccountType type,
    required Money initialBalance,
    String? bankName,
    String? cardLastFour,
  }) async {
    emit(OnboardingAccountCreating());
    try {
      final now = DateTime.now();
      final trimmedBankName = bankName?.trim();
      final trimmedLastFour = cardLastFour?.trim();

      final account = AccountEntity(
        id: const Uuid().v4(),
        name: name.trim(),
        type: type,
        currency: initialBalance.currency,
        initialBalance: initialBalance,
        currentBalance: initialBalance,
        bankName: (trimmedBankName != null && trimmedBankName.isNotEmpty) ? trimmedBankName : null,
        cardNumberLastFour:
            (trimmedLastFour != null && trimmedLastFour.length == 4) ? trimmedLastFour : null,
        createdAt: now,
        updatedAt: now,
      );

      final result = await _repository.createAccount(account);
      final success = result.fold(
        onSuccess: (_) {
          emit(OnboardingAccountCreated());
          return true;
        },
        onFailure: (failure) {
          emit(OnboardingAccountFailure(failure.message));
          return false;
        },
      );
      return success;
    } catch (e) {
      emit(OnboardingAccountFailure(e.toString()));
      return false;
    }
  }
}
