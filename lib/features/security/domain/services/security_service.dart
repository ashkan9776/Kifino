import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:pointycastle/export.dart' as pc;

import '../../../../core/utils/app_logger.dart';

class SecurityService {
  final FlutterSecureStorage secureStorage;
  final LocalAuthentication _localAuth;

  /// PBKDF2 work factor for new PIN hashes. A 4–6 digit PIN has at most a
  /// million values, so the cost of each guess is what protects it if the
  /// stored hash ever leaks. Injectable so tests can run fast.
  final int pinHashIterations;

  /// Clock used for the lockout window (injectable for tests).
  final DateTime Function() _now;

  static const String _pinHashKey = 'kifino_sec_pin_hash';
  static const String _pinSaltKey = 'kifino_sec_pin_salt';
  static const String _biometricEnabledKey = 'kifino_sec_bio_enabled';
  static const String _screenshotProtectionKey = 'kifino_sec_screenshot_prot';
  static const String _failedAttemptsKey = 'kifino_sec_failed_attempts';
  static const String _lockoutUntilKey = 'kifino_sec_lockout_until';
  static const MethodChannel _securityChannel = MethodChannel(
    'ir.kifino.app/security',
  );

  static const int defaultPinHashIterations = 120000;

  /// Wrong PINs allowed before the first lockout.
  static const int freeAttempts = 5;

  /// First lockout length; it doubles with every further wrong PIN.
  static const Duration baseLockout = Duration(seconds: 30);

  /// Upper bound for a single lockout.
  static const Duration maxLockout = Duration(minutes: 30);

  static const String _v2Prefix = 'pbkdf2';

  SecurityService({
    required this.secureStorage,
    LocalAuthentication? localAuth,
    this.pinHashIterations = defaultPinHashIterations,
    DateTime Function()? clock,
  }) : _localAuth = localAuth ?? LocalAuthentication(),
       _now = clock ?? DateTime.now;

  // ─── Hashing ───

  /// Legacy (pre-v10) format: a single SHA-256 round. Only used to verify
  /// old PINs once so they can be upgraded.
  String _legacyHash(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin:$salt');
    return sha256.convert(bytes).toString();
  }

