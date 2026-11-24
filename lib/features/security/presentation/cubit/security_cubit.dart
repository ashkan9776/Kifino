import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/services/security_service.dart';
import 'security_state.dart';

class SecurityCubit extends Cubit<SecurityState> {
  final SecurityService securityService;

  /// Set when the app goes to background while a PIN is configured, so the
  /// session can be re-locked on return (spec session management).
  bool _wentToBackground = false;

  SecurityCubit({required this.securityService}) : super(const SecurityState());

  Future<void> init() async {
    final isPinSet = await securityService.isPinSet();
    final canBio = await securityService.canCheckBiometrics();
    final isBioEnabled = await securityService.isBiometricEnabled();
    final isSecProt = await securityService.isScreenshotProtectionEnabled();
    await securityService.syncSecurityFlags();
    // A lockout survives app restarts — killing the app must not reset it.
    final lockout = await securityService.lockoutRemaining();

    emit(
      state.copyWith(
        isPinSet: isPinSet,
        canBiometric: canBio,
        isBiometricEnabled: isBioEnabled,
        isScreenshotProtected: isSecProt,
        isLocked: isPinSet, // Automatically lock if PIN is configured
        lockedUntil: lockout == null ? null : DateTime.now().add(lockout),
      ),
    );

    if (isPinSet && isBioEnabled && canBio) {
      authenticateBiometric();
    }
  }

  Future<void> toggleScreenshotProtection(bool enabled) async {
    await securityService.setScreenshotProtection(enabled);
    emit(state.copyWith(isScreenshotProtected: enabled));
  }

  Future<bool> verifyPin(String pin) async {
    emit(state.copyWith(errorMessage: null));
    final isValid = await securityService.verifyPin(pin);
    if (isValid) {
      emit(
        state.copyWith(isLocked: false, errorMessage: null, lockedUntil: null),
      );
      return true;
    }
    await _emitPinFailure();
    return false;
  }

  /// Re-reads the lockout window (e.g. when the lock page opens or its
  /// countdown ends) so the keypad state matches secure storage.
  Future<void> refreshLockout() async {
    final remaining = await securityService.lockoutRemaining();
    emit(
      state.copyWith(
        errorMessage: state.errorMessage,
        lockedUntil: remaining == null ? null : DateTime.now().add(remaining),
      ),
    );
  }

  Future<void> _emitPinFailure() async {
    final remaining = await securityService.lockoutRemaining();
    if (remaining != null) {
      final seconds = remaining.inSeconds + 1;
      emit(
        state.copyWith(
          errorMessage:
              'تلاش‌های نادرست زیاد بود. $seconds ثانیه دیگر دوباره امتحان کنید.',
          lockedUntil: DateTime.now().add(remaining),
        ),
      );
      return;
    }
    final left = await securityService.attemptsBeforeLockout();
    emit(
      state.copyWith(
        errorMessage: left > 0 && left <= 2
            ? 'رمز عبور نادرست است. $left تلاش دیگر تا قفل موقت.'
            : 'رمز عبور وارد شده نادرست است.',
        lockedUntil: null,
      ),
    );
  }

  Future<bool> authenticateBiometric() async {
    if (!state.canBiometric || !state.isBiometricEnabled) return false;

    emit(state.copyWith(isAuthenticating: true));
    final authenticated = await securityService.authenticateBiometric();
    emit(
      state.copyWith(
        isAuthenticating: false,
        isLocked: !authenticated,
        lockedUntil: authenticated ? null : state.lockedUntil,
      ),
    );
    return authenticated;
  }

  Future<void> savePin(String pin) async {
    await securityService.savePin(pin);
    emit(state.copyWith(isPinSet: true, isLocked: false));
  }

  Future<void> removePin() async {
    await securityService.removePin();
    emit(
      state.copyWith(
        isPinSet: false,
        isLocked: false,
        isBiometricEnabled: false,
      ),
    );
  }

  Future<void> toggleBiometrics(bool enabled) async {
    await securityService.setBiometricEnabled(enabled);
    emit(state.copyWith(isBiometricEnabled: enabled));
  }

  void lockApp() {
    if (state.isPinSet) {
      emit(state.copyWith(isLocked: true));
    }
  }

  void unlockApp() {
    emit(state.copyWith(isLocked: false));
  }

  /// Call from the WidgetsBindingObserver when the activity is paused
  /// (sent to background). The system biometric prompt also pauses the
  /// activity — that must NOT count as leaving the app.
  void onAppPaused() {
    if (state.isPinSet && !state.isAuthenticating) {
      _wentToBackground = true;
    }
  }

  /// Call on resume: re-lock the session when the app actually came back
  /// from the background, and immediately offer biometric unlock again.
  Future<void> onAppResumed() async {
    if (!_wentToBackground) return;
    _wentToBackground = false;
    if (!state.isPinSet || state.isLocked) return;

    lockApp();
    if (state.isBiometricEnabled && state.canBiometric) {
      await authenticateBiometric();
    }
  }
}
