import 'package:equatable/equatable.dart';

class SecurityState extends Equatable {
  final bool isLocked;
  final bool isPinSet;
  final bool isBiometricEnabled;
  final bool canBiometric;
  final bool isScreenshotProtected;
  final String? errorMessage;
  final bool isAuthenticating;

  const SecurityState({
    this.isLocked = false,
    this.isPinSet = false,
    this.isBiometricEnabled = false,
    this.canBiometric = false,
    this.isScreenshotProtected = true,
    this.errorMessage,
    this.isAuthenticating = false,
  });

  SecurityState copyWith({
    bool? isLocked,
    bool? isPinSet,
    bool? isBiometricEnabled,
    bool? canBiometric,
    bool? isScreenshotProtected,
    String? errorMessage,
    bool? isAuthenticating,
  }) {
    return SecurityState(
      isLocked: isLocked ?? this.isLocked,
      isPinSet: isPinSet ?? this.isPinSet,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      canBiometric: canBiometric ?? this.canBiometric,
      isScreenshotProtected:
          isScreenshotProtected ?? this.isScreenshotProtected,
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
    isScreenshotProtected,
    errorMessage,
    isAuthenticating,
  ];
}
