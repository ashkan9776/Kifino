import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/text_normalizer.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/installment_entity.dart';
import '../../domain/repositories/installment_repository.dart';

class InstallmentRepositoryImpl implements InstallmentRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  InstallmentRepositoryImpl(this._db);

  InstallmentEntity _toEntity(InstallmentData data) {
    final currency = Currency.fromCode(data.currency);
    return InstallmentEntity(
      id: data.id,
      title: data.title,
      accountId: data.accountId,
      totalAmount: Money.fromMinor(data.totalAmountMinor, currency),
      numberOfInstallments: data.numberOfInstallments,
      paidInstallmentsCount: data.paidInstallmentsCount,
      installmentAmount: Money.fromMinor(data.installmentAmountMinor, currency),
      startDate: DateTime.fromMillisecondsSinceEpoch(data.startDate),
      recurrenceIntervalDays: data.recurrenceIntervalDays,
      nextDueDate: DateTime.fromMillisecondsSinceEpoch(data.nextDueDate),
      status: InstallmentStatus.fromCode(data.status),
      notes: data.notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data.updatedAt),
      deletedAt: data.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!) : null,
    );
  }

  @override
  Stream<List<InstallmentEntity>> watchInstallments() {
    final query = _db.select(_db.installmentsTable)
      ..where((tbl) => tbl.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.nextDueDate)]);

    return query.watch().map((rows) => rows.map(_toEntity).toList());
  }

  @override
  Future<Result<List<InstallmentEntity>>> getInstallments() async {
    try {
      final query = _db.select(_db.installmentsTable)
        ..where((tbl) => tbl.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.asc(t.nextDueDate)]);

      final rows = await query.get();
      return Success(rows.map(_toEntity).toList());
    } catch (e) {
      return DatabaseFailure('خواندن اقساط انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<InstallmentEntity>> createInstallment(InstallmentEntity installment) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final instId = installment.id.isEmpty ? _uuid.v4() : installment.id;

      await _db.transaction(() async {
        final companion = InstallmentsTableCompanion.insert(
          id: instId,
          title: installment.title,
          accountId: installment.accountId,
          totalAmountMinor: installment.totalAmount.minorUnits,
          currency: installment.totalAmount.currency.code,
          numberOfInstallments: installment.numberOfInstallments,
          paidInstallmentsCount: Value(installment.paidInstallmentsCount),
          installmentAmountMinor: installment.installmentAmount.minorUnits,
          startDate: installment.startDate.millisecondsSinceEpoch,
          recurrenceIntervalDays: Value(installment.recurrenceIntervalDays),
          nextDueDate: installment.nextDueDate.millisecondsSinceEpoch,
          status: installment.status.code,
          notes: Value(installment.notes),
          createdAt: now,
          updatedAt: now,
        );

        await _db.into(_db.installmentsTable).insert(companion);

        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'installments',
                entityId: instId,
                operation: 'INSERT',
                payloadJson: '{"id":"$instId","title":"${installment.title}","total":${installment.totalAmount.minorUnits}}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return Success(installment.copyWith(id: instId));
    } catch (e) {
      return DatabaseFailure('ثبت قسط انجام نشد.').asFailure();
    }
  }

  @override
  Future<Result<void>> payNextInstallment(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final inst = await (_db.select(_db.installmentsTable)..where((t) => t.id.equals(id))).getSingleOrNull();
        if (inst == null) throw Exception('Installment not found');

        final nextPaidCount = inst.paidInstallmentsCount + 1;
        final isCompleted = nextPaidCount >= inst.numberOfInstallments;
        final nextDueEpoch = inst.nextDueDate + (inst.recurrenceIntervalDays * 86400000);

        await (_db.update(_db.installmentsTable)..where((t) => t.id.equals(id))).write(
          InstallmentsTableCompanion(
            paidInstallmentsCount: Value(nextPaidCount),
            nextDueDate: Value(nextDueEpoch),
            status: Value(isCompleted ? InstallmentStatus.completed.code : inst.status),
            updatedAt: Value(now),
          ),
        );

        // Deduct balance from linked account
        final account = await (_db.select(_db.accountsTable)..where((t) => t.id.equals(inst.accountId))).getSingleOrNull();
        if (account != null) {
          final newBalance = account.currentBalanceMinor - inst.installmentAmountMinor;
          await (_db.update(_db.accountsTable)..where((t) => t.id.equals(inst.accountId))).write(
            AccountsTableCompanion(
              currentBalanceMinor: Value(newBalance),
              updatedAt: Value(now),
            ),
          );
        }

        // Ledger integrity: the money left the account, so the payment must
        // exist as a real expense transaction — otherwise analytics and the
        // transaction list never see installment payments.
        final txId = _uuid.v4();
        await _db.into(_db.transactionsTable).insert(
              TransactionsTableCompanion.insert(
                id: txId,
                accountId: inst.accountId,
                type: 'expense',
                amountMinor: inst.installmentAmountMinor,
                currency: inst.currency,
                transactionDate: now,
                description: TextNormalizer.auto(
                  'قسط ${inst.title} — $nextPaidCount از ${inst.numberOfInstallments}',
                ),
                createdAt: now,
                updatedAt: now,
                syncStatus: const Value(1),
              ),
            );
        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'transactions',
                entityId: txId,
                operation: 'INSERT',
                payloadJson:
                    '{"id":"$txId","account_id":"${inst.accountId}","amount_minor":${inst.installmentAmountMinor},"currency":"${inst.currency}","type":"expense"}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );

        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'installments',
                entityId: id,
                operation: 'UPDATE',
                payloadJson: '{"id":"$id","paidCount":$nextPaidCount,"isCompleted":$isCompleted}',
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('پرداخت قسط انجام نشد. دوباره تلاش کنید.').asFailure();
    }
  }

  @override
  Future<Result<void>> deleteInstallment(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.installmentsTable)..where((t) => t.id.equals(id))).write(
        InstallmentsTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف قسط انجام نشد.').asFailure();
    }
  }
}
