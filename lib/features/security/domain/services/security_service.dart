import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';

class SecurityService {
  final FlutterSecureStorage secureStorage;
  final LocalAuthentication _localAuth;

  static const String _pinHashKey = 'kifino_sec_pin_hash';
  static const String _pinSaltKey = 'kifino_sec_pin_salt';
  static const String _biometricEnabledKey = 'kifino_sec_bio_enabled';

  SecurityService({required this.secureStorage, LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('$salt:$pin:$salt');
    return sha256.convert(bytes).toString();
  }

  Future<bool> isPinSet() async {
    final hash = await secureStorage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> savePin(String pin) async {
    final salt = const Uuid().v4();
    final hash = _hashPin(pin, salt);
    await secureStorage.write(key: _pinSaltKey, value: salt);
    await secureStorage.write(key: _pinHashKey, value: hash);
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await secureStorage.read(key: _pinHashKey);
    final storedSalt = await secureStorage.read(key: _pinSaltKey);
    if (storedHash == null || storedSalt == null) return false;
    final computed = _hashPin(pin, storedSalt);
    return computed == storedHash;
  }

  Future<void> removePin() async {
    await secureStorage.delete(key: _pinHashKey);
    await secureStorage.delete(key: _pinSaltKey);
    await secureStorage.delete(key: _biometricEnabledKey);
  }

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
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
