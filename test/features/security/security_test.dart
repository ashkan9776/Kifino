import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:kifino/features/security/domain/services/security_service.dart';
import 'package:kifino/features/security/presentation/cubit/security_cubit.dart';
import 'package:kifino/features/security/presentation/cubit/security_state.dart';

class InMemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

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
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
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
  }) async {
    _storage.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.clear();
  }
}

class FakeLocalAuthentication extends Fake implements LocalAuthentication {
  bool canCheck = true;
  bool deviceSupported = true;
  bool authResult = true;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    return authResult;
  }
}

void main() {
  late InMemorySecureStorage storage;
  late FakeLocalAuthentication localAuth;
  late SecurityService service;

  setUp(() {
    storage = InMemorySecureStorage();
    localAuth = FakeLocalAuthentication();
    service = SecurityService(secureStorage: storage, localAuth: localAuth);
  });

  group('SecurityService Tests', () {
    test('isPinSet returns false when no PIN is stored', () async {
      expect(await service.isPinSet(), isFalse);
    });

    test('savePin hashes PIN with unique salt and stores securely', () async {
      await service.savePin('1234');
      expect(await service.isPinSet(), isTrue);

      final isCorrect = await service.verifyPin('1234');
      expect(isCorrect, isTrue);

      final isWrong = await service.verifyPin('9999');
      expect(isWrong, isFalse);
    });

    test('removePin deletes salt, hash, and biometric preference', () async {
      await service.savePin('4321');
      await service.setBiometricEnabled(true);
      expect(await service.isPinSet(), isTrue);
      expect(await service.isBiometricEnabled(), isTrue);

      await service.removePin();
      expect(await service.isPinSet(), isFalse);
    });

    test('biometric settings and authentication', () async {
      expect(await service.isBiometricEnabled(), isFalse);
      await service.setBiometricEnabled(true);
      expect(await service.isBiometricEnabled(), isTrue);

      expect(await service.canCheckBiometrics(), isTrue);
      expect(await service.authenticateBiometric(), isTrue);

      localAuth.authResult = false;
      expect(await service.authenticateBiometric(), isFalse);
    });
  });

  group('SecurityCubit Tests', () {
    blocTest<SecurityCubit, SecurityState>(
      'init locks app when PIN is set',
      setUp: () async {
        await service.savePin('2580');
      },
      build: () => SecurityCubit(securityService: service),
      act: (cubit) => cubit.init(),
      expect: () => [predicate<SecurityState>((s) => s.isPinSet && s.isLocked)],
    );

    blocTest<SecurityCubit, SecurityState>(
      'verifyPin unlocks app with correct PIN',
      setUp: () async {
        await service.savePin('1111');
      },
      build: () => SecurityCubit(securityService: service),
      act: (cubit) async {
        await cubit.init();
        await cubit.verifyPin('1111');
      },
      expect: () => [
        predicate<SecurityState>((s) => s.isPinSet && s.isLocked),
        predicate<SecurityState>((s) => !s.isLocked && s.errorMessage == null),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'verifyPin sets error message with wrong PIN',
      setUp: () async {
        await service.savePin('1111');
      },
      build: () => SecurityCubit(securityService: service),
      act: (cubit) async {
        await cubit.init();
        await cubit.verifyPin('2222');
      },
      expect: () => [
        predicate<SecurityState>((s) => s.isPinSet && s.isLocked),
        predicate<SecurityState>((s) => s.isLocked && s.errorMessage != null),
      ],
    );

    blocTest<SecurityCubit, SecurityState>(
      'savePin sets isPinSet true and unlocks',
      build: () => SecurityCubit(securityService: service),
      act: (cubit) => cubit.savePin('9876'),
      expect: () => [const SecurityState(isPinSet: true, isLocked: false)],
    );

    blocTest<SecurityCubit, SecurityState>(
      'lockApp and unlockApp update isLocked flag',
      setUp: () async {
        await service.savePin('0000');
      },
      build: () => SecurityCubit(securityService: service),
      act: (cubit) async {
        await cubit.init();
        await cubit.verifyPin('0000');
        cubit.lockApp();
        cubit.unlockApp();
      },
      expect: () => [
        predicate<SecurityState>((s) => s.isPinSet && s.isLocked),
        predicate<SecurityState>((s) => s.isPinSet && !s.isLocked),
        predicate<SecurityState>((s) => s.isPinSet && s.isLocked),
        predicate<SecurityState>((s) => s.isPinSet && !s.isLocked),
      ],
    );
  });
}
