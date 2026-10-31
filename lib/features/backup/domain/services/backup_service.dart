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
      final transactions = await (_db.select(_db.transactionsTable)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.transactionDate),
            ]))
          .get();
      final accounts = {for (final a in await _db.select(_db.accountsTable).get()) a.id: a.name};
      final categories = {
        for (final c in await _db.select(_db.categoriesTable).get()) c.id: c.name,
      };

      String esc(String value) => '"${value.replaceAll('"', '""')}"';

      final buffer = StringBuffer('\uFEFF'); // UTF-8 BOM for Excel
      buffer.writeln('تاریخ شمسی,تاریخ میلادی,نوع,شرح,حساب,دسته,مبلغ,ارز');

      for (final tx in transactions) {
        final date = DateTime.fromMillisecondsSinceEpoch(tx.transactionDate);
        final jalali = JalaliDate.fromDateTime(date).format(usePersianDigits: false);
        final type = TransactionType.fromCode(tx.type);
        final majorValue = _majorValue(tx.amountMinor, tx.currency);

        buffer.writeln([
          esc(jalali),
          esc(date.toIso8601String()),
          esc(type.titleFa),
          esc(tx.description),
          esc(accounts[tx.accountId] ?? ''),
          esc(tx.categoryId != null ? (categories[tx.categoryId] ?? '') : ''),
          majorValue.toString(),
          esc(tx.currency),
        ].join(','));
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
    return (enc.Key(Uint8List.fromList(keyBytes)), enc.IV(Uint8List.fromList(ivBytes)));
  }

  /// Exports all financial entities to an encrypted JSON file
  Future<Result<String>> createEncryptedBackup({required String password}) async {
    try {
      final accounts = await _db.select(_db.accountsTable).get();
      final categories = await _db.select(_db.categoriesTable).get();
      final transactions = await _db.select(_db.transactionsTable).get();
      final budgets = await _db.select(_db.budgetsTable).get();
      final debts = await _db.select(_db.debtsReceivablesTable).get();
      final installments = await _db.select(_db.installmentsTable).get();
      final checks = await _db.select(_db.checksTable).get();
      final assets = await _db.select(_db.assetsTable).get();
      final contacts = await _db.select(_db.businessContactsTable).get();
      final products = await _db.select(_db.productsTable).get();
      final invoices = await _db.select(_db.invoicesTable).get();
      final invoiceItems = await _db.select(_db.invoiceItemsTable).get();

      final dataMap = {
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'categories': categories.map((c) => c.toJson()).toList(),
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'budgets': budgets.map((b) => b.toJson()).toList(),
        'debts': debts.map((d) => d.toJson()).toList(),
        'installments': installments.map((i) => i.toJson()).toList(),
        'checks': checks.map((c) => c.toJson()).toList(),
        'assets': assets.map((a) => a.toJson()).toList(),
        'contacts': contacts.map((c) => c.toJson()).toList(),
        'products': products.map((p) => p.toJson()).toList(),
        'invoices': invoices.map((i) => i.toJson()).toList(),
        'invoiceItems': invoiceItems.map((ii) => ii.toJson()).toList(),
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
          'transactions': transactions.length,
          'budgets': budgets.length,
          'debts': debts.length,
          'invoices': invoices.length,
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
      return FailureResult(DatabaseFailure('خطا در ایجاد پشتیبان رمزنگاری‌شده: $e'));
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
      final Map<String, dynamic> package = jsonDecode(content) as Map<String, dynamic>;

      final metadataJson = package['metadata'] as Map<String, dynamic>;
      final metadata = BackupMetadata.fromJson(metadataJson);

      final cipherBase64 = package['cipher'] as String;

      // Decrypt
      final (key, iv) = _deriveKeyAndIv(password);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      String decryptedPayload;
      try {
        decryptedPayload = encrypter.decrypt64(cipherBase64, iv: iv);
      } catch (e) {
        return const FailureResult(SecurityFailure('رمز عبور پشتیبان اشتباه است یا فایل دستکاری شده است.'));
      }

      // Verify Checksum
      final computedChecksum = sha256.convert(utf8.encode(decryptedPayload)).toString();
      if (computedChecksum != metadata.checksum) {
        return FailureResult(DatabaseFailure('فایل پشتیبان معتبر نیست (ناهماهنگی در چک‌سام).'));
      }

      final dataMap = jsonDecode(decryptedPayload) as Map<String, dynamic>;

      // Restore inside atomic transaction
      await _db.transaction(() async {
        // Accounts
        if (dataMap.containsKey('accounts')) {
          for (final item in (dataMap['accounts'] as List)) {
            final acc = AccountData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.accountsTable).insertOnConflictUpdate(acc);
          }
        }

        // Transactions
        if (dataMap.containsKey('transactions')) {
          for (final item in (dataMap['transactions'] as List)) {
            final tx = TransactionData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.transactionsTable).insertOnConflictUpdate(tx);
          }
        }

        // Budgets
        if (dataMap.containsKey('budgets')) {
          for (final item in (dataMap['budgets'] as List)) {
            final b = BudgetData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.budgetsTable).insertOnConflictUpdate(b);
          }
        }

        // Debts
        if (dataMap.containsKey('debts')) {
          for (final item in (dataMap['debts'] as List)) {
            final d = DebtReceivableData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.debtsReceivablesTable).insertOnConflictUpdate(d);
          }
        }

        // Installments
        if (dataMap.containsKey('installments')) {
          for (final item in (dataMap['installments'] as List)) {
            final inst = InstallmentData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.installmentsTable).insertOnConflictUpdate(inst);
          }
        }

        // Checks
        if (dataMap.containsKey('checks')) {
          for (final item in (dataMap['checks'] as List)) {
            final chk = CheckData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.checksTable).insertOnConflictUpdate(chk);
          }
        }

        // Assets
        if (dataMap.containsKey('assets')) {
          for (final item in (dataMap['assets'] as List)) {
            final ast = AssetData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.assetsTable).insertOnConflictUpdate(ast);
          }
        }

        // Business Contacts
        if (dataMap.containsKey('contacts')) {
          for (final item in (dataMap['contacts'] as List)) {
            final c = BusinessContactData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.businessContactsTable).insertOnConflictUpdate(c);
          }
        }

        // Products
        if (dataMap.containsKey('products')) {
          for (final item in (dataMap['products'] as List)) {
            final pr = ProductData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.productsTable).insertOnConflictUpdate(pr);
          }
        }

        // Invoices
        if (dataMap.containsKey('invoices')) {
          for (final item in (dataMap['invoices'] as List)) {
            final inv = InvoiceData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.invoicesTable).insertOnConflictUpdate(inv);
          }
        }

        // Invoice line items — without these, restored invoices lose all
        // their rows (data-loss bug in the original restore).
        if (dataMap.containsKey('invoiceItems')) {
          for (final item in (dataMap['invoiceItems'] as List)) {
            final invItem = InvoiceItemData.fromJson(item as Map<String, dynamic>);
            await _db.into(_db.invoiceItemsTable).insertOnConflictUpdate(invItem);
          }
        }
      });

      return Success(metadata);
    } catch (e) {
      return FailureResult(DatabaseFailure('خطا در بازیابی اطلاعات: $e'));
    }
  }
}
