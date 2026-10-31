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
      deletedAt: data.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!) : null,
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

        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'checks',
                entityId: cId,
                operation: 'INSERT',
                payloadJson: '{"id":"$cId","checkNumber":"${check.checkNumber}","amount":${check.amount.minorUnits}}',
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
  Future<Result<void>> updateCheckStatus(String id, CheckStatus status) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final check = await (_db.select(_db.checksTable)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (check == null) throw Exception('Check not found');

        // Reconcile balance if cleared
        if (status == CheckStatus.cleared && check.status != CheckStatus.cleared.code && check.accountId != null) {
          final account = await (_db.select(_db.accountsTable)..where((t) => t.id.equals(check.accountId!))).getSingleOrNull();
          if (account != null) {
            final isIssued = check.type == CheckType.issued.code;
            final diff = isIssued ? -check.amountMinor : check.amountMinor;
            final newBalance = account.currentBalanceMinor + diff;

            await (_db.update(_db.accountsTable)..where((t) => t.id.equals(account.id))).write(
              AccountsTableCompanion(
                currentBalanceMinor: Value(newBalance),
                updatedAt: Value(now),
              ),
            );
          }
        }

        await (_db.update(_db.checksTable)..where((t) => t.id.equals(id))).write(
          ChecksTableCompanion(
            status: Value(status.code),
            updatedAt: Value(now),
          ),
        );

        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'checks',
                entityId: id,
                operation: 'UPDATE',
                payloadJson: '{"id":"$id","status":"${status.code}"}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
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
      await (_db.update(_db.checksTable)..where((t) => t.id.equals(id))).write(
        ChecksTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف چک انجام نشد.').asFailure();
    }
  }
}
