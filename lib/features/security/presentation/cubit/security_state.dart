import 'package:equatable/equatable.dart';

class SecurityState extends Equatable {
  final bool isLocked;
  final bool isPinSet;
  final bool isBiometricEnabled;
  final bool canBiometric;
  final bool isScreenshotProtected;
  final String? errorMessage;
  final bool isAuthenticating;

  /// While set and in the future, PIN entry is blocked (too many wrong PINs).
  final DateTime? lockedUntil;

  const SecurityState({
    this.isLocked = false,
    this.isPinSet = false,
    this.isBiometricEnabled = false,
    this.canBiometric = false,
    this.isScreenshotProtected = true,
    this.errorMessage,
    this.isAuthenticating = false,
    this.lockedUntil,
  });

  static const Object _keep = Object();

  SecurityState copyWith({
    bool? isLocked,
    bool? isPinSet,
    bool? isBiometricEnabled,
    bool? canBiometric,
    bool? isScreenshotProtected,
    String? errorMessage,
    bool? isAuthenticating,
    Object? lockedUntil = _keep,
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
      lockedUntil: identical(lockedUntil, _keep)
          ? this.lockedUntil
          : lockedUntil as DateTime?,
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
    lockedUntil,
  ];
}
