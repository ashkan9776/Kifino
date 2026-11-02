import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/features/security/domain/services/security_service.dart';
import 'package:kifino/features/security/presentation/cubit/security_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P0-8: Android Release Configuration & Security', () {
    test('build.gradle.kts has correct production applicationId and release signing', () {
      final file = File('android/app/build.gradle.kts');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('applicationId = "ir.kifino.app"'));
      expect(content, contains('namespace = "ir.kifino.app"'));
      expect(content, contains('signingConfigs.getByName("release")'));
      expect(content, contains('key.properties'));
    });

    test('AndroidManifest.xml disables allowBackup and specifies extraction and backup rules', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);
      final content = manifestFile.readAsStringSync();

      expect(content, contains('android:allowBackup="false"'));
      expect(
        content,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(
        content,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
    });

    test('data_extraction_rules.xml and backup_rules.xml exclude database and sharedpref', () {
      final dataRules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );
      final backupRules = File('android/app/src/main/res/xml/backup_rules.xml');

      expect(dataRules.existsSync(), isTrue);
      expect(backupRules.existsSync(), isTrue);

      final dataContent = dataRules.readAsStringSync();
      final backupContent = backupRules.readAsStringSync();

      expect(dataContent, contains('exclude domain="database"'));
      expect(dataContent, contains('exclude domain="sharedpref"'));
      expect(backupContent, contains('exclude domain="database"'));
      expect(backupContent, contains('exclude domain="sharedpref"'));
    });

    test(
      'MainActivity.kt resides in ir.kifino.app and configures FLAG_SECURE',
      () {
        final mainActivity = File(
          'android/app/src/main/kotlin/ir/kifino/app/MainActivity.kt',
        );
        expect(mainActivity.existsSync(), isTrue);
        final content = mainActivity.readAsStringSync();

        expect(content, contains('package ir.kifino.app'));
        expect(content, contains('FLAG_SECURE'));
        expect(content, contains('ir.kifino.app/security'));
      },
    );

    test(
      'SecurityService and SecurityCubit manage screenshot protection setting',
      () async {
        FlutterSecureStorage.setMockInitialValues({});
        const storage = FlutterSecureStorage();
        final service = SecurityService(secureStorage: storage);
        final cubit = SecurityCubit(securityService: service);

        expect(await service.isScreenshotProtectionEnabled(), isTrue);

        await cubit.init();
        expect(cubit.state.isScreenshotProtected, isTrue);

        await cubit.toggleScreenshotProtection(false);
        expect(cubit.state.isScreenshotProtected, isFalse);
        expect(await service.isScreenshotProtectionEnabled(), isFalse);

        await cubit.toggleScreenshotProtection(true);
        expect(cubit.state.isScreenshotProtected, isTrue);
        expect(await service.isScreenshotProtectionEnabled(), isTrue);
      },
    );
  });
}
