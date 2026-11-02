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
    test(
      'creates encrypted backup file with metadata and cipher payload',
      () async {
        // Seed account
        await db
            .into(db.accountsTable)
            .insert(
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
        await db
            .into(db.transactionsTable)
            .insert(
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

        final result = await service.createEncryptedBackup(
          password: 'MyStrongPass!123',
        );
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
      },
    );

    test('restores encrypted backup to a fresh database', () async {
      // 1. Seed original DB
      await db
          .into(db.accountsTable)
          .insert(
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

      final backupResult = await service.createEncryptedBackup(
        password: 'PassRestore2026',
      );
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
      await db
          .into(db.accountsTable)
          .insert(
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

      final backupResult = await service.createEncryptedBackup(
        password: 'CorrectPass1',
      );
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

    test(
      'exports transactions to Excel-compatible CSV with BOM and headers',
      () async {
        await db
            .into(db.accountsTable)
            .insert(
              AccountsTableCompanion.insert(
                id: 'acc-1',
                name: 'کیف پول',
                type: 'cashWallet',
                currency: 'TOMAN',
                createdAt: DateTime.now().millisecondsSinceEpoch,
                updatedAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );

        await db
            .into(db.transactionsTable)
            .insert(
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
        expect(
          content,
          contains('تاریخ شمسی,تاریخ میلادی,نوع,شرح,حساب,دسته,مبلغ,ارز'),
        );
        expect(content, contains('خرید ناهار'));
        expect(content, contains('هزینه'));
        expect(content, contains('کیف پول'));
        expect(content, contains(',350000,"TOMAN"'));
      },
    );

    test(
      'P0-1: round-trip backup and restore covers all 28 tables and categories',
      () async {
        // Seed all 28 tables
        await db
            .into(db.accountsTable)
            .insert(
              AccountsTableCompanion.insert(
                id: 'acc-1',
                name: 'بانک',
                type: 'bankCard',
                currency: 'TOMAN',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.categoriesTable)
            .insert(
              CategoriesTableCompanion.insert(
                id: 'cat-1',
                name: 'خوراک',
                type: 'expense',
                iconCodePoint: 1,
                colorHex: '#fff',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.tagsTable)
            .insert(
              TagsTableCompanion.insert(
                id: 'tag-1',
                name: 'ضروری',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.transactionsTable)
            .insert(
              TransactionsTableCompanion.insert(
                id: 'tx-1',
                accountId: 'acc-1',
                categoryId: const Value('cat-1'),
                amountMinor: 1000,
                currency: 'TOMAN',
                type: 'expense',
                transactionDate: 100,
                description: 'نان',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.transactionTagsTable)
            .insert(
              TransactionTagsTableCompanion.insert(
                transactionId: 'tx-1',
                tagId: 'tag-1',
              ),
            );
        await db
            .into(db.budgetsTable)
            .insert(
              BudgetsTableCompanion.insert(
                id: 'b-1',
                name: 'بودجه',
                amountLimitMinor: 10000,
                currency: 'TOMAN',
                periodType: 'monthly',
                startDate: 1,
                endDate: 2,
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.budgetCategoriesTable)
            .insert(
              BudgetCategoriesTableCompanion.insert(
                budgetId: 'b-1',
                categoryId: 'cat-1',
              ),
            );
        await db
            .into(db.debtsReceivablesTable)
            .insert(
              DebtsReceivablesTableCompanion.insert(
                id: 'd-1',
                contactName: 'علی',
                type: 'debt',
                totalAmountMinor: 5000,
                currency: 'TOMAN',
                status: 'active',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.installmentsTable)
            .insert(
              InstallmentsTableCompanion.insert(
                id: 'inst-1',
                title: 'قسط',
                accountId: 'acc-1',
                totalAmountMinor: 12000,
                currency: 'TOMAN',
                numberOfInstallments: 12,
                installmentAmountMinor: 1000,
                startDate: 1,
                nextDueDate: 10,
                status: 'ongoing',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.installmentPaymentsTable)
            .insert(
              InstallmentPaymentsTableCompanion.insert(
                id: 'ip-1',
                installmentId: 'inst-1',
                amountMinor: 1000,
                installmentIndex: 1,
                paidAt: 1,
                createdAt: 1,
              ),
            );
        await db
            .into(db.checksTable)
            .insert(
              ChecksTableCompanion.insert(
                id: 'chk-1',
                checkNumber: '1234',
                bankName: 'ملی',
                type: 'issued',
                amountMinor: 2000,
                currency: 'TOMAN',
                partyName: 'رضا',
                dueDate: 100,
                status: 'pending',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.assetsTable)
            .insert(
              AssetsTableCompanion.insert(
                id: 'ast-1',
                name: 'طلا',
                category: 'gold',
                quantity: 1.5,
                unit: 'گرم',
                costBasisMinor: 5000,
                currentValueMinor: 6000,
                currency: 'TOMAN',
                purchaseDate: 1,
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.financialGoalsTable)
            .insert(
              FinancialGoalsTableCompanion.insert(
                id: 'g-1',
                name: 'خودرو',
                targetAmountMinor: 100000,
                currentAmountMinor: const Value(20000),
                currency: 'TOMAN',
                status: 'active',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.businessContactsTable)
            .insert(
              BusinessContactsTableCompanion.insert(
                id: 'bc-1',
                name: 'شرکت آریا',
                type: 'customer',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.productsTable)
            .insert(
              ProductsTableCompanion.insert(
                id: 'prod-1',
                name: 'کالا ۱',
                sellingPriceMinor: 2000,
                currency: 'TOMAN',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.inventoryLogsTable)
            .insert(
              InventoryLogsTableCompanion.insert(
                id: 'inv-log-1',
                productId: 'prod-1',
                changeQuantity: 10,
                movementType: 'purchase',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.invoicesTable)
            .insert(
              InvoicesTableCompanion.insert(
                id: 'inv-1',
                invoiceNumber: 'INV-001',
                contactId: 'bc-1',
                type: 'sale',
                status: 'draft',
                issueDate: 1,
                dueDate: 2,
                subtotalMinor: 2000,
                totalMinor: 2000,
                currency: 'TOMAN',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.invoiceItemsTable)
            .insert(
              InvoiceItemsTableCompanion.insert(
                id: 'inv-item-1',
                invoiceId: 'inv-1',
                description: 'ردیف ۱',
                quantity: 1,
                unitPriceMinor: 2000,
                totalMinor: 2000,
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'account',
                entityId: 'acc-1',
                operation: 'insert',
                payloadJson: '{}',
                idempotencyKey: 'idemp-1',
                queuedAt: 1,
              ),
            );
        await db
            .into(db.notificationsTable)
            .insert(
              NotificationsTableCompanion.insert(
                id: 'notif-1',
                title: 'یادآور',
                body: 'متن',
                type: 'check',
                scheduledFor: 1,
                createdAt: 1,
              ),
            );
        await db
            .into(db.fiscalYearsTable)
            .insert(
              FiscalYearsTableCompanion.insert(
                id: 'fy-1',
                title: '۱۴۰۳',
                yearNumber: 1403,
                startDate: 1,
                endDate: 2,
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.accountingSubjectsTable)
            .insert(
              AccountingSubjectsTableCompanion.insert(
                id: 'sub-1',
                code: '010',
                name: 'بانک',
                type: 'both',
                level: 'kol',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.accountingDocumentsTable)
            .insert(
              AccountingDocumentsTableCompanion.insert(
                id: 'doc-1',
                number: 1,
                date: 1,
                title: 'سند افتتاحیه',
                status: 'approved',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.accountingTransactionsTable)
            .insert(
              AccountingTransactionsTableCompanion.insert(
                id: 'atx-1',
                documentId: 'doc-1',
                subjectId: 'sub-1',
                description: 'شرح ردیف',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.accountingAuditLogsTable)
            .insert(
              AccountingAuditLogsTableCompanion.insert(
                id: 'log-1',
                entityType: 'document',
                entityId: 'doc-1',
                action: 'create',
                performedAt: 1,
                createdAt: 1,
              ),
            );
        await db
            .into(db.accountingDetailLedgersTable)
            .insert(
              AccountingDetailLedgersTableCompanion.insert(
                id: 'adl-1',
                title: 'پروژه‌ها',
                code: 'project',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.accountingDetailValuesTable)
            .insert(
              AccountingDetailValuesTableCompanion.insert(
                id: 'adv-1',
                ledgerId: 'adl-1',
                title: 'پروژه آلفا',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        await db
            .into(db.accountingDocumentDetailLinksTable)
            .insert(
              AccountingDocumentDetailLinksTableCompanion.insert(
                id: 'link-1',
                documentId: 'doc-1',
                ledgerId: 'adl-1',
                valueId: 'adv-1',
                createdAt: 1,
              ),
            );

        final backupResult = await service.createEncryptedBackup(
          password: 'TestSecret123',
        );
        expect(backupResult.isSuccess, isTrue);

        final freshDb = AppDatabase(NativeDatabase.memory());
        final freshService = BackupService(freshDb);

        final restoreResult = await freshService.restoreEncryptedBackup(
          filePath: backupResult.dataOrNull!,
          password: 'TestSecret123',
        );
        expect(restoreResult.isSuccess, isTrue);

        // Verify all 28 tables have been restored
        expect(
          (await freshDb.select(freshDb.accountsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.categoriesTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.tagsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.transactionsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.transactionTagsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.budgetsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.budgetCategoriesTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.debtsReceivablesTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.installmentsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.installmentPaymentsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.checksTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.assetsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.financialGoalsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.businessContactsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.productsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.inventoryLogsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.invoicesTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.invoiceItemsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.syncQueueTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.notificationsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.fiscalYearsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.accountingSubjectsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.accountingDocumentsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.accountingTransactionsTable).get())
              .length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.accountingAuditLogsTable).get()).length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.accountingDetailLedgersTable).get())
              .length,
          equals(1),
        );
        expect(
          (await freshDb.select(freshDb.accountingDetailValuesTable).get())
              .length,
          equals(1),
        );
        expect(
          (await freshDb
                  .select(freshDb.accountingDocumentDetailLinksTable)
                  .get())
              .length,
          equals(1),
        );

        // PRAGMA integrity_check
        final integrityCheck = await freshDb
            .customSelect('PRAGMA integrity_check')
            .getSingle();
        expect(integrityCheck.data.values.first, equals('ok'));

        await freshDb.close();
      },
    );

    test(
      'P0-1: restore cleanly replaces existing data instead of merging',
      () async {
        // 1. Create a backup with acc-A
        await db
            .into(db.accountsTable)
            .insert(
              AccountsTableCompanion.insert(
                id: 'acc-A',
                name: 'حساب A',
                type: 'bankCard',
                currency: 'TOMAN',
                createdAt: 1,
                updatedAt: 1,
              ),
            );
        final backupResult = await service.createEncryptedBackup(
          password: 'PassReplace',
        );
        expect(backupResult.isSuccess, isTrue);

        // 2. Target DB has acc-B
        final targetDb = AppDatabase(NativeDatabase.memory());
        await targetDb
            .into(targetDb.accountsTable)
            .insert(
              AccountsTableCompanion.insert(
                id: 'acc-B',
                name: 'حساب B نامربوط',
                type: 'bankCard',
                currency: 'TOMAN',
                createdAt: 2,
                updatedAt: 2,
              ),
            );
        final targetService = BackupService(targetDb);

        // 3. Restore backup into target DB
        final restoreResult = await targetService.restoreEncryptedBackup(
          filePath: backupResult.dataOrNull!,
          password: 'PassReplace',
        );
        expect(restoreResult.isSuccess, isTrue);

        // 4. acc-B must NOT exist! Only acc-A should exist.
        final accounts = await targetDb.select(targetDb.accountsTable).get();
        expect(accounts.length, equals(1));
        expect(accounts.first.id, equals('acc-A'));

        await targetDb.close();
      },
    );

    test('P0-1: fails restore when backup schemaVersion is newer than app database version', () async {
      await db
          .into(db.accountsTable)
          .insert(
            AccountsTableCompanion.insert(
              id: 'acc-v',
              name: 'حساب',
              type: 'bankCard',
              currency: 'TOMAN',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final backupResult = await service.createEncryptedBackup(
        password: 'PassVersion123',
      );
      expect(backupResult.isSuccess, isTrue);

      final filePath = backupResult.dataOrNull!;
      final file = File(filePath);
      final content = await file.readAsString();
      final Map<String, dynamic> json = jsonDecode(content);
      final meta = json['metadata'] as Map<String, dynamic>;
      meta['schemaVersion'] =
          AppConstants.databaseVersion + 1; // Future version
      json['metadata'] = meta;
      await file.writeAsString(jsonEncode(json));

      final restoreResult = await service.restoreEncryptedBackup(
        filePath: filePath,
        password: 'PassVersion123',
      );
      expect(restoreResult.isFailure, isTrue);
      expect(restoreResult.failureOrNull?.message, contains('جدیدتر است'));
    });
  });
}
