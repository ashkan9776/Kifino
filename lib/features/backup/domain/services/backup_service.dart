import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Constant, OrderingTerm, Table, TableInfo;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' as pc;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class BackupMetadata {
  final int schemaVersion;
  final String appVersion;
  final DateTime exportedAt;
  final String checksum;
  final Map<String, int> entityCounts;
  final bool isLegacyFormat;

  const BackupMetadata({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.checksum,
    required this.entityCounts,
    this.isLegacyFormat = false,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'checksum': checksum,
    'entityCounts': entityCounts,
    'isLegacyFormat': isLegacyFormat,
  };

  factory BackupMetadata.fromJson(
    Map<String, dynamic> json, {
    bool isLegacyFormat = false,
  }) => BackupMetadata(
    schemaVersion: json['schemaVersion'] as int,
    appVersion: json['appVersion'] as String,
    exportedAt: DateTime.parse(json['exportedAt'] as String),
    checksum: json['checksum'] as String,
    entityCounts: Map<String, int>.from(json['entityCounts'] as Map),
    isLegacyFormat:
        isLegacyFormat || (json['isLegacyFormat'] as bool? ?? false),
  );
}

class BackupService {
  static const int currentFormatVersion = 3;
  static const int defaultKdfIterations = 300000;
  static const int minRestoreIterations = 1000;
  static const int maxRestoreIterations = 2000000;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _gcmTagBits = 128;
  static const Set<String> _allowedMetadataKeys = {
    'schemaVersion',
    'appVersion',
    'exportedAt',
    'checksum',
    'entityCounts',
    'isLegacyFormat',
  };
  static final RegExp _csvFormulaLeadPattern = RegExp(r'^\s*[=+\-@\t\r]');

  final AppDatabase _db;

  const BackupService(this._db);

  /// Backups written by older app versions lack columns added later (e.g.
  /// products.avgCostMinor in v9). Drift's generated `fromJson` throws on a
  /// missing non-nullable field, which made those backups unrestorable.
  /// Fills every missing column that has a constant default with that default
  /// (and leaves nullable ones absent, which `fromJson` reads as null).
  static Map<String, dynamic> _withColumnDefaults(
    TableInfo<Table, dynamic> table,
    Object? item,
  ) {
    final json = Map<String, dynamic>.from(item as Map);
    for (final column in table.$columns) {
      final key = _camelCase(column.name);
      if (json.containsKey(key)) continue;
      final defaultValue = column.defaultValue;
      if (defaultValue is Constant) {
        json[key] = defaultValue.value;
      }
    }
    return json;
  }

  static String _camelCase(String snake) {
    final parts = snake.split('_');
    return parts.first +
        parts.skip(1).map((p) {
          if (p.isEmpty) return p;
          return p[0].toUpperCase() + p.substring(1);
        }).join();
  }

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

      String esc(String value) {
        final safe = sanitizeCsvCell(value);
        return '"${safe.replaceAll('"', '""')}"';
      }

      final buffer = StringBuffer('\uFEFF'); // UTF-8 BOM for Excel
      buffer.writeln('تاریخ شمسی,تاریخ میلادی,نوع,شرح,حساب,دسته,مبلغ,ارز');

