import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/features/backup/domain/services/backup_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  final Directory dir;
  _FakePathProvider(this.dir);

  @override
  Future<String?> getApplicationDocumentsPath() async => dir.path;

  @override
  Future<String?> getTemporaryPath() async => dir.path;
}

/// Writes a backup in the legacy V1 format (sha256/md5 + AES-CBC), the way
/// older app versions did, so restore can be tested against old payloads.
Future<String> _writeLegacyBackup({
  required Directory dir,
  required Map<String, dynamic> data,
  required int schemaVersion,
  required String password,
}) async {
  final payload = jsonEncode(data);
  final key = enc.Key(
    Uint8List.fromList(
      sha256.convert(utf8.encode('kifino:key:$password')).bytes,
    ),
  );
  final iv = enc.IV(
    Uint8List.fromList(md5.convert(utf8.encode('kifino:iv:$password')).bytes),
  );
  final cipher = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc))
      .encrypt(payload, iv: iv);

  final file = File('${dir.path}/legacy_v$schemaVersion.kfn');
  await file.writeAsString(
    jsonEncode({
      'metadata': {
        'schemaVersion': schemaVersion,
        'appVersion': '0.9.0',
        'exportedAt': DateTime(2026, 9, 1).toIso8601String(),
        'checksum': sha256.convert(utf8.encode(payload)).toString(),
        'entityCounts': {'products': 1},
      },
      'cipher': cipher.base64,
    }),
  );
  return file.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late BackupService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kifino_legacy_backup_');
    PathProviderPlatform.instance = _FakePathProvider(tempDir);
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('restores a v5 backup whose products lack conversionFactor and '
      'avgCostMinor (columns added in v6 and v9)', () async {
    // A product row exactly as a v5 app exported it.
    final legacyProduct = <String, dynamic>{
      'id': 'p-1',
      'name': 'کالای قدیمی',
      'sku': null,
      'barcode': null,
      'description': null,
      'unit': 'unit',
      'purchasePriceMinor': 1000,
      'sellingPriceMinor': 1500,
      'currency': 'TOMAN',
      'currentStock': 4.0,
      'lowStockThreshold': 1.0,
      'supplierId': null,
      'createdAt': 1,
      'updatedAt': 1,
      'deletedAt': null,
      'syncStatus': 0,
      'version': 1,
    };
    final path = await _writeLegacyBackup(
      dir: tempDir,
      data: {
        'products': [legacyProduct],
      },
      schemaVersion: 5,
      password: 'legacy-pass-123',
    );

    final result = await service.restoreEncryptedBackup(
      filePath: path,
      password: 'legacy-pass-123',
    );

    expect(
      result.isSuccess,
      isTrue,
      reason: result.failureOrNull?.message ?? '',
    );
    final products = await db.select(db.productsTable).get();
    expect(products, hasLength(1));
    expect(products.single.name, 'کالای قدیمی');
    expect(products.single.avgCostMinor, 0); // column default
    expect(products.single.conversionFactor, isPositive); // column default
    expect(products.single.secondaryUnit, isNull); // nullable → null
  });

  test('restores pre-v10 transactions without source columns as manual '
      'entries', () async {
    final path = await _writeLegacyBackup(
      dir: tempDir,
      data: {
        'accounts': [
          {
            'id': 'acc-1',
            'name': 'نقد',
            'type': 'cash',
            'currency': 'TOMAN',
            'initialBalanceMinor': 0,
            'currentBalanceMinor': -500,
            'cardNumberLastFour': null,
            'bankName': null,
            'colorHex': null,
            'iconName': null,
            'isArchived': false,
            'createdAt': 1,
            'updatedAt': 1,
            'deletedAt': null,
            'syncStatus': 0,
            'version': 1,
          },
        ],
        'transactions': [
          {
            'id': 'tx-1',
            'accountId': 'acc-1',
            'destinationAccountId': null,
            'categoryId': null,
            'type': 'expense',
            'amountMinor': 500,
            'currency': 'TOMAN',
            'transactionDate': 1,
            'description': 'قدیمی',
            'notes': null,
            'isBusiness': false,
            'locationLat': null,
            'locationLng': null,
            'locationName': null,
            'attachmentUri': null,
            'recurringRuleId': null,
            'createdAt': 1,
            'updatedAt': 1,
            'deletedAt': null,
            'syncStatus': 0,
            'version': 1,
          },
        ],
      },
      schemaVersion: 9,
      password: 'legacy-pass-123',
    );

    final result = await service.restoreEncryptedBackup(
      filePath: path,
      password: 'legacy-pass-123',
    );

    expect(
      result.isSuccess,
      isTrue,
      reason: result.failureOrNull?.message ?? '',
    );
    final tx = await db.select(db.transactionsTable).getSingle();
    expect(tx.sourceType, isNull);
    expect(tx.sourceId, isNull);
  });

  group('CSV amount formatting', () {
    test('keeps cents for two-decimal currencies', () {
      expect(BackupService.majorValueForCsv(1250, 'USD'), '12.50');
      expect(BackupService.majorValueForCsv(1205, 'EUR'), '12.05');
      expect(BackupService.majorValueForCsv(-99, 'GBP'), '-0.99');
      expect(BackupService.majorValueForCsv(100, 'USD'), '1.00');
    });

    test('leaves zero-decimal Iranian amounts as whole numbers', () {
      expect(BackupService.majorValueForCsv(350000, 'TOMAN'), '350000');
      expect(BackupService.majorValueForCsv(3500000, 'IRR'), '3500000');
    });

    test('export writes the decimal amount into the file', () async {
      await db
          .into(db.accountsTable)
          .insert(
            AccountsTableCompanion.insert(
              id: 'usd',
              name: 'Dollar',
              type: 'cash',
              currency: 'USD',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      await db
          .into(db.transactionsTable)
          .insert(
            TransactionsTableCompanion.insert(
              id: 'tx-usd',
              accountId: 'usd',
              type: 'expense',
              amountMinor: 1250,
              currency: 'USD',
              transactionDate: DateTime(2026, 5, 1).millisecondsSinceEpoch,
              description: 'coffee',
              createdAt: 1,
              updatedAt: 1,
            ),
          );

      final path = (await service.exportTransactionsCsv()).dataOrNull!;
      final csv = await File(path).readAsString();
      expect(csv, contains(',12.50,'));
      expect(csv, isNot(contains(',12,')));
    });
  });
}
