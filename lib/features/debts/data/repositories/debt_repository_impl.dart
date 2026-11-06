import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/debt_entity.dart';
import '../../domain/repositories/debt_repository.dart';

class DebtRepositoryImpl implements DebtRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  DebtRepositoryImpl(this._db);

  DebtEntity _toEntity(DebtReceivableData data) {
    final currency = Currency.fromCode(data.currency);
    return DebtEntity(
      id: data.id,
      contactName: data.contactName,
      contactPhone: data.contactPhone,
      type: DebtType.fromCode(data.type),
      totalAmount: Money.fromMinor(data.totalAmountMinor, currency),
      paidAmount: Money.fromMinor(data.paidAmountMinor, currency),
      dueDate: data.dueDate != null
          ? DateTime.fromMillisecondsSinceEpoch(data.dueDate!)
          : null,
      status: DebtStatus.fromCode(data.status),
      notes: data.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
      deletedAt: data.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!)
          : null,
    );
  }

  @override
  Stream<List<DebtEntity>> watchDebts({DebtType? type}) {
    final query = _db.select(_db.debtsReceivablesTable)
      ..where((tbl) {
        Expression<bool> predicate = tbl.deletedAt.isNull();
        if (type != null) {
          predicate = predicate & tbl.type.equals(type.code);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Result<List<DebtEntity>>> getDebts({DebtType? type}) async {
    try {
      final query = _db.select(_db.debtsReceivablesTable)
        ..where((tbl) {
          Expression<bool> predicate = tbl.deletedAt.isNull();
          if (type != null) {
            predicate = predicate & tbl.type.equals(type.code);
          }
          return predicate;
        })
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

      final rows = await query.get();
      return Success(rows.map(_toEntity).toList());
    } catch (e) {
      return DatabaseFailure('خواندن بدهی‌ها انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<DebtEntity>> createDebt(DebtEntity debt) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final dId = debt.id.isEmpty ? _uuid.v4() : debt.id;

      await _db.transaction(() async {
        final companion = DebtsReceivablesTableCompanion.insert(
          id: dId,
          contactName: debt.contactName,
          contactPhone: Value(debt.contactPhone),
          type: debt.type.code,
          totalAmountMinor: debt.totalAmount.minorUnits,
          paidAmountMinor: Value(debt.paidAmount.minorUnits),
          currency: debt.totalAmount.currency.code,
          dueDate: Value(debt.dueDate?.millisecondsSinceEpoch),
          status: debt.status.code,
          notes: Value(debt.notes),
          createdAt: now,
          updatedAt: now,
        );

        await _db.into(_db.debtsReceivablesTable).insert(companion);

        // Outbox Sync Queue
        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'debts_receivables',
                entityId: dId,
                operation: 'INSERT',
                payloadJson:
                    '{"id":"$dId","contact":"${debt.contactName}","amount":${debt.totalAmount.minorUnits}}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return Success(debt.copyWith(id: dId));
    } catch (e) {
      return DatabaseFailure('ثبت بدهی/طلب انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> addPayment(String id, Money paymentAmount) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final existing = await (_db.select(
          _db.debtsReceivablesTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();

        if (existing == null || existing.deletedAt != null) {
          throw StateError('بدهی/طلب پیدا نشد.');
        }
        if (paymentAmount.minorUnits <= 0) {
          throw ArgumentError('مبلغ پرداخت باید بیشتر از صفر باشد.');
        }

        final newPaidMinor =
            existing.paidAmountMinor + paymentAmount.minorUnits;
        final newStatus = newPaidMinor >= existing.totalAmountMinor
            ? DebtStatus.settled.code
            : existing.status;

        await (_db.update(
          _db.debtsReceivablesTable,
        )..where((t) => t.id.equals(id))).write(
          DebtsReceivablesTableCompanion(
            paidAmountMinor: Value(newPaidMinor),
            status: Value(newStatus),
            updatedAt: Value(now),
          ),
        );

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'debts_receivables',
                entityId: id,
                operation: 'UPDATE',
                payloadJson:
                    '{"id":"$id","payment":${paymentAmount.minorUnits},"newPaid":$newPaidMinor}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      if (e is ArgumentError) return DatabaseFailure(e.message.toString()).asFailure();
      if (e is StateError) return DatabaseFailure(e.message).asFailure();
      return DatabaseFailure('ثبت پرداخت انجام نشد. دوباره تلاش کنید.')
          .asFailure();
    }
  }

  @override
  Future<Result<void>> updateDebt(DebtEntity debt) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.debtsReceivablesTable,
      )..where((tbl) => tbl.id.equals(debt.id))).write(
        DebtsReceivablesTableCompanion(
          contactName: Value(debt.contactName),
          contactPhone: Value(debt.contactPhone),
          totalAmountMinor: Value(debt.totalAmount.minorUnits),
          dueDate: Value(debt.dueDate?.millisecondsSinceEpoch),
          notes: Value(debt.notes),
          updatedAt: Value(now),
        ),
      );

      await _db
          .into(_db.syncQueueTable)
          .insert(
            SyncQueueTableCompanion.insert(
              syncEntityName: 'debts_receivables',
              entityId: debt.id,
              operation: 'UPDATE',
              payloadJson:
                  '{"id":"${debt.id}","total":${debt.totalAmount.minorUnits}}',
              idempotencyKey: _uuid.v4(),
              queuedAt: now,
            ),
          );

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('ویرایش بدهی/طلب انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> updateDebtStatus(String id, DebtStatus status) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.debtsReceivablesTable,
      )..where((t) => t.id.equals(id))).write(
        DebtsReceivablesTableCompanion(
          status: Value(status.code),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('تغییر وضعیت انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> deleteDebt(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.debtsReceivablesTable,
      )..where((t) => t.id.equals(id))).write(
        DebtsReceivablesTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف بدهی انجام نشد.').asFailure();
    }
  }
}
