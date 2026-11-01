import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/check_entity.dart';
import '../../domain/repositories/check_repository.dart';

class CheckRepositoryImpl implements CheckRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  CheckRepositoryImpl(this._db);

  CheckEntity _toEntity(CheckData data) {
    final currency = Currency.fromCode(data.currency);
    return CheckEntity(
      id: data.id,
      checkNumber: data.checkNumber,
      sayadiId: data.sayadiId,
      bankName: data.bankName,
      type: CheckType.fromCode(data.type),
      amount: Money.fromMinor(data.amountMinor, currency),
      partyName: data.partyName,
      dueDate: DateTime.fromMillisecondsSinceEpoch(data.dueDate),
      accountId: data.accountId,
      status: CheckStatus.fromCode(data.status),
      frontImagePath: data.frontImagePath,
      backImagePath: data.backImagePath,
      notes: data.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
      deletedAt: data.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!)
          : null,
    );
  }

  @override
  Stream<List<CheckEntity>> watchChecks({CheckType? type}) {
    final query = _db.select(_db.checksTable)
      ..where((tbl) {
        Expression<bool> predicate = tbl.deletedAt.isNull();
        if (type != null) {
          predicate = predicate & tbl.type.equals(type.code);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Result<List<CheckEntity>>> getChecks({CheckType? type}) async {
    try {
      final query = _db.select(_db.checksTable)
        ..where((tbl) {
          Expression<bool> predicate = tbl.deletedAt.isNull();
          if (type != null) {
            predicate = predicate & tbl.type.equals(type.code);
          }
          return predicate;
        })
        ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);

      final rows = await query.get();
      return Success(rows.map(_toEntity).toList());
    } catch (e) {
      return DatabaseFailure('خواندن چک‌ها انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<CheckEntity>> createCheck(CheckEntity check) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cId = check.id.isEmpty ? _uuid.v4() : check.id;

      await _db.transaction(() async {
        final companion = ChecksTableCompanion.insert(
          id: cId,
          checkNumber: check.checkNumber,
          sayadiId: Value(check.sayadiId),
          bankName: check.bankName,
          type: check.type.code,
          amountMinor: check.amount.minorUnits,
          currency: check.amount.currency.code,
          partyName: check.partyName,
          dueDate: check.dueDate.millisecondsSinceEpoch,
          accountId: Value(check.accountId),
          status: check.status.code,
          frontImagePath: Value(check.frontImagePath),
          backImagePath: Value(check.backImagePath),
          notes: Value(check.notes),
          createdAt: now,
          updatedAt: now,
        );

        await _db.into(_db.checksTable).insert(companion);

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'checks',
                entityId: cId,
                operation: 'INSERT',
                payloadJson:
                    '{"id":"$cId","checkNumber":"${check.checkNumber}","amount":${check.amount.minorUnits}}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return Success(check.copyWith(id: cId));
    } catch (e) {
      return DatabaseFailure('ثبت چک انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> updateCheck(CheckEntity check) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.checksTable,
      )..where((tbl) => tbl.id.equals(check.id))).write(
        ChecksTableCompanion(
          checkNumber: Value(check.checkNumber),
          sayadiId: Value(check.sayadiId),
          bankName: Value(check.bankName),
          partyName: Value(check.partyName),
          amountMinor: Value(check.amount.minorUnits),
          dueDate: Value(check.dueDate.millisecondsSinceEpoch),
          accountId: Value(check.accountId),
          notes: Value(check.notes),
          updatedAt: Value(now),
        ),
      );

      await _db
          .into(_db.syncQueueTable)
          .insert(
            SyncQueueTableCompanion.insert(
              syncEntityName: 'checks',
              entityId: check.id,
              operation: 'UPDATE',
              payloadJson:
                  '{"id":"${check.id}","amount":${check.amount.minorUnits},"number":"${check.checkNumber}"}',
              idempotencyKey: _uuid.v4(),
              queuedAt: now,
            ),
          );

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('ویرایش چک انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> updateCheckStatus(String id, CheckStatus status) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final check = await (_db.select(
          _db.checksTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (check == null) throw Exception('Check not found');
        if (check.status == status.code) return; // no-op

        // Symmetric balance reconciliation (Phase: accountant rework):
        // entering cleared applies the money movement, LEAVING cleared
        // (correction or bounce) reverts it — so a mis-tap is fully undoable.
        final wasCleared = check.status == CheckStatus.cleared.code;
        final nowCleared = status == CheckStatus.cleared;
        if (check.accountId != null && wasCleared != nowCleared) {
          final account = await (_db.select(
            _db.accountsTable,
          )..where((t) => t.id.equals(check.accountId!))).getSingleOrNull();
          if (account != null) {
            final isIssued = check.type == CheckType.issued.code;
            // Signed effect: issued cleared = money out (−), received cleared = money in (+).
            final signedDiff = isIssued
                ? -check.amountMinor
                : check.amountMinor;
            final applied = nowCleared ? signedDiff : -signedDiff;
            await (_db.update(
              _db.accountsTable,
            )..where((t) => t.id.equals(account.id))).write(
              AccountsTableCompanion(
                currentBalanceMinor: Value(
                  account.currentBalanceMinor + applied,
                ),
                updatedAt: Value(now),
              ),
            );

            final txId = 'cheque_tx_${check.id}';
            if (nowCleared) {
              final serial = check.checkNumber.isNotEmpty
                  ? check.checkNumber
                  : (check.sayadiId ?? '');
              final desc = isIssued
                  ? 'پاس شدن چک شماره $serial در وجه ${check.partyName}'
                  : 'وصول چک شماره $serial از ${check.partyName}';
              await _db
                  .into(_db.transactionsTable)
                  .insertOnConflictUpdate(
                    TransactionsTableCompanion.insert(
                      id: txId,
                      accountId: check.accountId!,
                      type: isIssued ? 'expense' : 'income',
                      amountMinor: check.amountMinor,
                      currency: check.currency,
                      transactionDate: now,
                      description: desc,
                      notes: Value('cheque:${check.id}'),
                      createdAt: now,
                      updatedAt: now,
                      syncStatus: const Value(1),
                    ),
                  );
              await _db
                  .into(_db.syncQueueTable)
                  .insert(
                    SyncQueueTableCompanion.insert(
                      syncEntityName: 'transactions',
                      entityId: txId,
                      operation: 'INSERT',
                      payloadJson:
                          '{"id":"$txId","account_id":"${check.accountId}","amount_minor":${check.amountMinor},"currency":"${check.currency}","type":"${isIssued ? "expense" : "income"}"}',
                      idempotencyKey: _uuid.v4(),
                      queuedAt: now,
                    ),
                  );
            } else {
              await (_db.update(
                _db.transactionsTable,
              )..where((t) => t.id.equals(txId))).write(
                TransactionsTableCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                  syncStatus: const Value(3),
                ),
              );
              await _db
                  .into(_db.syncQueueTable)
                  .insert(
                    SyncQueueTableCompanion.insert(
                      syncEntityName: 'transactions',
                      entityId: txId,
                      operation: 'DELETE',
                      payloadJson: '{"id":"$txId"}',
                      idempotencyKey: _uuid.v4(),
                      queuedAt: now,
                    ),
                  );
            }
          }
        }

        await (_db.update(
          _db.checksTable,
        )..where((t) => t.id.equals(id))).write(
          ChecksTableCompanion(
            status: Value(status.code),
            updatedAt: Value(now),
          ),
        );

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'checks',
                entityId: id,
                operation: 'UPDATE',
                payloadJson: '{"id":"$id","status":"${status.code}"}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );

        // Audit trail for status corrections (before/after).
        await _db
            .into(_db.accountingAuditLogsTable)
            .insert(
              AccountingAuditLogsTableCompanion.insert(
                id: _uuid.v4(),
                entityType: 'check',
                entityId: id,
                action: 'update',
                beforeJson: Value('{"status":"${check.status}"}'),
                afterJson: Value('{"status":"${status.code}"}'),
                description: Value(
                  'تغییر وضعیت چک ${check.checkNumber} از ${check.status} به ${status.code}',
                ),
                performedAt: now,
                createdAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('تغییر وضعیت چک انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> deleteCheck(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        final check = await (_db.select(
          _db.checksTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (check != null && check.deletedAt == null) {
          if (check.status == CheckStatus.cleared.code &&
              check.accountId != null) {
            final account = await (_db.select(
              _db.accountsTable,
            )..where((t) => t.id.equals(check.accountId!))).getSingleOrNull();
            if (account != null) {
              final isIssued = check.type == CheckType.issued.code;
              final signedDiff = isIssued
                  ? -check.amountMinor
                  : check.amountMinor;
              await (_db.update(
                _db.accountsTable,
              )..where((t) => t.id.equals(account.id))).write(
                AccountsTableCompanion(
                  currentBalanceMinor: Value(
                    account.currentBalanceMinor - signedDiff,
                  ),
                  updatedAt: Value(now),
                ),
              );
              final txId = 'cheque_tx_${check.id}';
              await (_db.update(
                _db.transactionsTable,
              )..where((t) => t.id.equals(txId))).write(
                TransactionsTableCompanion(
                  deletedAt: Value(now),
                  updatedAt: Value(now),
                  syncStatus: const Value(3),
                ),
              );
            }
          }
          await (_db.update(
            _db.checksTable,
          )..where((t) => t.id.equals(id))).write(
            ChecksTableCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );
        }
      });
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف چک انجام نشد.').asFailure();
    }
  }
}
