import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import 'tables/account_tables.dart';
import 'tables/accounting_tables.dart';
import 'tables/budget_debt_tables.dart';
import 'tables/business_tables.dart';
import 'tables/goal_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/transaction_tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AccountsTable,
    CategoriesTable,
    TagsTable,
    TransactionsTable,
    TransactionTagsTable,
    BudgetsTable,
    BudgetCategoriesTable,
    DebtsReceivablesTable,
    InstallmentsTable,
    ChecksTable,
    AssetsTable,
    FinancialGoalsTable,
    BusinessContactsTable,
    ProductsTable,
    InventoryLogsTable,
    InvoicesTable,
    InvoiceItemsTable,
    SyncQueueTable,
    NotificationsTable,
    AccountingSubjectsTable,
    AccountingDocumentsTable,
    AccountingTransactionsTable,
    FiscalYearsTable,
    InstallmentPaymentsTable,
    AccountingAuditLogsTable,
    AccountingDetailLedgersTable,
    AccountingDetailValuesTable,
    AccountingDocumentDetailLinksTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// [companyDbName] selects the company file (Phase 5). When null the
  /// default company's legacy file (kifino_local.db) is used, so existing
  /// installs keep their data. Tests pass an explicit [executor] instead.
  AppDatabase([QueryExecutor? executor, String? companyDbName])
    : super(executor ?? _openConnection(companyDbName));

  @override
  int get schemaVersion => AppConstants.databaseVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(financialGoalsTable);
      }
      if (from < 3) {
        await m.createTable(accountingSubjectsTable);
        await m.createTable(accountingDocumentsTable);
        await m.createTable(accountingTransactionsTable);
        await m.createTable(fiscalYearsTable);
      }
      if (from == 3) {
        // Sync-readiness for the accounting tables added in v3.
        await _addColumnIfMissing(
          m,
          accountingTransactionsTable,
          accountingTransactionsTable.deletedAt,
        );
        await _addColumnIfMissing(
          m,
          accountingTransactionsTable,
          accountingTransactionsTable.syncStatus,
        );
        await _addColumnIfMissing(
          m,
          accountingTransactionsTable,
          accountingTransactionsTable.version,
        );
        await _addColumnIfMissing(
          m,
          fiscalYearsTable,
          fiscalYearsTable.deletedAt,
        );
        await _addColumnIfMissing(
          m,
          fiscalYearsTable,
          fiscalYearsTable.syncStatus,
        );
        await _addColumnIfMissing(
          m,
          fiscalYearsTable,
          fiscalYearsTable.version,
        );
      }
      if (from < 5) {
        await m.createTable(accountingAuditLogsTable);
        await m.createTable(accountingDetailLedgersTable);
        await m.createTable(accountingDetailValuesTable);
        await m.createTable(accountingDocumentDetailLinksTable);
      }
      if (from < 6) {
        // Warehouse light (Phase 3): secondary unit + conversion factor.
        await _addColumnIfMissing(
          m,
          productsTable,
          productsTable.secondaryUnit,
        );
        await _addColumnIfMissing(
          m,
          productsTable,
          productsTable.conversionFactor,
        );
      }
      if (from < 7) {
        await m.createTable(installmentPaymentsTable);
      }
      if (from < 8) {
        await _addColumnIfMissing(m, assetsTable, assetsTable.customTypeName);
      }
      if (from < 9) {
        // Phase 1 COGS: weighted-average unit cost per product.
        await _addColumnIfMissing(m, productsTable, productsTable.avgCostMinor);
      }
      if (from < 10) {
        // Source links: auto-generated transactions remember their owner.
        await _addColumnIfMissing(
          m,
          transactionsTable,
          transactionsTable.sourceType,
        );
        await _addColumnIfMissing(
          m,
          transactionsTable,
          transactionsTable.sourceId,
        );
        await _addColumnIfMissing(
          m,
          syncQueueTable,
          syncQueueTable.lastAttemptAt,
        );
        await _addColumnIfMissing(
          m,
          installmentsTable,
          installmentsTable.firstDueDate,
        );
        await _backfillTransactionSources();
      }
    },
  );

  /// Links transactions that installments and checks created before v10 to
  /// their owners, so they get the same edit/delete protection as new ones.
  /// Debt and goal payments from before v10 carry no reliable link and stay
  /// as ordinary transactions.
  Future<void> _backfillTransactionSources() async {
    if (!await _tableExists('transactions')) return;
    if (await _tableExists('installment_payments')) {
      await customStatement('''
        UPDATE transactions
        SET source_type = 'installment',
            source_id = (
              SELECT ip.installment_id FROM installment_payments ip
              WHERE ip.ledger_transaction_id = transactions.id
              LIMIT 1
            )
        WHERE source_type IS NULL
          AND id IN (
            SELECT ledger_transaction_id FROM installment_payments
            WHERE ledger_transaction_id IS NOT NULL
          )
      ''');
    }
    await customStatement('''
      UPDATE transactions
      SET source_type = 'check', source_id = substr(id, 11)
      WHERE source_type IS NULL AND id LIKE 'cheque\\_tx\\_%' ESCAPE '\\'
    ''');
  }

  Future<bool> _tableExists(String name) async {
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(name)],
    ).get();
    return rows.isNotEmpty;
  }

  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    final cols = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    // An empty result means the table itself does not exist (only possible
    // on partial test schemas) — there is nothing to alter then.
    if (cols.isEmpty) return;
    final existing = cols.map((r) => r.read<String>('name')).toSet();
    if (!existing.contains(column.name)) {
      await m.addColumn(table, column);
    }
  }

  static LazyDatabase _openConnection(String? companyDbName) {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      // companyDbName is already the final file name (mapped once in
      // ServiceLocator.init) — never re-wrap it.
      final file = File(
        p.join(dbFolder.path, companyDbName ?? 'kifino_local.db'),
      );
      return NativeDatabase.createInBackground(file);
    });
  }
}
