import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/constants/app_constants.dart';
import 'package:kifino/core/database/app_database.dart';

/// v11 → v12 creates 23 secondary SQLite indexes across core transactional,
/// accounting, business, check, installment, sync and notification tables.
void main() {
  const expectedIndexes = <String, Map<String, List<String>>>{
    'transactions': {
      'idx_transactions_deleted_date': ['deleted_at', 'transaction_date'],
      'idx_transactions_account_deleted': ['account_id', 'deleted_at'],
      'idx_transactions_dest_account_deleted': [
        'destination_account_id',
        'deleted_at',
      ],
      'idx_transactions_category_deleted': ['category_id', 'deleted_at'],
      'idx_transactions_source': ['source_type', 'source_id'],
    },
    'accounting_documents': {
      'idx_accounting_docs_fy_deleted_date': [
        'fiscal_year_id',
        'deleted_at',
        'date',
      ],
      'idx_accounting_docs_ref': ['reference_type', 'reference_id'],
    },
    'accounting_transactions': {
      'idx_accounting_tx_doc_deleted': ['document_id', 'deleted_at'],
      'idx_accounting_tx_subject_deleted': ['subject_id', 'deleted_at'],
    },
    'accounting_subjects': {
      'idx_accounting_subjects_code': ['code'],
      'idx_accounting_subjects_parent': ['parent_id'],
    },
    'accounting_document_detail_links': {
      'idx_accounting_doc_detail_doc': ['document_id'],
      'idx_accounting_doc_detail_ledger_val': ['ledger_id', 'value_id'],
    },
    'invoices': {
      'idx_invoices_contact_deleted': ['contact_id', 'deleted_at'],
      'idx_invoices_type_status_deleted': ['type', 'status', 'deleted_at'],
      'idx_invoices_due_date': ['due_date'],
    },
    'invoice_items': {
      'idx_invoice_items_invoice_deleted': ['invoice_id', 'deleted_at'],
      'idx_invoice_items_product': ['product_id'],
    },
    'inventory_logs': {
      'idx_inventory_logs_product_created': ['product_id', 'created_at'],
    },
    'installment_payments': {
      'idx_installment_payments_inst_deleted': ['installment_id', 'deleted_at'],
    },
    'checks': {
      'idx_checks_status_due_deleted': ['status', 'due_date', 'deleted_at'],
    },
    'sync_queue': {
      'idx_sync_queue_queued_at': ['queued_at'],
    },
    'audit_notifications': {
      'idx_notifications_read_scheduled': ['is_read', 'scheduled_for'],
    },
  };

  Future<void> verifyAllExpectedIndexes(AppDatabase db) async {
    for (final entry in expectedIndexes.entries) {
      final tableName = entry.key;
      final indexRows = await db
          .customSelect('PRAGMA index_list($tableName)')
          .get();
      final indexNames = indexRows.map((r) => r.read<String>('name')).toSet();

      for (final idxEntry in entry.value.entries) {
        final indexName = idxEntry.key;
        final expectedColumns = idxEntry.value;

        expect(
          indexNames,
          contains(indexName),
          reason: 'Expected index $indexName on table $tableName',
        );

        final infoRows = await db
            .customSelect('PRAGMA index_info($indexName)')
            .get();
        final sorted = [
          ...infoRows,
        ]..sort((a, b) => a.read<int>('seqno').compareTo(b.read<int>('seqno')));
        final actualColumns = sorted
            .map((r) => r.read<String>('name'))
            .toList();
        expect(
          actualColumns,
          equals(expectedColumns),
          reason: 'Columns mismatch for index $indexName on $tableName',
        );
      }
    }
  }

  test(
    'fresh v12 database has schemaVersion 12 and all expected indexes',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(AppConstants.databaseVersion, equals(12));
      expect(db.schemaVersion, equals(12));

      final versionRow = await db
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(versionRow.read<int>('user_version'), equals(12));

      await verifyAllExpectedIndexes(db);
    },
  );

  test('upgrades v11 database to v12 idempotently while preserving existing rows', () async {
    final tempDir = await Directory.systemTemp.createTemp('kifino_mig12_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final dbFile = File('${tempDir.path}/company.db');

    // 1. Seed a real database with sample rows and drop all secondary
    //    indexes to simulate an existing v11 installation.
    final seed = AppDatabase(NativeDatabase(dbFile));
    await seed
        .into(seed.accountsTable)
        .insert(
          AccountsTableCompanion.insert(
            id: 'acc-1',
            name: 'بانک',
            type: 'bankCard',
            currency: 'TOMAN',
            createdAt: 10,
            updatedAt: 10,
          ),
        );
    await seed
        .into(seed.transactionsTable)
        .insert(
          TransactionsTableCompanion.insert(
            id: 'tx-v11',
            accountId: 'acc-1',
            type: 'expense',
            amountMinor: 250000,
            currency: 'TOMAN',
            transactionDate: 1000,
            description: 'تراکنش نسخه ۱۱',
            createdAt: 10,
            updatedAt: 10,
          ),
        );
    await seed
        .into(seed.notificationsTable)
        .insert(
          NotificationsTableCompanion.insert(
            id: 'n-v11',
            title: 'سررسید',
            body: 'متن',
            type: 'checkDue',
            scheduledFor: 2000,
            createdAt: 10,
          ),
        );
    await seed.close();

    // 2. Rewind the file back to v11 (no custom indexes except one pre-created
    //    to verify IF NOT EXISTS idempotency).
    final upgraded = AppDatabase(
      NativeDatabase(
        dbFile,
        setup: (dynamic raw) {
          final ver =
              raw.select('PRAGMA user_version').first['user_version'] as int;
          if (ver != 12) return;
          final rows = raw.select(
            "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
          );
          var keptOne = false;
          for (final row in rows) {
            final name = row['name'] as String;
            if (!keptOne && name == 'idx_sync_queue_queued_at') {
              keptOne = true;
              continue; // leave one index present to test idempotent upgrade
            }
            raw.execute('DROP INDEX IF EXISTS "$name"');
          }
          raw.execute('PRAGMA user_version = 11');
        },
      ),
    );
    addTearDown(upgraded.close);

    // Verify upgraded version and rows
    final versionRow = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(versionRow.read<int>('user_version'), equals(12));

    await verifyAllExpectedIndexes(upgraded);

    final tx = await (upgraded.select(
      upgraded.transactionsTable,
    )..where((t) => t.id.equals('tx-v11'))).getSingle();
    expect(tx.description, equals('تراکنش نسخه ۱۱'));
    expect(tx.amountMinor, equals(250000));

    final notif = await upgraded
        .customSelect(
          'SELECT title FROM audit_notifications WHERE id = ?',
          variables: [Variable.withString('n-v11')],
        )
        .getSingle();
    expect(notif.read<String>('title'), equals('سررسید'));
  });
}
