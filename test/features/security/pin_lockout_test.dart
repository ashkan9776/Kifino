import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/features/security/domain/services/security_service.dart';
import 'package:kifino/features/security/presentation/cubit/security_cubit.dart';
import 'package:local_auth/local_auth.dart';

class _MemoryStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data.remove(key);
}

class _NoBiometrics extends Fake implements LocalAuthentication {
  @override
  Future<bool> get canCheckBiometrics async => false;

  @override
  Future<bool> isDeviceSupported() async => false;
}

void main() {
  late _MemoryStorage storage;
  late DateTime now;
  late SecurityService service;

  SecurityService build({int iterations = 1000}) => SecurityService(
    secureStorage: storage,
    localAuth: _NoBiometrics(),
    pinHashIterations: iterations,
    clock: () => now,
  );

  setUp(() {
    storage = _MemoryStorage();
    now = DateTime(2026, 11, 24, 10);
    service = build();
  });

  group('PIN hashing', () {
    test('new PINs are stored as salted PBKDF2, not plain SHA-256', () async {
      await service.savePin('1234');
      final stored = storage.data['kifino_sec_pin_hash']!;
      expect(stored, startsWith(r'pbkdf2$1000$'));
      expect(await service.verifyPin('1234'), isTrue);
      expect(await service.verifyPin('4321'), isFalse);
    });

    test('the production work factor is high enough to slow guessing', () {
      expect(
        SecurityService.defaultPinHashIterations,
        greaterThanOrEqualTo(100000),
      );
    });

    test('a legacy SHA-256 PIN still unlocks and is upgraded', () async {
      const salt = 'legacy-salt';
      storage.data['kifino_sec_pin_salt'] = salt;
      storage.data['kifino_sec_pin_hash'] = sha256
          .convert(utf8.encode('$salt:2580:$salt'))
          .toString();

      expect(await service.verifyPin('2580'), isTrue);
      expect(storage.data['kifino_sec_pin_hash'], startsWith(r'pbkdf2$'));
      expect(await service.verifyPin('2580'), isTrue);
      expect(await service.verifyPin('0000'), isFalse);
    });
  });

  group('lockout', () {
    test('schedule: 4 free misses, then 30s doubling, capped at 30 min', () {
      expect(SecurityService.lockoutFor(4), isNull);
      expect(SecurityService.lockoutFor(5), const Duration(seconds: 30));
      expect(SecurityService.lockoutFor(6), const Duration(minutes: 1));
      expect(SecurityService.lockoutFor(7), const Duration(minutes: 2));
      expect(SecurityService.lockoutFor(50), const Duration(minutes: 30));
    });

    test(
      'blocks guessing — even the right PIN — until the wait is over',
      () async {
        await service.savePin('1234');
        for (var i = 0; i < 5; i++) {
          expect(await service.verifyPin('0000'), isFalse);
        }
        expect(await service.lockoutRemaining(), const Duration(seconds: 30));

        // Correct PIN is refused while locked out, and not even checked.
        expect(await service.verifyPin('1234'), isFalse);

        now = now.add(const Duration(seconds: 31));
        expect(await service.lockoutRemaining(), isNull);
        expect(await service.verifyPin('1234'), isTrue);
        expect(await service.failedAttempts(), 0);
      },
    );

    test('each further miss doubles the wait', () async {
      await service.savePin('1234');
      for (var i = 0; i < 5; i++) {
        await service.verifyPin('0000');
      }
      now = now.add(const Duration(seconds: 31));
      await service.verifyPin('0000'); // 6th miss
      expect(await service.lockoutRemaining(), const Duration(minutes: 1));
    });

    test('survives an app restart (new service instance)', () async {
      await service.savePin('1234');
      for (var i = 0; i < 5; i++) {
        await service.verifyPin('0000');
      }
      final restarted = build();
      expect(await restarted.lockoutRemaining(), isNotNull);
      expect(await restarted.verifyPin('1234'), isFalse);
    });

    test('cubit exposes the lockout so the keypad can be disabled', () async {
      await service.savePin('1234');
      final cubit = SecurityCubit(securityService: service);
      addTearDown(cubit.close);
      await cubit.init();

      for (var i = 0; i < 4; i++) {
        await cubit.verifyPin('0000');
      }
      expect(cubit.state.lockedUntil, isNull);
      expect(cubit.state.errorMessage, contains('۱').or(contains('1')));

      await cubit.verifyPin('0000');
      expect(cubit.state.lockedUntil, isNotNull);
      expect(cubit.state.isLocked, isTrue);

      // A fresh cubit (app restart) starts in lockout too.
      final again = SecurityCubit(securityService: service);
      addTearDown(again.close);
      await again.init();
      expect(again.state.lockedUntil, isNotNull);
    });
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