      for (final tx in transactions) {
        final date = DateTime.fromMillisecondsSinceEpoch(tx.transactionDate);
        final jalali = JalaliDate.fromDateTime(date)
            .format(usePersianDigits: false);
        final type = TransactionType.fromCode(tx.type);
        final majorValue = majorValueForCsv(tx.amountMinor, tx.currency);

        buffer.writeln(
          [
            esc(jalali),
            esc(date.toIso8601String()),
            esc(type.titleFa),
            esc(tx.description),
            esc(accounts[tx.accountId] ?? ''),
            esc(tx.categoryId != null ? (categories[tx.categoryId] ?? '') : ''),
            majorValue,
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
  /// actually thinks in, keeping fractional units (12.50 USD stays 12.50 —
  /// the old integer division exported it as 12).
  static String majorValueForCsv(int minor, String currencyCode) {
    final decimals = Currency.fromCodeOrNull(currencyCode)?.decimals ?? 0;
    if (decimals == 0) return minor.toString();
    final factor = pow(10, decimals).toInt();
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    final fraction = (abs % factor).toString().padLeft(decimals, '0');
    return '$sign${abs ~/ factor}.$fraction';
  }

  /// Neutralizes CSV/spreadsheet formula injection on text cells.
  ///
  /// Any cell whose value (ignoring leading whitespace) starts with `=`, `+`,
  /// `-`, `@`, `\t`, or `\r` is prefixed with a leading single quote `'` before
  /// CSV quoting. Numeric cells must NOT be passed through this helper so valid
  /// negative numbers remain unquoted numbers.
  static String sanitizeCsvCell(String value) {
    if (value.isEmpty) return value;
    if (_csvFormulaLeadPattern.hasMatch(value)) {
      return "'$value";
    }
    return value;
  }

  /// Evaluates password strength:
  /// Returns a score between 0 and 4:
  /// 0: Too short (< 8)
  /// 1: Weak
  /// 2: Fair
  /// 3: Good
  /// 4: Strong
  static int evaluatePasswordStrength(String password) {
    if (password.length < 8) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[a-zA-Z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return score;
  }

  /// PBKDF2-HMAC-SHA256 key derivation with salt and configurable iterations.
  static Uint8List _derivePbkdf2Key({
    required String password,
    required Uint8List salt,
    int iterations = defaultKdfIterations,
    int keyLength = 32,
  }) {
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(salt, iterations, keyLength));
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    return derivator.process(passwordBytes);
  }

  /// Encrypts plaintext using AES-256-GCM with 128-bit authentication tag.
  static (Uint8List cipherWithTag, Uint8List nonce) _encryptGcm({
    required Uint8List key,
    required Uint8List plaintext,
    required Uint8List aad,
    Uint8List? nonce,
  }) {
    final actualNonce =
        nonce ??
        () {
          final rng = Random.secure();
          return Uint8List.fromList(
            List.generate(_nonceLength, (_) => rng.nextInt(256)),
          );
        }();

    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        true,
        pc.AEADParameters(pc.KeyParameter(key), _gcmTagBits, actualNonce, aad),
      );
    final output = cipher.process(plaintext);
    return (output, actualNonce);
  }

  /// Decrypts ciphertext and verifies GCM authentication tag + AAD.
  static Uint8List _decryptGcm({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List cipherWithTag,
    required Uint8List aad,
  }) {
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(
        false,
        pc.AEADParameters(pc.KeyParameter(key), _gcmTagBits, nonce, aad),
      );
    return cipher.process(cipherWithTag);
  }

  static (Uint8List cipherWithTag, Uint8List nonce) _deriveAndEncryptGcm({
    required String password,
    required Uint8List salt,
    required int iterations,
    required Uint8List plaintext,
    required Uint8List aad,
  }) {
    final key = _derivePbkdf2Key(
      password: password,
      salt: salt,
      iterations: iterations,
    );
    return _encryptGcm(key: key, plaintext: plaintext, aad: aad);
  }

  static Uint8List _deriveAndDecryptGcm({
    required String password,
    required Uint8List salt,
    required int iterations,
    required Uint8List nonce,
    required Uint8List cipherWithTag,
    required Uint8List aad,
  }) {
    final key = _derivePbkdf2Key(
      password: password,
      salt: salt,
      iterations: iterations,
    );
    return _decryptGcm(
      key: key,
      nonce: nonce,
      cipherWithTag: cipherWithTag,
      aad: aad,
    );
  }

  /// Derives a 32-byte Key and 16-byte IV from password (legacy V1 format).
  static (enc.Key, enc.IV) _deriveKeyAndIv(String password) {
    final keyBytes = sha256.convert(utf8.encode('kifino:key:$password')).bytes;
    final ivBytes = md5.convert(utf8.encode('kifino:iv:$password')).bytes;
    return (
      enc.Key(Uint8List.fromList(keyBytes)),
      enc.IV(Uint8List.fromList(ivBytes)),
    );
  }

  static String _decryptLegacyV1({
    required String password,
    required String cipherBase64,
  }) {
    final (key, iv) = _deriveKeyAndIv(password);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(cipherBase64, iv: iv);
  }

  static Future<(Uint8List cipherWithTag, Uint8List nonce)> _encryptInIsolate({
    required String password,
    required Uint8List salt,
    required int iterations,
    required Uint8List plaintext,
    required Uint8List aad,
  }) => Isolate.run(
    () => _deriveAndEncryptGcm(
      password: password,
      salt: salt,
      iterations: iterations,
      plaintext: plaintext,
      aad: aad,
    ),
  );

  static Future<Uint8List> _decryptGcmInIsolate({
    required String password,
    required Uint8List salt,
    required int iterations,
    required Uint8List nonce,
    required Uint8List cipherWithTag,
    required Uint8List aad,
  }) => Isolate.run(
    () => _deriveAndDecryptGcm(
      password: password,
      salt: salt,
      iterations: iterations,
      nonce: nonce,
      cipherWithTag: cipherWithTag,
      aad: aad,
    ),
  );

  static Future<String> _decryptLegacyV1InIsolate({
    required String password,
    required String cipherBase64,
  }) => Isolate.run(
    () => _decryptLegacyV1(password: password, cipherBase64: cipherBase64),
  );

  static Uint8List _canonicalMetadataAad(BackupMetadata metadata) =>
      Uint8List.fromList(utf8.encode(jsonEncode(metadata.toJson())));

  /// Exports all financial entities to an encrypted JSON file
  Future<Result<String>> createEncryptedBackup({
    required String password,
    int iterations = defaultKdfIterations,
  }) async {
    if (password.length < 8) {
      return const FailureResult(
        ValidationFailure('رمز عبور باید حداقل ۸ کاراکتر باشد.'),
      );
    }
    if (iterations < minRestoreIterations ||
        iterations > maxRestoreIterations) {
      return const FailureResult(
        SecurityFailure('تعداد تکرار کلید (KDF) خارج از محدوده مجاز است.'),
      );
    }
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
      final recurringRules = await _db.select(_db.recurringRulesTable).get();

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
        'recurringRules': recurringRules.map((r) => r.toJson()).toList(),
      };

      final jsonPayload = jsonEncode(dataMap);
      final checksum = sha256.convert(utf8.encode(jsonPayload)).toString();

      final metadata = BackupMetadata(
        schemaVersion: AppConstants.databaseVersion,
        appVersion: AppConstants.appVersion,
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
          'recurringRules': recurringRules.length,
        },
      );

      // PBKDF2-HMAC-SHA256 + AES-256-GCM (v3 binds canonical metadata via AAD),
      // executed in a background isolate so the UI thread stays responsive.
      final rng = Random.secure();
      final salt = Uint8List.fromList(
        List.generate(_saltLength, (_) => rng.nextInt(256)),
      );
      final metadataMap = metadata.toJson();
      final plaintext = Uint8List.fromList(utf8.encode(jsonPayload));
      final aad = _canonicalMetadataAad(metadata);

      final (cipherWithTag, nonce) = await _encryptInIsolate(
        password: password,
        salt: salt,
        iterations: iterations,
        plaintext: plaintext,
        aad: aad,
      );

      final backupPackage = jsonEncode({
        'magic': 'KIFINO',
        'formatVersion': currentFormatVersion,
        'kdf': {
          'algorithm': 'PBKDF2-HMAC-SHA256',
          'iterations': iterations,
          'salt': base64Encode(salt),
        },
        'nonce': base64Encode(nonce),
        'metadata': metadataMap,
        'cipher': base64Encode(cipherWithTag),
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
      final decodedPackage = jsonDecode(content);
      if (decodedPackage is! Map) {
        return const FailureResult(
          SecurityFailure('ساختار فایل پشتیبان نامعتبر است.'),
        );
      }
      final package = Map<String, dynamic>.from(decodedPackage);

      final magic = package['magic'];
      final rawFormatVersion = package['formatVersion'];
      final int backupFormatVersion;
      if (magic == 'KIFINO') {
        if (rawFormatVersion is! int ||
            (rawFormatVersion != 2 && rawFormatVersion != 3)) {
          return const FailureResult(
            SecurityFailure('نسخه فرمت فایل پشتیبان پشتیبانی نمی‌شود.'),
          );
        }
        backupFormatVersion = rawFormatVersion;
      } else if (rawFormatVersion == null && magic == null) {
        backupFormatVersion = 1;
      } else {
        return const FailureResult(
          SecurityFailure('ساختار فایل پشتیبان معتبر نیست.'),
        );
      }

      final rawMetadata = package['metadata'];
      if (rawMetadata is! Map) {
        return const FailureResult(
          SecurityFailure('متادیتای فایل پشتیبان نامعتبر است.'),
        );
      }
      final metadataJson = Map<String, dynamic>.from(rawMetadata);
      if (backupFormatVersion >= 2 &&
          !metadataJson.keys.every(_allowedMetadataKeys.contains)) {
        return const FailureResult(
          SecurityFailure(
            'متادیتای فایل پشتیبان معتبر نیست یا دستکاری شده است.',
          ),
        );
      }

      final BackupMetadata metadata;
      try {
        metadata = BackupMetadata.fromJson(
          metadataJson,
          isLegacyFormat: backupFormatVersion == 1,
        );
      } catch (_) {
        return const FailureResult(
          SecurityFailure(
            'متادیتای فایل پشتیبان معتبر نیست یا دستکاری شده است.',
          ),
        );
      }

      if (metadata.schemaVersion > AppConstants.databaseVersion) {
        return FailureResult(
          DatabaseFailure(
            'نسخه پایگاه داده فایل پشتیبان (${metadata.schemaVersion}) از نسخه فعلی برنامه (${AppConstants.databaseVersion}) جدیدتر است و قابل بازیابی نیست.',
          ),
        );
      }

      final cipherBase64 = package['cipher'];
      if (cipherBase64 is! String || cipherBase64.isEmpty) {
        return const FailureResult(
          SecurityFailure('محتوای رمزنگاری‌شده فایل پشتیبان نامعتبر است.'),
        );
      }

      String decryptedPayload;

      if (backupFormatVersion == 2 || backupFormatVersion == 3) {
        // V2 / V3: PBKDF2-HMAC-SHA256 + AES-256-GCM (v3 authenticates metadata)
        final rawKdf = package['kdf'];
        if (rawKdf is! Map) {
          return const FailureResult(
            SecurityFailure(
              'اطلاعات الگوریتم کلید در فایل پشتیبان نامعتبر است.',
            ),
          );
        }
        final kdfInfo = Map<String, dynamic>.from(rawKdf);
        if (kdfInfo['algorithm'] != 'PBKDF2-HMAC-SHA256') {
          return const FailureResult(
            SecurityFailure('الگوریتم کلید فایل پشتیبان پشتیبانی نمی‌شود.'),
          );
        }

        final rawIterations = kdfInfo['iterations'];
        if (rawIterations is! int ||
            rawIterations < minRestoreIterations ||
            rawIterations > maxRestoreIterations) {
          return const FailureResult(
            SecurityFailure(
              'تعداد تکرار کلید (KDF) در فایل پشتیبان نامعتبر یا خارج از محدوده مجاز است.',
            ),
          );
        }

        final Uint8List salt;
        final Uint8List nonce;
        final Uint8List cipherBytes;
        try {
          final saltB64 = kdfInfo['salt'];
          final nonceB64 = package['nonce'];
          if (saltB64 is! String || nonceB64 is! String) {
            return const FailureResult(
              SecurityFailure('پارامترهای رمزگشایی فایل پشتیبان نامعتبر است.'),
            );
          }
          salt = base64Decode(saltB64);
          nonce = base64Decode(nonceB64);
          cipherBytes = base64Decode(cipherBase64);
          if (salt.isEmpty ||
              nonce.length != _nonceLength ||
              cipherBytes.length < 16) {
            return const FailureResult(
              SecurityFailure('پارامترهای رمزگشایی فایل پشتیبان نامعتبر است.'),
            );
          }
        } catch (_) {
          return const FailureResult(
            SecurityFailure('پارامترهای رمزگشایی فایل پشتیبان نامعتبر است.'),
          );
        }

        final aad = backupFormatVersion == 3
            ? _canonicalMetadataAad(metadata)
            : Uint8List(0);

        try {
          final decryptedBytes = await _decryptGcmInIsolate(
            password: password,
            salt: salt,
            iterations: rawIterations,
            nonce: nonce,
            cipherWithTag: cipherBytes,
            aad: aad,
          );
          decryptedPayload = utf8.decode(decryptedBytes);
        } catch (e) {
          return const FailureResult(
            SecurityFailure(
              'رمز عبور پشتیبان اشتباه است یا فایل دستکاری شده است.',
            ),
          );
        }
      } else {
        // Legacy V1: sha256/md5 + AES-256-CBC
        try {
          decryptedPayload = await _decryptLegacyV1InIsolate(
            password: password,
            cipherBase64: cipherBase64,
          );
        } catch (e) {
          return const FailureResult(
            SecurityFailure(
              'رمز عبور پشتیبان اشتباه است یا فایل دستکاری شده است.',
            ),
          );
        }
      }

      // Verify Checksum
      final computedChecksum = sha256
          .convert(utf8.encode(decryptedPayload))
          .toString();
      if (computedChecksum != metadata.checksum) {
        return const FailureResult(
          SecurityFailure(
            'فایل پشتیبان معتبر نیست یا داده‌ها دستکاری شده‌اند (ناهماهنگی در چک‌سام).',
          ),
        );
      }

      final dataMap = jsonDecode(decryptedPayload) as Map<String, dynamic>;

      // Clean replacement inside atomic transaction:
      // 1. Wipe all existing tables in reverse dependency order.
      // 2. Insert all restored records.
      await _db.transaction(() async {
        await _db.delete(_db.accountingDocumentDetailLinksTable).go();
        await _db.delete(_db.recurringRulesTable).go();
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
            final acc = AccountData.fromJson(
              _withColumnDefaults(_db.accountsTable, item),
            );
            await _db.into(_db.accountsTable).insert(acc);
          }
        }

        // Categories
        if (dataMap.containsKey('categories')) {
          for (final item in (dataMap['categories'] as List)) {
            final cat = CategoryData.fromJson(
              _withColumnDefaults(_db.categoriesTable, item),
            );
            await _db.into(_db.categoriesTable).insert(cat);
          }
        }

        // Tags
        if (dataMap.containsKey('tags')) {
          for (final item in (dataMap['tags'] as List)) {
            final tag = TagData.fromJson(
              _withColumnDefaults(_db.tagsTable, item),
            );
            await _db.into(_db.tagsTable).insert(tag);
          }
        }

        // Transactions
        if (dataMap.containsKey('transactions')) {
          for (final item in (dataMap['transactions'] as List)) {
            final tx = TransactionData.fromJson(
              _withColumnDefaults(_db.transactionsTable, item),
            );
            await _db.into(_db.transactionsTable).insert(tx);
          }
        }

        // TransactionTags
        if (dataMap.containsKey('transactionTags')) {
          for (final item in (dataMap['transactionTags'] as List)) {
            final tt = TransactionTagData.fromJson(
              _withColumnDefaults(_db.transactionTagsTable, item),
            );
            await _db.into(_db.transactionTagsTable).insert(tt);
          }
        }

        // Budgets
        if (dataMap.containsKey('budgets')) {
          for (final item in (dataMap['budgets'] as List)) {
            final b = BudgetData.fromJson(
              _withColumnDefaults(_db.budgetsTable, item),
            );
            await _db.into(_db.budgetsTable).insert(b);
          }
        }

        // BudgetCategories
        if (dataMap.containsKey('budgetCategories')) {
          for (final item in (dataMap['budgetCategories'] as List)) {
            final bc = BudgetCategoryData.fromJson(
              _withColumnDefaults(_db.budgetCategoriesTable, item),
            );
            await _db.into(_db.budgetCategoriesTable).insert(bc);
          }
        }

        // Debts
        if (dataMap.containsKey('debts')) {
          for (final item in (dataMap['debts'] as List)) {
            final d = DebtReceivableData.fromJson(
              _withColumnDefaults(_db.debtsReceivablesTable, item),
            );
            await _db.into(_db.debtsReceivablesTable).insert(d);
          }
        }

        // Installments
        if (dataMap.containsKey('installments')) {
          for (final item in (dataMap['installments'] as List)) {
            final inst = InstallmentData.fromJson(
              _withColumnDefaults(_db.installmentsTable, item),
            );
            await _db.into(_db.installmentsTable).insert(inst);
          }
        }

        // Installment Payments
        if (dataMap.containsKey('installmentPayments')) {
          for (final item in (dataMap['installmentPayments'] as List)) {
            final ip = InstallmentPaymentData.fromJson(
              _withColumnDefaults(_db.installmentPaymentsTable, item),
            );
            await _db.into(_db.installmentPaymentsTable).insert(ip);
          }
        }

        // Checks
        if (dataMap.containsKey('checks')) {
          for (final item in (dataMap['checks'] as List)) {
            final chk = CheckData.fromJson(
              _withColumnDefaults(_db.checksTable, item),
            );
            await _db.into(_db.checksTable).insert(chk);
          }
        }

        // Assets
        if (dataMap.containsKey('assets')) {
          for (final item in (dataMap['assets'] as List)) {
            final ast = AssetData.fromJson(
              _withColumnDefaults(_db.assetsTable, item),
            );
            await _db.into(_db.assetsTable).insert(ast);
          }
        }

        // Financial Goals
        if (dataMap.containsKey('financialGoals')) {
          for (final item in (dataMap['financialGoals'] as List)) {
            final g = FinancialGoalData.fromJson(
              _withColumnDefaults(_db.financialGoalsTable, item),
            );
            await _db.into(_db.financialGoalsTable).insert(g);
          }
        }

        // Business Contacts
        if (dataMap.containsKey('contacts')) {
          for (final item in (dataMap['contacts'] as List)) {
            final c = BusinessContactData.fromJson(
              _withColumnDefaults(_db.businessContactsTable, item),
            );
            await _db.into(_db.businessContactsTable).insert(c);
          }
        }

        // Products
        if (dataMap.containsKey('products')) {
          for (final item in (dataMap['products'] as List)) {
            final pr = ProductData.fromJson(
              _withColumnDefaults(_db.productsTable, item),
            );
            await _db.into(_db.productsTable).insert(pr);
          }
        }

        // Inventory Logs
        if (dataMap.containsKey('inventoryLogs')) {
          for (final item in (dataMap['inventoryLogs'] as List)) {
            final il = InventoryLogData.fromJson(
              _withColumnDefaults(_db.inventoryLogsTable, item),
            );
            await _db.into(_db.inventoryLogsTable).insert(il);
          }
        }

        // Invoices
        if (dataMap.containsKey('invoices')) {
          for (final item in (dataMap['invoices'] as List)) {
            final inv = InvoiceData.fromJson(
              _withColumnDefaults(_db.invoicesTable, item),
            );
            await _db.into(_db.invoicesTable).insert(inv);
          }
        }

        // Invoice line items
        if (dataMap.containsKey('invoiceItems')) {
          for (final item in (dataMap['invoiceItems'] as List)) {
            final invItem = InvoiceItemData.fromJson(
              _withColumnDefaults(_db.invoiceItemsTable, item),
            );
            await _db.into(_db.invoiceItemsTable).insert(invItem);
          }
        }

        // Sync Queue
        if (dataMap.containsKey('syncQueue')) {
          for (final item in (dataMap['syncQueue'] as List)) {
            final sq = SyncQueueData.fromJson(
              _withColumnDefaults(_db.syncQueueTable, item),
            );
            await _db.into(_db.syncQueueTable).insert(sq);
          }
        }

        // Notifications
        if (dataMap.containsKey('notifications')) {
          for (final item in (dataMap['notifications'] as List)) {
            final n = NotificationData.fromJson(
              _withColumnDefaults(_db.notificationsTable, item),
            );
            await _db.into(_db.notificationsTable).insert(n);
          }
        }

        // Fiscal Years
        if (dataMap.containsKey('fiscalYears')) {
          for (final item in (dataMap['fiscalYears'] as List)) {
            final fy = FiscalYearData.fromJson(
              _withColumnDefaults(_db.fiscalYearsTable, item),
            );
            await _db.into(_db.fiscalYearsTable).insert(fy);
          }
        }

        // Accounting Subjects
        if (dataMap.containsKey('accountingSubjects')) {
          for (final item in (dataMap['accountingSubjects'] as List)) {
            final s = AccountingSubjectData.fromJson(
              _withColumnDefaults(_db.accountingSubjectsTable, item),
            );
            await _db.into(_db.accountingSubjectsTable).insert(s);
          }
        }

        // Accounting Documents
        if (dataMap.containsKey('accountingDocuments')) {
          for (final item in (dataMap['accountingDocuments'] as List)) {
            final d = AccountingDocumentData.fromJson(
              _withColumnDefaults(_db.accountingDocumentsTable, item),
            );
            await _db.into(_db.accountingDocumentsTable).insert(d);
          }
        }

        // Accounting Transactions
        if (dataMap.containsKey('accountingTransactions')) {
          for (final item in (dataMap['accountingTransactions'] as List)) {
            final at = AccountingTransactionData.fromJson(
              _withColumnDefaults(_db.accountingTransactionsTable, item),
            );
            await _db.into(_db.accountingTransactionsTable).insert(at);
          }
        }

        // Accounting Audit Logs
        if (dataMap.containsKey('accountingAuditLogs')) {
          for (final item in (dataMap['accountingAuditLogs'] as List)) {
            final al = AccountingAuditLogData.fromJson(
              _withColumnDefaults(_db.accountingAuditLogsTable, item),
            );
            await _db.into(_db.accountingAuditLogsTable).insert(al);
          }
        }

        // Accounting Detail Ledgers
        if (dataMap.containsKey('accountingDetailLedgers')) {
          for (final item in (dataMap['accountingDetailLedgers'] as List)) {
            final adl = AccountingDetailLedgerData.fromJson(
              _withColumnDefaults(_db.accountingDetailLedgersTable, item),
            );
            await _db.into(_db.accountingDetailLedgersTable).insert(adl);
          }
        }

        // Accounting Detail Values
        if (dataMap.containsKey('accountingDetailValues')) {
          for (final item in (dataMap['accountingDetailValues'] as List)) {
            final adv = AccountingDetailValueData.fromJson(
              _withColumnDefaults(_db.accountingDetailValuesTable, item),
            );
            await _db.into(_db.accountingDetailValuesTable).insert(adv);
          }
        }

        // Accounting Document Detail Links
        if (dataMap.containsKey('accountingDocumentDetailLinks')) {
          for (final item
              in (dataMap['accountingDocumentDetailLinks'] as List)) {
            final link = AccountingDocumentDetailLinkData.fromJson(
              _withColumnDefaults(_db.accountingDocumentDetailLinksTable, item),
            );
            await _db.into(_db.accountingDocumentDetailLinksTable).insert(link);
          }
        }

        // Recurring rules (v11)
        if (dataMap.containsKey('recurringRules')) {
          for (final item in (dataMap['recurringRules'] as List)) {
            final rule = RecurringRuleData.fromJson(
              _withColumnDefaults(_db.recurringRulesTable, item),
            );
            await _db.into(_db.recurringRulesTable).insert(rule);
          }
        }
      });

      return Success(metadata);
    } catch (e) {
      return FailureResult(DatabaseFailure('خطا در بازیابی اطلاعات: $e'));
    }
  }
}
