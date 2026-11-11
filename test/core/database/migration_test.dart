import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';

void main() {
  /// Minimal v1 base tables (excluding columns added in v6/v8/v9).
  void createV1Schema(dynamic rawDb) {
    rawDb.execute('''
      CREATE TABLE products (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        sku TEXT,
        barcode TEXT,
        description TEXT,
        unit TEXT NOT NULL DEFAULT 'unit',
        purchase_price_minor INTEGER NOT NULL DEFAULT 0,
        selling_price_minor INTEGER NOT NULL,
        currency TEXT NOT NULL,
        current_stock REAL NOT NULL DEFAULT 0.0,
        low_stock_threshold REAL NOT NULL DEFAULT 5.0,
        supplier_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_status INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 1
      );
    ''');
    rawDb.execute('''
      CREATE TABLE assets (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        cost_basis_minor INTEGER NOT NULL,
        current_value_minor INTEGER NOT NULL,
        currency TEXT NOT NULL,
        purchase_date INTEGER NOT NULL,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_status INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 1
      );
    ''');
    rawDb.execute('''
      CREATE TABLE accounts (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        currency TEXT NOT NULL,
        initial_balance_minor INTEGER NOT NULL DEFAULT 0,
        current_balance_minor INTEGER NOT NULL DEFAULT 0,
        card_number_last_four TEXT,
        bank_name TEXT,
        color_hex TEXT,
        icon_name TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        sync_status INTEGER NOT NULL DEFAULT 0,
        version INTEGER NOT NULL DEFAULT 1
      );
    ''');
  }

  test('upgrades cleanly from v1 -> v9 without duplicate column crash', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          createV1Schema(rawDb);
          rawDb.execute('PRAGMA user_version = 1;');
        },
      ),
    );
    addTearDown(db.close);

    // Trigger migration by querying a table created during v3/v5 and v1 tables
    final products = await db.select(db.productsTable).get();
    final goals = await db.select(db.financialGoalsTable).get();
    final txs = await db.select(db.accountingTransactionsTable).get();
    final fiscalYears = await db.select(db.fiscalYearsTable).get();
    final payments = await db.select(db.installmentPaymentsTable).get();
    final auditLogs = await db.select(db.accountingAuditLogsTable).get();

    expect(products, isEmpty);
    expect(goals, isEmpty);
    expect(txs, isEmpty);
    expect(fiscalYears, isEmpty);
    expect(payments, isEmpty);
    expect(auditLogs, isEmpty);

    // Verify new columns on products and assets exist and are selectable
    await db
        .into(db.productsTable)
        .insert(
          ProductsTableCompanion.insert(
            id: 'p1',
            name: 'کالا',
            sellingPriceMinor: 1000,
            currency: 'TOMAN',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final inserted = await db.select(db.productsTable).getSingle();
    expect(inserted.avgCostMinor, equals(0));
    expect(inserted.conversionFactor, equals(1));
  });

  test('upgrades cleanly from v2 -> v9 without duplicate column crash', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          createV1Schema(rawDb);
          rawDb.execute('''
            CREATE TABLE financial_goals (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              target_amount_minor INTEGER NOT NULL,
              current_amount_minor INTEGER NOT NULL DEFAULT 0,
              currency TEXT NOT NULL,
              target_date INTEGER,
              status TEXT NOT NULL,
              notes TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted_at INTEGER,
              sync_status INTEGER NOT NULL DEFAULT 0,
              version INTEGER NOT NULL DEFAULT 1
            );
          ''');
          rawDb.execute('PRAGMA user_version = 2;');
        },
      ),
    );
    addTearDown(db.close);

    expect(await db.select(db.accountingTransactionsTable).get(), isEmpty);
    expect(await db.select(db.assetsTable).get(), isEmpty);
  });

  test('upgrades cleanly from v3 -> v9 and adds sync columns to accounting_transactions & fiscal_years', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          createV1Schema(rawDb);
          rawDb.execute('''
            CREATE TABLE accounting_transactions (
              id TEXT NOT NULL PRIMARY KEY,
              document_id TEXT NOT NULL,
              subject_id TEXT NOT NULL,
              detail_subject_id TEXT,
              debit_minor_units INTEGER NOT NULL DEFAULT 0,
              credit_minor_units INTEGER NOT NULL DEFAULT 0,
              description TEXT NOT NULL,
              row_order INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
          rawDb.execute('''
            CREATE TABLE fiscal_years (
              id TEXT NOT NULL PRIMARY KEY,
              title TEXT NOT NULL,
              year_number INTEGER NOT NULL,
              start_date INTEGER NOT NULL,
              end_date INTEGER NOT NULL,
              is_closed INTEGER NOT NULL DEFAULT 0,
              is_active INTEGER NOT NULL DEFAULT 1,
              opening_document_id TEXT,
              closing_document_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
          rawDb.execute('PRAGMA user_version = 3;');
        },
      ),
    );
    addTearDown(db.close);

    // Selecting must succeed with deleted_at / sync_status / version added
    expect(await db.select(db.accountingTransactionsTable).get(), isEmpty);
    expect(await db.select(db.fiscalYearsTable).get(), isEmpty);
  });
}