  static Uint8List _pbkdf2(String pin, Uint8List salt, int iterations) {
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(pin)));
  }

  /// Runs PBKDF2 off the UI thread so the lock screen never stutters.
  Future<String> _hashV2(String pin, String saltB64, int iterations) async {
    final salt = base64Decode(saltB64);
    final key = await Isolate.run(() => _pbkdf2(pin, salt, iterations));
    return '$_v2Prefix\$$iterations\$${base64Encode(key)}';
  }

  static String _newSalt() {
    final rng = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => rng.nextInt(256)));
  }

  /// Compares without exiting early, so timing does not leak how many
  /// leading characters matched.
  static bool _constantTimeEquals(String a, String b) {
    final x = utf8.encode(a);
    final y = utf8.encode(b);
    var diff = x.length ^ y.length;
    for (var i = 0; i < x.length && i < y.length; i++) {
      diff |= x[i] ^ y[i];
    }
    return diff == 0;
  }

  // ─── PIN ───

  Future<bool> isPinSet() async {
    final hash = await secureStorage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    final salt = _newSalt();
    final hash = await _hashV2(pin, salt, pinHashIterations);
    await secureStorage.write(key: _pinSaltKey, value: salt);
    await secureStorage.write(key: _pinHashKey, value: hash);
    await _resetFailures();
  }

  /// Checks [pin] and enforces the lockout: while locked out, returns false
  /// WITHOUT testing the PIN, so guessing cannot continue during the wait.
  /// Use [lockoutRemaining] to tell the user how long to wait.
  Future<bool> verifyPin(String pin) async {
    if (await lockoutRemaining() != null) return false;

    final storedHash = await secureStorage.read(key: _pinHashKey);
    final storedSalt = await secureStorage.read(key: _pinSaltKey);
    if (storedHash == null || storedSalt == null) return false;

    bool ok;
    if (storedHash.startsWith('$_v2Prefix\$')) {
      final parts = storedHash.split('\$');
      final iterations = parts.length == 3 ? int.tryParse(parts[1]) : null;
      if (iterations == null) return false;
      final computed = await _hashV2(pin, storedSalt, iterations);
      ok = _constantTimeEquals(computed, storedHash);
    } else {
      ok = _constantTimeEquals(_legacyHash(pin, storedSalt), storedHash);
      // Upgrade old single-round hashes the first time the PIN is entered.
      if (ok) await savePin(pin);
    }

    if (ok) {
      await _resetFailures();
    } else {
      await _registerFailure();
    }
    return ok;
  }

  /// Time left before another PIN may be tried, or null when not locked.
  Future<Duration?> lockoutRemaining() async {
    final raw = await secureStorage.read(key: _lockoutUntilKey);
    final until = raw == null ? null : int.tryParse(raw);
    if (until == null) return null;
    final left = until - _now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : null;
  }

  Future<int> failedAttempts() async {
    final raw = await secureStorage.read(key: _failedAttemptsKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// Wrong PINs left before the next lockout starts (0 once in lockout mode).
  Future<int> attemptsBeforeLockout() async {
    final left = freeAttempts - await failedAttempts();
    return left > 0 ? left : 0;
  }

  /// Lockout after the [failures]-th wrong PIN: none for the first
  /// [freeAttempts] - 1, then 30s, 1m, 2m, … capped at [maxLockout].
  static Duration? lockoutFor(int failures) {
    if (failures < freeAttempts) return null;
    final doublings = min(failures - freeAttempts, 16);
    final seconds = baseLockout.inSeconds * (1 << doublings);
    return seconds >= maxLockout.inSeconds
        ? maxLockout
        : Duration(seconds: seconds);
  }

  Future<void> _registerFailure() async {
    final failures = await failedAttempts() + 1;
    await secureStorage.write(key: _failedAttemptsKey, value: '$failures');
    final lockout = lockoutFor(failures);
    if (lockout != null) {
      final until = _now().add(lockout).millisecondsSinceEpoch;
      await secureStorage.write(key: _lockoutUntilKey, value: '$until');
    }
  }

  Future<void> _resetFailures() async {
    await secureStorage.delete(key: _failedAttemptsKey);
    await secureStorage.delete(key: _lockoutUntilKey);
  }

  Future<void> removePin() async {
    await secureStorage.delete(key: _pinHashKey);
    await secureStorage.delete(key: _pinSaltKey);
    await secureStorage.delete(key: _biometricEnabledKey);
    await _resetFailures();
  }

  // ─── Biometrics ───

  Future<bool> isBiometricEnabled() async {
    final val = await secureStorage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await secureStorage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateBiometric({
    String reason = 'لطفاً هویت خود را تأیید کنید',
  }) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      // A successful device-owner check proves who is holding the phone.
      if (ok) await _resetFailures();
      return ok;
    } catch (_) {
      return false;
    }
  }

  // ─── Screenshot protection ───

  Future<bool> isScreenshotProtectionEnabled() async {
    final val = await secureStorage.read(key: _screenshotProtectionKey);
    // Defaults to true for financial app privacy
    return val == null || val == 'true';
  }

  Future<void> setScreenshotProtection(bool enabled) async {
    await secureStorage.write(
      key: _screenshotProtectionKey,
      value: enabled.toString(),
    );
    await syncSecurityFlags();
  }

  Future<void> syncSecurityFlags() async {
    final enabled = await isScreenshotProtectionEnabled();
    try {
      if (enabled) {
        await _securityChannel.invokeMethod('enableSecureMode');
      } else {
        await _securityChannel.invokeMethod('disableSecureMode');
      }
    } catch (e) {
      // Secure mode is Android-only: desktop, web and tests have no channel.
      AppLogger.info('Secure-mode channel unavailable: $e');
    }
  }
}
