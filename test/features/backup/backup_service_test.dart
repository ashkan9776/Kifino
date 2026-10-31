import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:kifino/core/constants/app_constants.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/features/backup/domain/services/backup_service.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  final Directory tempDir;
  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AppDatabase db;
  late BackupService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kifino_backup_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
    db = AppDatabase(NativeDatabase.memory());
    service = BackupService(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BackupService Tests', () {
    test('creates encrypted backup file with metadata and cipher payload', () async {
      // Seed account
      await db.into(db.accountsTable).insert(
            AccountsTableCompanion.insert(
              id: 'acc-1',
              name: 'حساب جاری ملت',
              type: 'bank',
              currency: 'IRR',
              initialBalanceMinor: const Value(50000000),
              currentBalanceMinor: const Value(50000000),
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      // Seed transaction
      await db.into(db.transactionsTable).insert(
            TransactionsTableCompanion.insert(
              id: 'tx-1',
              accountId: 'acc-1',
              amountMinor: 2500000,
              currency: 'IRR',
              type: 'expense',
              transactionDate: DateTime.now().millisecondsSinceEpoch,
              description: 'خرید سوپرمارکت',
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final result = await service.createEncryptedBackup(password: 'MyStrongPass!123');
      expect(result.isSuccess, isTrue);

      final filePath = result.dataOrNull!;
      final file = File(filePath);
      expect(await file.exists(), isTrue);

      // Verify backup structure
      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);
      expect(json.containsKey('metadata'), isTrue);
      expect(json.containsKey('cipher'), isTrue);

      final metadata = BackupMetadata.fromJson(json['metadata']);
      expect(metadata.schemaVersion, equals(AppConstants.databaseVersion));
      expect(metadata.entityCounts['accounts'], equals(1));
      expect(metadata.entityCounts['transactions'], equals(1));
    });

    test('restores encrypted backup to a fresh database', () async {
      // 1. Seed original DB
      await db.into(db.accountsTable).insert(
            AccountsTableCompanion.insert(
              id: 'acc-original',
              name: 'کیف پول نقدی',
              type: 'cash',
              currency: 'IRR',
              initialBalanceMinor: const Value(12000000),
              currentBalanceMinor: const Value(12000000),
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final backupResult = await service.createEncryptedBackup(password: 'PassRestore2026');
      expect(backupResult.isSuccess, isTrue);
      final filePath = backupResult.dataOrNull!;

      // 2. Open brand new database
      final freshDb = AppDatabase(NativeDatabase.memory());
      final freshService = BackupService(freshDb);

      final restoreResult = await freshService.restoreEncryptedBackup(
        filePath: filePath,
        password: 'PassRestore2026',
      );

      expect(restoreResult.isSuccess, isTrue);

      // Verify entity exists in fresh database
      final accounts = await freshDb.select(freshDb.accountsTable).get();
      expect(accounts.length, equals(1));
      expect(accounts.first.id, equals('acc-original'));
      expect(accounts.first.name, equals('کیف پول نقدی'));
      expect(accounts.first.currentBalanceMinor, equals(12000000));

      await freshDb.close();
    });

    test('fails restore when wrong password is provided', () async {
      await db.into(db.accountsTable).insert(
            AccountsTableCompanion.insert(
              id: 'acc-sec',
              name: 'سپرده',
              type: 'savings',
              currency: 'IRR',
              initialBalanceMinor: const Value(99000000),
              currentBalanceMinor: const Value(99000000),
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final backupResult = await service.createEncryptedBackup(password: 'CorrectPass1');
      final filePath = backupResult.dataOrNull!;

      final restoreResult = await service.restoreEncryptedBackup(
        filePath: filePath,
        password: 'IncorrectPassword',
      );

      expect(restoreResult.isFailure, isTrue);
      expect(restoreResult.failureOrNull?.message, contains('اشتباه'));
    });

    test('fails restore when file does not exist', () async {
      final restoreResult = await service.restoreEncryptedBackup(
        filePath: '/invalid/path/nonexistent.kfn',
        password: 'AnyPassword',
      );

      expect(restoreResult.isFailure, isTrue);
      expect(restoreResult.failureOrNull?.message, contains('یافت نشد'));
    });

    test('exports transactions to Excel-compatible CSV with BOM and headers', () async {
      await db.into(db.accountsTable).insert(
            AccountsTableCompanion.insert(
              id: 'acc-1',
              name: 'کیف پول',
              type: 'cashWallet',
              currency: 'TOMAN',
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      await db.into(db.transactionsTable).insert(
            TransactionsTableCompanion.insert(
              id: 'tx-csv-1',
              accountId: 'acc-1',
              type: 'expense',
              amountMinor: 350000,
              currency: 'TOMAN',
              transactionDate: DateTime(2026, 9, 30).millisecondsSinceEpoch,
              description: 'خرید ناهار',
              createdAt: DateTime.now().millisecondsSinceEpoch,
              updatedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );

      final result = await service.exportTransactionsCsv();
      expect(result.isSuccess, isTrue);

      final file = File(result.dataOrNull!);
      expect(await file.exists(), isTrue);

      final bytes = await file.readAsBytes();
      // UTF-8 BOM (EF BB BF) must lead the file so Excel renders Persian.
      expect(bytes.take(3).toList(), equals([239, 187, 191]));

      final content = await file.readAsString();
      expect(content, contains('تاریخ شمسی,تاریخ میلادی,نوع,شرح,حساب,دسته,مبلغ,ارز'));
      expect(content, contains('خرید ناهار'));
      expect(content, contains('هزینه'));
      expect(content, contains('کیف پول'));
      expect(content, contains(',350000,"TOMAN"'));
    });
  });
}
