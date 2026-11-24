import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';

/// v9 → v10 adds transaction source links (and backfills them for check and
/// installment transactions), sync_queue.last_attempt_at and
/// installments.first_due_date.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kifino_mig10_');
    file = File('${dir.path}/company.db');

    // 1. Build a database with data, using the current schema…
    final seed = AppDatabase(NativeDatabase(file));
    Future<void> tx(String id) => seed
        .into(seed.transactionsTable)
        .insert(
          TransactionsTableCompanion.insert(
            id: id,
            accountId: 'acc',
            type: 'expense',
            amountMinor: 100,
            currency: 'TOMAN',
            transactionDate: 1,
            description: id,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await tx('cheque_tx_chk-7');
    await tx('inst-tx-1');
    await tx('manual-1');
    await seed
        .into(seed.installmentPaymentsTable)
        .insert(
          InstallmentPaymentsTableCompanion.insert(
            id: 'pay-1',
            installmentId: 'plan-9',
            amountMinor: 100,
            installmentIndex: 1,
            ledgerTransactionId: const Value('inst-tx-1'),
            paidAt: 1,
            createdAt: 1,
          ),
        );
    await seed.close();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('upgrades from v9 and backfills check/installment links', () async {
    // 2. …then turn it back into a v9 file before drift opens it.
    final db = AppDatabase(
      NativeDatabase(
        file,
        setup: (dynamic raw) {
          final version =
              (raw.select('PRAGMA user_version').first['user_version'] as int);
          if (version != 10) return;
          raw.execute('ALTER TABLE transactions DROP COLUMN source_type');
          raw.execute('ALTER TABLE transactions DROP COLUMN source_id');
          raw.execute('ALTER TABLE sync_queue DROP COLUMN last_attempt_at');
          raw.execute('ALTER TABLE installments DROP COLUMN first_due_date');
          raw.execute('PRAGMA user_version = 9');
        },
      ),
    );
    addTearDown(db.close);

    final rows = {
      for (final r in await db.select(db.transactionsTable).get()) r.id: r,
    };
    expect(rows['cheque_tx_chk-7']!.sourceType, 'check');
    expect(rows['cheque_tx_chk-7']!.sourceId, 'chk-7');
    expect(rows['inst-tx-1']!.sourceType, 'installment');
    expect(rows['inst-tx-1']!.sourceId, 'plan-9');
    expect(rows['manual-1']!.sourceType, isNull);

    expect(await db.select(db.syncQueueTable).get(), isEmpty);
    expect(await db.select(db.installmentsTable).get(), isEmpty);
  });
}
