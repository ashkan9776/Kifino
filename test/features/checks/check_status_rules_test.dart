import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/features/checks/data/repositories/check_repository_impl.dart';
import 'package:kifino/features/checks/domain/entities/check_entity.dart';

/// Accountant-grade check status tests: symmetric balance reconciliation
/// (cleared applies, leaving cleared reverts) and the audit trail for status
/// corrections — a mis-tap on «وصول شد» must be fully undoable.
void main() {
  late AppDatabase db;
  late CheckRepositoryImpl repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CheckRepositoryImpl(db);

    await db.into(db.accountsTable).insertOnConflictUpdate(
      AccountsTableCompanion.insert(
        id: 'acc-bank',
        name: 'بانک ملت',
        type: 'bankCard',
        currency: 'TOMAN',
        initialBalanceMinor: const Value(50000000),
        currentBalanceMinor: const Value(50000000),
        createdAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
        updatedAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      ),
    );

    await db.into(db.checksTable).insertOnConflictUpdate(
      ChecksTableCompanion.insert(
        id: 'ch-1',
        checkNumber: '123456',
        bankName: 'ملت',
        type: 'received', // چک دریافتی
        amountMinor: 20000000,
        currency: 'TOMAN',
        partyName: 'مشتری الف',
        dueDate: DateTime(2026, 3, 1).millisecondsSinceEpoch,
        status: 'pending',
        accountId: const Value('acc-bank'),
        createdAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
        updatedAt: DateTime(2026, 1, 1).millisecondsSinceEpoch,
      ),
    );
  });

  tearDown(() async => db.close());

  Future<int> accountBalance() async {
    final rows = await db.select(db.accountsTable).get();
    return rows.first.currentBalanceMinor;
  }

  test('cleared received check adds money to the account', () async {
    final res = await repo.updateCheckStatus('ch-1', CheckStatus.cleared);
    expect(res.isSuccess, isTrue);
    expect(await accountBalance(), equals(70000000)); // 50M + 20M
  });

  test('status correction (cleared → pending) REVERTS the money', () async {
    await repo.updateCheckStatus('ch-1', CheckStatus.cleared);
    expect(await accountBalance(), equals(70000000));

    // Mis-tap corrected: back to pending.
    await repo.updateCheckStatus('ch-1', CheckStatus.pending);
    expect(await accountBalance(), equals(50000000));
  });

  test('cleared → bounced also reverts the money', () async {
    await repo.updateCheckStatus('ch-1', CheckStatus.cleared);
    await repo.updateCheckStatus('ch-1', CheckStatus.bounced);
    expect(await accountBalance(), equals(50000000));
  });

  test('issued check clearing deducts money and correction reverts it', () async {
    await (db.update(db.checksTable)..where((tbl) => tbl.id.equals('ch-1')))
        .write(const ChecksTableCompanion(type: Value('issued')));

    await repo.updateCheckStatus('ch-1', CheckStatus.cleared);
    expect(await accountBalance(), equals(30000000)); // 50M − 20M

    await repo.updateCheckStatus('ch-1', CheckStatus.pending);
    expect(await accountBalance(), equals(50000000));
  });

  test('every status change writes an audit entry with before/after', () async {
    await repo.updateCheckStatus('ch-1', CheckStatus.cleared);
    await repo.updateCheckStatus('ch-1', CheckStatus.pending);

    final logs = await (db.select(db.accountingAuditLogsTable)
          ..where((tbl) =>
              (tbl.entityType.equals('check')) &
              (tbl.entityId.equals('ch-1'))))
        .get();

    expect(logs.length, equals(2));
    expect(logs.last.beforeJson, contains('"status":"cleared"'));
    expect(logs.last.afterJson, contains('"status":"pending"'));
  });

  test('status change to the SAME status is a no-op (no audit spam)', () async {
    await repo.updateCheckStatus('ch-1', CheckStatus.pending);
    final logs = await (db.select(db.accountingAuditLogsTable)
          ..where((tbl) => tbl.entityType.equals('check')))
        .get();
    expect(logs, isEmpty);
  });
}
