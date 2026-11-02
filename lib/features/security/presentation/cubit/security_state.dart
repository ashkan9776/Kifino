import 'package:equatable/equatable.dart';

class SecurityState extends Equatable {
  final bool isLocked;
  final bool isPinSet;
  final bool isBiometricEnabled;
  final bool canBiometric;
  final String? errorMessage;
  final bool isAuthenticating;

  const SecurityState({
    this.isLocked = false,
    this.isPinSet = false,
    this.isBiometricEnabled = false,
    this.canBiometric = false,
    this.errorMessage,
    this.isAuthenticating = false,
  });

  SecurityState copyWith({
    bool? isLocked,
    bool? isPinSet,
    bool? isBiometricEnabled,
    bool? canBiometric,
    String? errorMessage,
    bool? isAuthenticating,
  }) {
    return SecurityState(
      isLocked: isLocked ?? this.isLocked,
      isPinSet: isPinSet ?? this.isPinSet,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      canBiometric: canBiometric ?? this.canBiometric,
      errorMessage: errorMessage,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
    );
  }

  @override
  List<Object?> get props => [
    isLocked,
    isPinSet,
    isBiometricEnabled,
    canBiometric,
    errorMessage,
    isAuthenticating,
  ];
}
