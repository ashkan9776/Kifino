import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/constants/app_constants.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/errors/failures.dart';
import 'package:kifino/features/backup/domain/services/backup_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pointycastle/export.dart' as pc;

class _MockPathProvider extends PathProviderPlatform {
  final Directory tempDir;
  _MockPathProvider(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;
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

      // Header version 3 (metadata authenticated via GCM AAD)
      expect(
        content1['formatVersion'],
        equals(BackupService.currentFormatVersion),
      );
      expect(
        content2['formatVersion'],
        equals(BackupService.currentFormatVersion),
      );
      expect(content1['formatVersion'], equals(3));
      expect(content1['magic'], equals('KIFINO'));
      expect(content2['magic'], equals('KIFINO'));
      expect(
        content1['metadata']['appVersion'],
        equals(AppConstants.appVersion),
      );

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

        expect(
          restoreRes.isSuccess,
          isTrue,
          reason: restoreRes.failureOrNull?.message ?? '',
        );
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

  group('BackupService v3 AAD, KDF bounds & CSV injection hardening', () {
    test('v3 backup round-trips and fails with SecurityFailure if outer metadata is tampered', () async {
      final createRes = await service.createEncryptedBackup(
        password: 'StrongPassword123!',
        iterations: 1000,
      );
      expect(createRes.isSuccess, isTrue);
      final filePath = createRes.dataOrNull!;

      final originalRaw = await File(filePath).readAsString();
      final decoded = jsonDecode(originalRaw) as Map<String, dynamic>;
      expect(decoded['formatVersion'], equals(3));

      // 1. Tamper exportedAt
      final tamperedDate = jsonDecode(originalRaw) as Map<String, dynamic>;
      (tamperedDate['metadata'] as Map<String, dynamic>)['exportedAt'] =
          DateTime(2020, 1, 1).toIso8601String();
      await File(filePath).writeAsString(jsonEncode(tamperedDate));
      final resDate = await service.restoreEncryptedBackup(
        filePath: filePath,
        password: 'StrongPassword123!',
      );
      expect(resDate.isFailure, isTrue);
      expect(resDate.failureOrNull, isA<SecurityFailure>());

      // 2. Tamper entityCounts
      final tamperedCounts = jsonDecode(originalRaw) as Map<String, dynamic>;
      ((tamperedCounts['metadata'] as Map<String, dynamic>)['entityCounts']
              as Map<String, dynamic>)['accounts'] =
          999;
      await File(filePath).writeAsString(jsonEncode(tamperedCounts));
      final resCounts = await service.restoreEncryptedBackup(
        filePath: filePath,
        password: 'StrongPassword123!',
      );
      expect(resCounts.isFailure, isTrue);
      expect(resCounts.failureOrNull, isA<SecurityFailure>());

      // 3. Downgrade formatVersion from 3 to 2 (attempts to bypass AAD check)
      final downgraded = jsonDecode(originalRaw) as Map<String, dynamic>;
      downgraded['formatVersion'] = 2;
      await File(filePath).writeAsString(jsonEncode(downgraded));
      final resDowngrade = await service.restoreEncryptedBackup(
        filePath: filePath,
        password: 'StrongPassword123!',
      );
      expect(resDowngrade.isFailure, isTrue);
      expect(resDowngrade.failureOrNull, isA<SecurityFailure>());

      // 4. Restore valid original file succeeds
      await File(filePath).writeAsString(originalRaw);
      await db.delete(db.accountsTable).go();
      final resValid = await service.restoreEncryptedBackup(
        filePath: filePath,
        password: 'StrongPassword123!',
      );
      expect(
        resValid.isSuccess,
        isTrue,
        reason: resValid.failureOrNull?.message ?? '',
      );
      expect(resValid.dataOrNull?.isLegacyFormat, isFalse);
      final restoredAccounts = await db.select(db.accountsTable).get();
      expect(restoredAccounts, hasLength(1));
      expect(restoredAccounts.single.name, equals('حساب جاری'));
    });

    test('maintains backward-compatible restore for existing formatVersion 2 backups', () async {
      final accounts = await db.select(db.accountsTable).get();
      final payload = jsonEncode({
        'accounts': accounts.map((a) => a.toJson()).toList(),
      });
      final checksum = sha256.convert(utf8.encode(payload)).toString();
      final metadata = BackupMetadata(
        schemaVersion: AppConstants.databaseVersion,
        appVersion: '1.0.0',
        exportedAt: DateTime.now(),
        checksum: checksum,
        entityCounts: {'accounts': accounts.length},
      );

      final rng = Random.secure();
      final salt = Uint8List.fromList(
        List.generate(16, (_) => rng.nextInt(256)),
      );
      final nonce = Uint8List.fromList(
        List.generate(12, (_) => rng.nextInt(256)),
      );
      final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
        ..init(pc.Pbkdf2Parameters(salt, 1000, 32));
      final key = derivator.process(
        Uint8List.fromList(utf8.encode('V2CompatPass!')),
      );
      final cipher = pc.GCMBlockCipher(pc.AESEngine())
        ..init(
          true,
          pc.AEADParameters(pc.KeyParameter(key), 128, nonce, Uint8List(0)),
        );
      final cipherBytes = cipher.process(
        Uint8List.fromList(utf8.encode(payload)),
      );

      final v2Path = p.join(tempDir.path, 'legacy_v2.kfn');
      await File(v2Path).writeAsString(
        jsonEncode({
          'magic': 'KIFINO',
          'formatVersion': 2,
          'kdf': {
            'algorithm': 'PBKDF2-HMAC-SHA256',
            'iterations': 1000,
            'salt': base64Encode(salt),
          },
          'nonce': base64Encode(nonce),
          'metadata': metadata.toJson(),
          'cipher': base64Encode(cipherBytes),
        }),
      );

      await db.delete(db.accountsTable).go();
      final restoreRes = await service.restoreEncryptedBackup(
        filePath: v2Path,
        password: 'V2CompatPass!',
      );
      expect(
        restoreRes.isSuccess,
        isTrue,
        reason: restoreRes.failureOrNull?.message ?? '',
      );
      expect(restoreRes.dataOrNull?.isLegacyFormat, isFalse);
      expect(await db.select(db.accountsTable).get(), hasLength(1));
    });

    test('rejects malicious or out-of-range KDF iteration counts immediately with SecurityFailure', () async {
      final createRes = await service.createEncryptedBackup(
        password: 'StrongPassword123!',
        iterations: 1000,
      );
      final filePath = createRes.dataOrNull!;
      final baseRaw = await File(filePath).readAsString();

      for (final badIterations in <Object?>[
        0,
        -1,
        999,
        2000001,
        999999999,
        1000.5,
        '1000',
        null,
      ]) {
        final modified = jsonDecode(baseRaw) as Map<String, dynamic>;
        (modified['kdf'] as Map<String, dynamic>)['iterations'] = badIterations;
        await File(filePath).writeAsString(jsonEncode(modified));

        final res = await service.restoreEncryptedBackup(
          filePath: filePath,
          password: 'StrongPassword123!',
        );
        expect(
          res.isFailure,
          isTrue,
          reason: 'Expected failure for iterations=$badIterations',
        );
        expect(
          res.failureOrNull,
          isA<SecurityFailure>(),
          reason: 'Expected SecurityFailure for iterations=$badIterations',
        );
      }
    });

    test('CSV export neutralizes formula injection in text cells while preserving negative numeric amounts', () async {
      final now = DateTime(2026, 6, 15).millisecondsSinceEpoch;
      await db
          .into(db.accountsTable)
          .insert(
            AccountsTableCompanion.insert(
              id: 'acc-inj',
              name: '+1+1 Account',
              type: 'bankCard',
              currency: 'USD',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.categoriesTable)
          .insert(
            CategoriesTableCompanion.insert(
              id: 'cat-inj',
              name: '@SUM(A1:A2)',
              type: 'expense',
              iconCodePoint: 1,
              colorHex: '#000000',
              createdAt: now,
              updatedAt: now,
            ),
          );

      final payloads = [
        ('tx-eq', '=HYPERLINK("http://evil.example","click")', -1250),
        ('tx-minus', '-2+3', 500),
        ('tx-ws', '   =CMD|"/C calc"!A0', 250),
        ('tx-tab', '\t=1+1', 100),
        ('tx-cr', '\r=1+1', 100),
      ];
      for (var i = 0; i < payloads.length; i++) {
        final (id, desc, minor) = payloads[i];
        await db
            .into(db.transactionsTable)
            .insert(
              TransactionsTableCompanion.insert(
                id: id,
                accountId: 'acc-inj',
                categoryId: const Value('cat-inj'),
                type: 'expense',
                amountMinor: minor,
                currency: 'USD',
                transactionDate: now + i,
                description: desc,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      final exportRes = await service.exportTransactionsCsv();
      expect(exportRes.isSuccess, isTrue);
      final csv = await File(exportRes.dataOrNull!).readAsString();

      // Text cells with dangerous prefixes must start with single quote inside quotes
      expect(
        csv,
        contains('"\'=HYPERLINK(""http://evil.example"",""click"")"'),
      );
      expect(csv, contains('"\'+1+1 Account"'));
      expect(csv, contains('"\'@SUM(A1:A2)"'));
      expect(csv, contains('"\'-2+3"'));
      expect(csv, contains('"\'   =CMD|""/C calc""!A0"'));
      expect(csv, contains('"\'\t=1+1"'));
      expect(csv, contains('"\'\r=1+1"'));

      // Negative numeric amount cell remains unquoted numeric (not `' -12.50`)
      expect(csv, contains(',-12.50,"USD"'));
      expect(csv, isNot(contains("'-12.50")));
    });
  });
}
