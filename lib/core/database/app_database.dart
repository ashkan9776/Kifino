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
  AccountingAuditLogsTable,
  AccountingDetailLedgersTable,
  AccountingDetailValuesTable,
  AccountingDocumentDetailLinksTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

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

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, AppConstants.databaseName));
      return NativeDatabase.createInBackground(file);
    });
  }
}
