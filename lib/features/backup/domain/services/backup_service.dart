import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class BackupMetadata {
  final int schemaVersion;
  final String appVersion;
  final DateTime exportedAt;
  final String checksum;
  final Map<String, int> entityCounts;

  const BackupMetadata({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.checksum,
    required this.entityCounts,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'checksum': checksum,
    'entityCounts': entityCounts,
  };

  factory BackupMetadata.fromJson(Map<String, dynamic> json) => BackupMetadata(
    schemaVersion: json['schemaVersion'] as int,
    appVersion: json['appVersion'] as String,
    exportedAt: DateTime.parse(json['exportedAt'] as String),
    checksum: json['checksum'] as String,
    entityCounts: Map<String, int>.from(json['entityCounts'] as Map),
  );
}

class BackupService {
  final AppDatabase _db;

  const BackupService(this._db);

  /// Exports all non-deleted transactions to an Excel-compatible CSV file
  /// (comma-separated, UTF-8 with BOM so Excel renders Persian correctly).
  /// Returns the written file path.
  Future<Result<String>> exportTransactionsCsv() async {
    try {
      final transactions =
          await (_db.select(_db.transactionsTable)
                ..where((t) => t.deletedAt.isNull())
                ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)]))
              .get();
      final accounts = {
        for (final a in await _db.select(_db.accountsTable).get()) a.id: a.name,
      };
      final categories = {
        for (final c in await _db.select(_db.categoriesTable).get())
          c.id: c.name,
      };

      String esc(String value) => '"${value.replaceAll('"', '""')}"';

      final buffer = StringBuffer('\uFEFF'); // UTF-8 BOM for Excel
      buffer.writeln('تاریخ شمسی,تاریخ میلادی,نوع,شرح,حساب,دسته,مبلغ,ارز');

      for (final tx in transactions) {
        final date = DateTime.fromMillisecondsSinceEpoch(tx.transactionDate);
        final jalali = JalaliDate.fromDateTime(date)
            .format(usePersianDigits: false);
        final type = TransactionType.fromCode(tx.type);
        final majorValue = _majorValue(tx.amountMinor, tx.currency);

        buffer.writeln(
          [
            esc(jalali),
            esc(date.toIso8601String()),
            esc(type.titleFa),
            esc(tx.description),
            esc(accounts[tx.accountId] ?? ''),
            esc(tx.categoryId != null ? (categories[tx.categoryId] ?? '') : ''),
            majorValue.toString(),
            esc(tx.currency),
          ].join(','),
        );
      }

      final dir = await getApplicationDocumentsDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = p.join(dir.path, 'kifino_transactions_$dateStr.csv');
      final file = File(filePath);
      await file.writeAsString(buffer.toString(), encoding: utf8);

      return Success(filePath);
    } catch (e) {
      return FailureResult(DatabaseFailure('خطا در خروجی گرفتن تراکنش‌ها: $e'));
    }
  }

  /// Converts stored minor units to the human-readable major value the user
  /// actually thinks in (Toman for zero-decimal IRR-family currencies).
  int _majorValue(int minor, String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case 'IRR':
      case 'TOMAN':
        return minor; // already integer-sized units for Iranian currencies
      case 'USD':
      case 'EUR':
      case 'GBP':
        return minor ~/ 100;
      default:
        return minor;
    }
  }

  /// Derives a 32-byte Key and 16-byte IV from password
  (enc.Key, enc.IV) _deriveKeyAndIv(String password) {
    final keyBytes = sha256.convert(utf8.encode('kifino:key:$password')).bytes;
    final ivBytes = md5.convert(utf8.encode('kifino:iv:$password')).bytes;
    return (
      enc.Key(Uint8List.fromList(keyBytes)),
      enc.IV(Uint8List.fromList(ivBytes)),
    );
  }

  /// Exports all financial entities to an encrypted JSON file
  Future<Result<String>> createEncryptedBackup({
    required String password,
  }) async {
    try {
      final accounts = await _db.select(_db.accountsTable).get();
      final categories = await _db.select(_db.categoriesTable).get();
      final tags = await _db.select(_db.tagsTable).get();
      final transactions = await _db.select(_db.transactionsTable).get();
      final transactionTags = await _db.select(_db.transactionTagsTable).get();
      final budgets = await _db.select(_db.budgetsTable).get();
      final budgetCategories = await _db
          .select(_db.budgetCategoriesTable)
          .get();
      final debts = await _db.select(_db.debtsReceivablesTable).get();
      final installments = await _db.select(_db.installmentsTable).get();
      final installmentPayments = await _db
          .select(_db.installmentPaymentsTable)
          .get();
      final checks = await _db.select(_db.checksTable).get();
      final assets = await _db.select(_db.assetsTable).get();
      final financialGoals = await _db.select(_db.financialGoalsTable).get();
      final contacts = await _db.select(_db.businessContactsTable).get();
      final products = await _db.select(_db.productsTable).get();
      final inventoryLogs = await _db.select(_db.inventoryLogsTable).get();
      final invoices = await _db.select(_db.invoicesTable).get();
      final invoiceItems = await _db.select(_db.invoiceItemsTable).get();
      final syncQueue = await _db.select(_db.syncQueueTable).get();
      final notifications = await _db.select(_db.notificationsTable).get();
      final fiscalYears = await _db.select(_db.fiscalYearsTable).get();
      final accountingSubjects = await _db
          .select(_db.accountingSubjectsTable)
          .get();
      final accountingDocuments = await _db
          .select(_db.accountingDocumentsTable)
          .get();
      final accountingTransactions = await _db
          .select(_db.accountingTransactionsTable)
          .get();
      final accountingAuditLogs = await _db
          .select(_db.accountingAuditLogsTable)
          .get();
      final accountingDetailLedgers = await _db
          .select(_db.accountingDetailLedgersTable)
          .get();
      final accountingDetailValues = await _db
          .select(_db.accountingDetailValuesTable)
          .get();
      final accountingDocumentDetailLinks = await _db
          .select(_db.accountingDocumentDetailLinksTable)
          .get();

      final dataMap = {
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'tags': tags.map((t) => t.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'transactionTags': transactionTags.map((tt) => tt.toJson()).toList(),
        'budgets': budgets.map((b) => b.toJson()).toList(),
        'budgetCategories': budgetCategories.map((bc) => bc.toJson()).toList(),
        'debts': debts.map((d) => d.toJson()).toList(),
        'installments': installments.map((i) => i.toJson()).toList(),
        'installmentPayments': installmentPayments
            .map((ip) => ip.toJson())
            .toList(),
        'checks': checks.map((c) => c.toJson()).toList(),
        'assets': assets.map((a) => a.toJson()).toList(),
        'financialGoals': financialGoals.map((g) => g.toJson()).toList(),
        'contacts': contacts.map((c) => c.toJson()).toList(),
        'products': products.map((p) => p.toJson()).toList(),
        'inventoryLogs': inventoryLogs.map((il) => il.toJson()).toList(),
        'invoices': invoices.map((i) => i.toJson()).toList(),
        'invoiceItems': invoiceItems.map((ii) => ii.toJson()).toList(),
        'syncQueue': syncQueue.map((sq) => sq.toJson()).toList(),
        'notifications': notifications.map((n) => n.toJson()).toList(),
        'fiscalYears': fiscalYears.map((fy) => fy.toJson()).toList(),
        'accountingSubjects': accountingSubjects
            .map((s) => s.toJson())
            .toList(),
        'accountingDocuments': accountingDocuments
            .map((d) => d.toJson())
            .toList(),
        'accountingTransactions': accountingTransactions
            .map((at) => at.toJson())
            .toList(),
        'accountingAuditLogs': accountingAuditLogs
            .map((al) => al.toJson())
            .toList(),
        'accountingDetailLedgers': accountingDetailLedgers
            .map((adl) => adl.toJson())
            .toList(),
        'accountingDetailValues': accountingDetailValues
            .map((adv) => adv.toJson())
            .toList(),
        'accountingDocumentDetailLinks': accountingDocumentDetailLinks
            .map((link) => link.toJson())
            .toList(),
      };

      final jsonPayload = jsonEncode(dataMap);
      final checksum = sha256.convert(utf8.encode(jsonPayload)).toString();

      final metadata = BackupMetadata(
        schemaVersion: AppConstants.databaseVersion,
        appVersion: '1.0.0',
        exportedAt: DateTime.now(),
        checksum: checksum,
        entityCounts: {
          'accounts': accounts.length,
          'categories': categories.length,
          'tags': tags.length,
          'transactions': transactions.length,
          'transactionTags': transactionTags.length,
          'budgets': budgets.length,
          'budgetCategories': budgetCategories.length,
          'debts': debts.length,
          'installments': installments.length,
          'installmentPayments': installmentPayments.length,
          'checks': checks.length,
          'assets': assets.length,
          'financialGoals': financialGoals.length,
          'contacts': contacts.length,
          'products': products.length,
          'inventoryLogs': inventoryLogs.length,
          'invoices': invoices.length,
          'invoiceItems': invoiceItems.length,
          'syncQueue': syncQueue.length,
          'notifications': notifications.length,
          'fiscalYears': fiscalYears.length,
          'accountingSubjects': accountingSubjects.length,
          'accountingDocuments': accountingDocuments.length,
          'accountingTransactions': accountingTransactions.length,
          'accountingAuditLogs': accountingAuditLogs.length,
          'accountingDetailLedgers': accountingDetailLedgers.length,
          'accountingDetailValues': accountingDetailValues.length,
          'accountingDocumentDetailLinks': accountingDocumentDetailLinks.length,
        },
      );

      // AES-256-CBC Encryption
      final (key, iv) = _deriveKeyAndIv(password);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(jsonPayload, iv: iv);

      final backupPackage = jsonEncode({
        'metadata': metadata.toJson(),
        'cipher': encrypted.base64,
      });

      final dir = await getApplicationDocumentsDirectory();
      final dateStr = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filePath = p.join(dir.path, 'kifino_backup_$dateStr.kfn');
      final file = File(filePath);
      await file.writeAsString(backupPackage);

      return Success(filePath);
    } catch (e) {
      return FailureResult(
        DatabaseFailure('خطا در ایجاد پشتیبان رمزنگاری‌شده: $e'),
      );
    }
  }

  /// Restores from an encrypted backup file
  Future<Result<BackupMetadata>> restoreEncryptedBackup({
    required String filePath,
    required String password,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const FailureResult(DatabaseFailure('فایل پشتیبان یافت نشد.'));
      }

      final content = await file.readAsString();
      final Map<String, dynamic> package =
          jsonDecode(content) as Map<String, dynamic>;

      final metadataJson = package['metadata'] as Map<String, dynamic>;
      final metadata = BackupMetadata.fromJson(metadataJson);

      if (metadata.schemaVersion > AppConstants.databaseVersion) {
        return FailureResult(
          DatabaseFailure(
            'نسخه پایگاه داده فایل پشتیبان (${metadata.schemaVersion}) از نسخه فعلی برنامه (${AppConstants.databaseVersion}) جدیدتر است و قابل بازیابی نیست.',
          ),
        );
      }

      final cipherBase64 = package['cipher'] as String;

      // Decrypt
      final (key, iv) = _deriveKeyAndIv(password);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      String decryptedPayload;
      try {
        decryptedPayload = encrypter.decrypt64(cipherBase64, iv: iv);
      } catch (e) {
        return const FailureResult(
          SecurityFailure(
            'رمز عبور پشتیبان اشتباه است یا فایل دستکاری شده است.',
          ),
        );
      }

      // Verify Checksum
      final computedChecksum = sha256
          .convert(utf8.encode(decryptedPayload))
          .toString();
      if (computedChecksum != metadata.checksum) {
        return FailureResult(
          DatabaseFailure('فایل پشتیبان معتبر نیست (ناهماهنگی در چک‌سام).'),
        );
      }

      final dataMap = jsonDecode(decryptedPayload) as Map<String, dynamic>;

      // Clean replacement inside atomic transaction:
      // 1. Wipe all existing tables in reverse dependency order.
      // 2. Insert all restored records.
      await _db.transaction(() async {
        await _db.delete(_db.accountingDocumentDetailLinksTable).go();
        await _db.delete(_db.accountingDetailValuesTable).go();
        await _db.delete(_db.accountingDetailLedgersTable).go();
        await _db.delete(_db.accountingAuditLogsTable).go();
        await _db.delete(_db.accountingTransactionsTable).go();
        await _db.delete(_db.accountingDocumentsTable).go();
        await _db.delete(_db.accountingSubjectsTable).go();
        await _db.delete(_db.fiscalYearsTable).go();
        await _db.delete(_db.notificationsTable).go();
        await _db.delete(_db.syncQueueTable).go();
        await _db.delete(_db.invoiceItemsTable).go();
        await _db.delete(_db.invoicesTable).go();
        await _db.delete(_db.inventoryLogsTable).go();
        await _db.delete(_db.productsTable).go();
        await _db.delete(_db.businessContactsTable).go();
        await _db.delete(_db.financialGoalsTable).go();
        await _db.delete(_db.assetsTable).go();
        await _db.delete(_db.checksTable).go();
        await _db.delete(_db.installmentPaymentsTable).go();
        await _db.delete(_db.installmentsTable).go();
        await _db.delete(_db.debtsReceivablesTable).go();
        await _db.delete(_db.budgetCategoriesTable).go();
        await _db.delete(_db.budgetsTable).go();
        await _db.delete(_db.transactionTagsTable).go();
        await _db.delete(_db.tagsTable).go();
        await _db.delete(_db.transactionsTable).go();
        await _db.delete(_db.categoriesTable).go();
        await _db.delete(_db.accountsTable).go();

        // Accounts
        if (dataMap.containsKey('accounts')) {
          for (final item in (dataMap['accounts'] as List)) {
            final acc = AccountData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.accountsTable).insert(acc);
          }
        }

        // Categories
        if (dataMap.containsKey('categories')) {
          for (final item in (dataMap['categories'] as List)) {
            final cat = CategoryData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.categoriesTable).insert(cat);
          }
        }

        // Tags
        if (dataMap.containsKey('tags')) {
          for (final item in (dataMap['tags'] as List)) {
            final tag = TagData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.tagsTable).insert(tag);
          }
        }

        // Transactions
        if (dataMap.containsKey('transactions')) {
          for (final item in (dataMap['transactions'] as List)) {
            final tx = TransactionData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.transactionsTable).insert(tx);
          }
        }

        // TransactionTags
        if (dataMap.containsKey('transactionTags')) {
          for (final item in (dataMap['transactionTags'] as List)) {
            final tt = TransactionTagData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.transactionTagsTable).insert(tt);
          }
        }

        // Budgets
        if (dataMap.containsKey('budgets')) {
          for (final item in (dataMap['budgets'] as List)) {
            final b = BudgetData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.budgetsTable).insert(b);
          }
        }

        // BudgetCategories
        if (dataMap.containsKey('budgetCategories')) {
          for (final item in (dataMap['budgetCategories'] as List)) {
            final bc = BudgetCategoryData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.budgetCategoriesTable).insert(bc);
          }
        }

        // Debts
        if (dataMap.containsKey('debts')) {
          for (final item in (dataMap['debts'] as List)) {
            final d = DebtReceivableData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.debtsReceivablesTable).insert(d);
          }
        }

        // Installments
        if (dataMap.containsKey('installments')) {
          for (final item in (dataMap['installments'] as List)) {
            final inst = InstallmentData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.installmentsTable).insert(inst);
          }
        }

        // Installment Payments
        if (dataMap.containsKey('installmentPayments')) {
          for (final item in (dataMap['installmentPayments'] as List)) {
            final ip = InstallmentPaymentData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.installmentPaymentsTable).insert(ip);
          }
        }

        // Checks
        if (dataMap.containsKey('checks')) {
          for (final item in (dataMap['checks'] as List)) {
            final chk = CheckData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.checksTable).insert(chk);
          }
        }

        // Assets
        if (dataMap.containsKey('assets')) {
          for (final item in (dataMap['assets'] as List)) {
            final ast = AssetData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.assetsTable).insert(ast);
          }
        }

        // Financial Goals
        if (dataMap.containsKey('financialGoals')) {
          for (final item in (dataMap['financialGoals'] as List)) {
            final g = FinancialGoalData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.financialGoalsTable).insert(g);
          }
        }

        // Business Contacts
        if (dataMap.containsKey('contacts')) {
          for (final item in (dataMap['contacts'] as List)) {
            final c = BusinessContactData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.businessContactsTable).insert(c);
          }
        }

        // Products
        if (dataMap.containsKey('products')) {
          for (final item in (dataMap['products'] as List)) {
            final pr = ProductData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.productsTable).insert(pr);
          }
        }

        // Inventory Logs
        if (dataMap.containsKey('inventoryLogs')) {
          for (final item in (dataMap['inventoryLogs'] as List)) {
            final il = InventoryLogData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.inventoryLogsTable).insert(il);
          }
        }

        // Invoices
        if (dataMap.containsKey('invoices')) {
          for (final item in (dataMap['invoices'] as List)) {
            final inv = InvoiceData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.invoicesTable).insert(inv);
          }
        }

        // Invoice line items
        if (dataMap.containsKey('invoiceItems')) {
          for (final item in (dataMap['invoiceItems'] as List)) {
            final invItem = InvoiceItemData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.invoiceItemsTable).insert(invItem);
          }
        }

        // Sync Queue
        if (dataMap.containsKey('syncQueue')) {
          for (final item in (dataMap['syncQueue'] as List)) {
            final sq = SyncQueueData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.syncQueueTable).insert(sq);
          }
        }

        // Notifications
        if (dataMap.containsKey('notifications')) {
          for (final item in (dataMap['notifications'] as List)) {
            final n = NotificationData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.notificationsTable).insert(n);
          }
        }

        // Fiscal Years
        if (dataMap.containsKey('fiscalYears')) {
          for (final item in (dataMap['fiscalYears'] as List)) {
            final fy = FiscalYearData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.fiscalYearsTable).insert(fy);
          }
        }

        // Accounting Subjects
        if (dataMap.containsKey('accountingSubjects')) {
          for (final item in (dataMap['accountingSubjects'] as List)) {
            final s = AccountingSubjectData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.accountingSubjectsTable).insert(s);
          }
        }

        // Accounting Documents
        if (dataMap.containsKey('accountingDocuments')) {
          for (final item in (dataMap['accountingDocuments'] as List)) {
            final d = AccountingDocumentData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.accountingDocumentsTable).insert(d);
          }
        }

        // Accounting Transactions
        if (dataMap.containsKey('accountingTransactions')) {
          for (final item in (dataMap['accountingTransactions'] as List)) {
            final at = AccountingTransactionData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.accountingTransactionsTable).insert(at);
          }
        }

        // Accounting Audit Logs
        if (dataMap.containsKey('accountingAuditLogs')) {
          for (final item in (dataMap['accountingAuditLogs'] as List)) {
            final al = AccountingAuditLogData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.accountingAuditLogsTable).insert(al);
          }
        }

        // Accounting Detail Ledgers
        if (dataMap.containsKey('accountingDetailLedgers')) {
          for (final item in (dataMap['accountingDetailLedgers'] as List)) {
            final adl = AccountingDetailLedgerData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.accountingDetailLedgersTable).insert(adl);
          }
        }

        // Accounting Detail Values
        if (dataMap.containsKey('accountingDetailValues')) {
          for (final item in (dataMap['accountingDetailValues'] as List)) {
            final adv = AccountingDetailValueData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.accountingDetailValuesTable).insert(adv);
          }
        }

        // Accounting Document Detail Links
        if (dataMap.containsKey('accountingDocumentDetailLinks')) {
          for (final item
              in (dataMap['accountingDocumentDetailLinks'] as List)) {
            final link = AccountingDocumentDetailLinkData.fromJson(
              item as Map<String, dynamic>,
            );
            await _db.into(_db.accountingDocumentDetailLinksTable).insert(link);
          }
        }
      });

      return Success(metadata);
    } catch (e) {
      return FailureResult(DatabaseFailure('خطا در بازیابی اطلاعات: $e'));
    }
  }
}
