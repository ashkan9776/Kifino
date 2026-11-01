import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/repositories/goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  GoalRepositoryImpl(this._db);

  GoalEntity _toEntity(FinancialGoalData g) {
    final currency = Currency.fromCode(g.currency);
    return GoalEntity(
      id: g.id,
      name: g.name,
      targetAmount: Money.fromMinor(g.targetAmountMinor, currency),
      currentAmount: Money.fromMinor(g.currentAmountMinor, currency),
      status: GoalStatus.fromCode(g.status),
      targetDate: g.targetDate != null ? DateTime.fromMillisecondsSinceEpoch(g.targetDate!) : null,
      notes: g.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(g.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(g.updatedAt),
      deletedAt: g.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(g.deletedAt!) : null,
      syncStatus: g.syncStatus,
      version: g.version,
    );
  }

  @override
  Stream<List<GoalEntity>> watchGoals() {
    final query = _db.select(_db.financialGoalsTable)
      ..where((tbl) => tbl.deletedAt.isNull())
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Result<GoalEntity>> createGoal(GoalEntity goal) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final gId = goal.id.isEmpty ? _uuid.v4() : goal.id;

      await _db.transaction(() async {
        final companion = FinancialGoalsTableCompanion.insert(
          id: gId,
          name: goal.name,
          targetAmountMinor: goal.targetAmount.minorUnits,
          currentAmountMinor: Value(goal.currentAmount.minorUnits),
          currency: goal.targetAmount.currency.code,
          targetDate: Value(goal.targetDate?.millisecondsSinceEpoch),
          status: goal.status.code,
          notes: Value(goal.notes),
          createdAt: now,
          updatedAt: now,
          syncStatus: const Value(1), // Pending sync
        );

        await _db.into(_db.financialGoalsTable).insert(companion);

        // Push to Outbox Sync Queue
        final idempotencyKey = _uuid.v4();
        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'financial_goals',
                entityId: gId,
                operation: 'INSERT',
                payloadJson: jsonEncode({
                  'id': gId,
                  'name': goal.name,
                  'target_amount_minor': goal.targetAmount.minorUnits,
                  'current_amount_minor': goal.currentAmount.minorUnits,
                  'currency': goal.targetAmount.currency.code,
                  'target_date': goal.targetDate?.millisecondsSinceEpoch,
                  'status': goal.status.code,
                  'notes': goal.notes,
                }),
                idempotencyKey: idempotencyKey,
                queuedAt: now,
              ),
            );
      });

      final created = await (_db.select(_db.financialGoalsTable)..where((t) => t.id.equals(gId))).getSingle();
      return Success(_toEntity(created));
    } catch (e) {
      return DatabaseFailure('ساخت هدف انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<GoalEntity>> contributeToGoal(String id, Money amount) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final row = await (_db.select(_db.financialGoalsTable)..where((t) => t.id.equals(id))).getSingle();

        final newCurrent = row.currentAmountMinor + amount.minorUnits;
        final newStatus =
            newCurrent >= row.targetAmountMinor ? GoalStatus.achieved.code : GoalStatus.active.code;

        await (_db.update(_db.financialGoalsTable)..where((t) => t.id.equals(id))).write(
          FinancialGoalsTableCompanion(
            currentAmountMinor: Value(newCurrent),
            status: Value(newStatus),
            updatedAt: Value(now),
            version: Value(row.version + 1),
            syncStatus: const Value(2), // Pending update
          ),
        );

        // Push to Outbox Sync Queue
        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'financial_goals',
                entityId: id,
                operation: 'UPDATE',
                payloadJson: jsonEncode({
                  'id': id,
                  'contribution_minor': amount.minorUnits,
                  'new_current_minor': newCurrent,
                  'status': newStatus,
                }),
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      final updated = await (_db.select(_db.financialGoalsTable)..where((t) => t.id.equals(id))).getSingle();
      return Success(_toEntity(updated));
    } catch (e) {
      return DatabaseFailure('ثبت پس‌انداز انجام نشد. دوباره تلاش کنید.').asFailure();
    }
  }

  @override
  Future<Result<void>> updateGoal(GoalEntity goal) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.financialGoalsTable)..where((tbl) => tbl.id.equals(goal.id))).write(
        FinancialGoalsTableCompanion(
          name: Value(goal.name),
          targetAmountMinor: Value(goal.targetAmount.minorUnits),
          targetDate: Value(goal.targetDate?.millisecondsSinceEpoch),
          notes: Value(goal.notes),
          updatedAt: Value(now),
        ),
      );

      await _db.into(_db.syncQueueTable).insert(
            SyncQueueTableCompanion.insert(
              syncEntityName: 'goals',
              entityId: goal.id,
              operation: 'UPDATE',
              payloadJson: '{"id":"${goal.id}","target":${goal.targetAmount.minorUnits}}',
              idempotencyKey: _uuid.v4(),
              queuedAt: now,
            ),
          );

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('ویرایش هدف انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> deleteGoal(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        await (_db.update(_db.financialGoalsTable)..where((t) => t.id.equals(id))).write(
          FinancialGoalsTableCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value(3), // Pending delete
          ),
        );

        // Push to Outbox Sync Queue
        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'financial_goals',
                entityId: id,
                operation: 'DELETE',
                payloadJson: jsonEncode({'id': id}),
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف هدف انجام نشد.').asFailure();
    }
  }
}
