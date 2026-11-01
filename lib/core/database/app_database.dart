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

@DriftDatabase(tables: [
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
])
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
          if (from < 7) {
            await m.createTable(installmentPaymentsTable);
          }
          if (from < 6) {
            // Warehouse light (Phase 3): secondary unit + conversion factor.
            await m.addColumn(productsTable, productsTable.secondaryUnit);
            await m.addColumn(productsTable, productsTable.conversionFactor);
          }
          if (from < 5) {
            await m.createTable(accountingAuditLogsTable);
            await m.createTable(accountingDetailLedgersTable);
            await m.createTable(accountingDetailValuesTable);
            await m.createTable(accountingDocumentDetailLinksTable);
          }
          if (from < 4) {
            // Sync-readiness for the accounting tables added in v3.
            await m.addColumn(accountingTransactionsTable,
                accountingTransactionsTable.deletedAt);
            await m.addColumn(accountingTransactionsTable,
                accountingTransactionsTable.syncStatus);
            await m.addColumn(accountingTransactionsTable,
                accountingTransactionsTable.version);
            await m.addColumn(
                fiscalYearsTable, fiscalYearsTable.deletedAt);
            await m.addColumn(fiscalYearsTable, fiscalYearsTable.syncStatus);
            await m.addColumn(fiscalYearsTable, fiscalYearsTable.version);
          }
        },
      );

  static LazyDatabase _openConnection(String? companyDbName) {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      // companyDbName is already the final file name (mapped once in
      // ServiceLocator.init) — never re-wrap it.
      final file = File(p.join(dbFolder.path, companyDbName ?? 'kifino_local.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
