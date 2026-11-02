import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/constants/app_constants.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/features/backup/domain/services/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _MockPathProvider extends PathProviderPlatform {
  final Directory tempDir;
  _MockPathProvider(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late BackupService service;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_p07_test_');
    PathProviderPlatform.instance = _MockPathProvider(tempDir);
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db);

    // Seed sample account
    await db
        .into(db.accountsTable)
        .insert(
          AccountsTableCompanion.insert(
            id: 'acc-1',
            name: 'حساب جاری',
            type: 'checking',
            currentBalanceMinor: const Value(5000000),
            currency: 'TOMAN',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('P0-7: Backup Encryption Modernization', () {
    test('Rejects passwords shorter than 8 characters', () async {
      final result = await service.createEncryptedBackup(password: 'short');
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('۸'));
    });

    test('Two backups with identical password produce different ciphertexts (random salt & nonce)', () async {
      final res1 = await service.createEncryptedBackup(
        password: 'SecurePass123!',
        iterations: 1000,
      );
      final res2 = await service.createEncryptedBackup(
        password: 'SecurePass123!',
        iterations: 1000,
      );

      expect(res1.isSuccess, isTrue);
      expect(res2.isSuccess, isTrue);

      final path1 = res1.dataOrNull!;
      final path2 = res2.dataOrNull!;

      final content1 =
          jsonDecode(await File(path1).readAsString()) as Map<String, dynamic>;
      final content2 =
          jsonDecode(await File(path2).readAsString()) as Map<String, dynamic>;

      // Header version 2
      expect(content1['formatVersion'], equals(2));
      expect(content2['formatVersion'], equals(2));
      expect(content1['magic'], equals('KIFINO'));
      expect(content2['magic'], equals('KIFINO'));

      // Different salt
      final salt1 = content1['kdf']['salt'] as String;
      final salt2 = content2['kdf']['salt'] as String;
      expect(salt1, isNot(equals(salt2)));

      // Different nonce
      final nonce1 = content1['nonce'] as String;
      final nonce2 = content2['nonce'] as String;
      expect(nonce1, isNot(equals(nonce2)));

      // Different ciphertext
      final cipher1 = content1['cipher'] as String;
      final cipher2 = content2['cipher'] as String;
      expect(cipher1, isNot(equals(cipher2)));
    });

    test(
      'Tampering a single byte of ciphertext triggers SecurityFailure',
      () async {
        final createRes = await service.createEncryptedBackup(
          password: 'StrongPassword123#',
          iterations: 1000,
        );
        expect(createRes.isSuccess, isTrue);
        final filePath = createRes.dataOrNull!;

        final content = jsonDecode(
          await File(filePath).readAsString(),
        ) as Map<String, dynamic>;
        final cipherBytes = base64Decode(content['cipher'] as String);

        // Flip one bit
        cipherBytes[0] ^= 0x01;
        content['cipher'] = base64Encode(cipherBytes);
        await File(filePath).writeAsString(jsonEncode(content));

        final restoreRes = await service.restoreEncryptedBackup(
          filePath: filePath,
          password: 'StrongPassword123#',
        );

        expect(restoreRes.isFailure, isTrue);
        expect(restoreRes.failureOrNull?.message, contains('دستکاری'));
      },
    );

    test('Wrong password fails authentication with SecurityFailure', () async {
      final createRes = await service.createEncryptedBackup(
        password: 'CorrectPassword123!',
        iterations: 1000,
      );
      final filePath = createRes.dataOrNull!;

      final restoreRes = await service.restoreEncryptedBackup(
        filePath: filePath,
        password: 'WrongPassword456?',
      );

      expect(restoreRes.isFailure, isTrue);
      expect(restoreRes.failureOrNull?.message, contains('اشتباه'));
    });

    test(
      'Can restore legacy V1 backup and marks isLegacyFormat == true',
      () async {
        // Create a legacy V1 backup package manually
        final accounts = await db.select(db.accountsTable).get();
        final dataMap = {'accounts': accounts.map((a) => a.toJson()).toList()};
        final jsonPayload = jsonEncode(dataMap);
        final checksum = sha256.convert(utf8.encode(jsonPayload)).toString();

        final metadata = BackupMetadata(
          schemaVersion: AppConstants.databaseVersion,
          appVersion: '1.0.0',
          exportedAt: DateTime.now(),
          checksum: checksum,
          entityCounts: {'accounts': accounts.length},
        );

        final legacyKeyBytes = sha256
            .convert(utf8.encode('kifino:key:LegacyPass123'))
            .bytes;
        final legacyIvBytes = md5
            .convert(utf8.encode('kifino:iv:LegacyPass123'))
            .bytes;
        final encrypter = enc.Encrypter(
          enc.AES(
            enc.Key(Uint8List.fromList(legacyKeyBytes)),
            mode: enc.AESMode.cbc,
          ),
        );
        final encrypted = encrypter.encrypt(
          jsonPayload,
          iv: enc.IV(Uint8List.fromList(legacyIvBytes)),
        );

        final legacyPackage = jsonEncode({
          'metadata': metadata.toJson(),
          'cipher': encrypted.base64,
        });

        final legacyFilePath = p.join(tempDir.path, 'legacy_backup.kfn');
        await File(legacyFilePath).writeAsString(legacyPackage);

        // Now clear the accounts in db
        await db.delete(db.accountsTable).go();
        expect((await db.select(db.accountsTable).get()).length, equals(0));

        // Restore legacy backup
        final restoreRes = await service.restoreEncryptedBackup(
          filePath: legacyFilePath,
          password: 'LegacyPass123',
        );

        expect(restoreRes.isSuccess, isTrue);
        expect(restoreRes.dataOrNull?.isLegacyFormat, isTrue);

        final restoredAccounts = await db.select(db.accountsTable).get();
        expect(restoredAccounts.length, equals(1));
        expect(restoredAccounts.first.name, equals('حساب جاری'));
      },
    );

    test('Password strength evaluation', () {
      expect(BackupService.evaluatePasswordStrength('short'), equals(0));
      expect(BackupService.evaluatePasswordStrength('12345678'), equals(1));
      expect(BackupService.evaluatePasswordStrength('abcdefgh1'), equals(2));
      expect(BackupService.evaluatePasswordStrength('Password123'), equals(2));
      expect(
        BackupService.evaluatePasswordStrength('LongPassword123'),
        equals(3),
      );
      expect(
        BackupService.evaluatePasswordStrength('StrongPass123!@#'),
        equals(4),
      );
    });
  });
}
