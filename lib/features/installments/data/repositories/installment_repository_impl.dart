import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/text_normalizer.dart';

import '../../../../core/database/account_balance.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/installment_entity.dart';
import '../../domain/entities/installment_payment_entity.dart';
import '../../domain/repositories/installment_repository.dart';
import '../../domain/services/installment_schedule.dart';

class InstallmentRepositoryImpl implements InstallmentRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  InstallmentRepositoryImpl(this._db);

  /// Due date of installment #1 — stored since v10, inferred for older rows.
  DateTime _firstDue(InstallmentData inst) {
    if (inst.firstDueDate != null) {
      return DateTime.fromMillisecondsSinceEpoch(inst.firstDueDate!);
    }
    return InstallmentSchedule.inferFirstDue(
      nextDue: DateTime.fromMillisecondsSinceEpoch(inst.nextDueDate),
      intervalDays: inst.recurrenceIntervalDays,
      paidCount: inst.paidInstallmentsCount,
    );
  }

  /// Next due date once [paidCount] installments are paid.
  int _nextDueAfter(InstallmentData inst, int paidCount) {
    final index = paidCount >= inst.numberOfInstallments
        ? inst.numberOfInstallments
        : paidCount + 1;
    return InstallmentSchedule.dueDateFor(
      firstDue: _firstDue(inst),
      intervalDays: inst.recurrenceIntervalDays,
      index: index,
    ).millisecondsSinceEpoch;
  }

  /// Takes [amountMinor] (in the plan's currency) out of the linked account.
  Future<void> _debitAccount(
    InstallmentData inst,
    int amountMinor,
    int now,
  ) async {
    await applyAccountBalanceDelta(
      _db,
      accountId: inst.accountId,
      delta: Money.fromMinor(-amountMinor, Currency.fromCode(inst.currency)),
      now: now,
    );
  }

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
      deletedAt: data.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(data.deletedAt!)
          : null,
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
  Future<Result<InstallmentEntity>> createInstallment(
    InstallmentEntity installment,
  ) async {
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
          firstDueDate: Value(
            InstallmentSchedule.inferFirstDue(
              nextDue: installment.nextDueDate,
              intervalDays: installment.recurrenceIntervalDays,
              paidCount: installment.paidInstallmentsCount,
            ).millisecondsSinceEpoch,
          ),
          status: installment.status.code,
          notes: Value(installment.notes),
          createdAt: now,
          updatedAt: now,
        );

        await _db.into(_db.installmentsTable).insert(companion);

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'installments',
                entityId: instId,
                operation: 'INSERT',
                payloadJson: jsonEncode({
                  'id': instId,
                  'title': installment.title,
                  'total': installment.totalAmount.minorUnits,
                }),
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
        final inst = await (_db.select(
          _db.installmentsTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (inst == null || inst.deletedAt != null) {
          throw StateError('قسط پیدا نشد.');
        }
        // Guard in the repository, not just the UI: a double tap or a stale
        // screen must never pay more installments than the plan has.
        if (inst.status == InstallmentStatus.completed.code ||
            inst.paidInstallmentsCount >= inst.numberOfInstallments) {
          throw StateError('این قسط قبلاً کامل پرداخت شده است.');
        }

        final nextPaidCount = inst.paidInstallmentsCount + 1;
        final isCompleted = nextPaidCount >= inst.numberOfInstallments;
        final nextDueEpoch = _nextDueAfter(inst, nextPaidCount);

        await (_db.update(
          _db.installmentsTable,
        )..where((t) => t.id.equals(id))).write(
          InstallmentsTableCompanion(
            paidInstallmentsCount: Value(nextPaidCount),
            nextDueDate: Value(nextDueEpoch),
            status: Value(
              isCompleted ? InstallmentStatus.completed.code : inst.status,
            ),
            updatedAt: Value(now),
          ),
        );

        // Deduct balance from linked account (Toman/Rial aware)
        await _debitAccount(inst, inst.installmentAmountMinor, now);

        // Ledger integrity: the money left the account, so the payment must
        // exist as a real expense transaction — otherwise analytics and the
        // transaction list never see installment payments.
        final txId = _uuid.v4();
        await _db
            .into(_db.transactionsTable)
            .insert(
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
                sourceType: const Value('installment'),
                sourceId: Value(id),
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
                payloadJson: jsonEncode({
                  'id': txId,
                  'account_id': inst.accountId,
                  'amount_minor': inst.installmentAmountMinor,
                  'currency': inst.currency,
                  'type': 'expense',
                }),
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );

        // Payment history row (Phase 3 rework) — reviewable & correctable.
        await _db
            .into(_db.installmentPaymentsTable)
            .insert(
              InstallmentPaymentsTableCompanion.insert(
                id: _uuid.v4(),
                installmentId: id,
                amountMinor: inst.installmentAmountMinor,
                installmentIndex: nextPaidCount,
                ledgerTransactionId: Value(txId),
                notes: const Value('پرداخت عادی'),
                paidAt: now,
                createdAt: now,
              ),
            );

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'installments',
                entityId: id,
                operation: 'UPDATE',
                payloadJson: jsonEncode({
                  'id': id,
                  'paidCount': nextPaidCount,
                  'isCompleted': isCompleted,
                }),
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      if (e is StateError) return DatabaseFailure(e.message).asFailure();
      return DatabaseFailure('پرداخت قسط انجام نشد. دوباره تلاش کنید.')
          .asFailure();
    }
  }

  @override
  Future<Result<void>> deleteInstallment(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.installmentsTable,
      )..where((t) => t.id.equals(id))).write(
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

  @override
  Future<Result<void>> payRemaining(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final inst = await (_db.select(
          _db.installmentsTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (inst == null) throw StateError('قسط پیدا نشد.');
        if (inst.status == InstallmentStatus.completed.code) {
          throw StateError('این قسط قبلاً کامل پرداخت شده است.');
        }

        final remainingCount =
            inst.numberOfInstallments - inst.paidInstallmentsCount;
        if (remainingCount <= 0) {
          throw StateError('قسط پرداخت‌نشده‌ای باقی نمانده.');
        }
        final remainingMinor = inst.installmentAmountMinor * remainingCount;

        // Update plan state: fully paid.
        await (_db.update(
          _db.installmentsTable,
        )..where((t) => t.id.equals(id))).write(
          InstallmentsTableCompanion(
            paidInstallmentsCount: Value(inst.numberOfInstallments),
            nextDueDate: Value(_nextDueAfter(inst, inst.numberOfInstallments)),
            status: const Value('completed'),
            updatedAt: Value(now),
          ),
        );

        // Deduct the remaining total once (Toman/Rial aware).
        await _debitAccount(inst, remainingMinor, now);

        // Dedicated expense transaction & history row for every settled قسط.
        // 1:1 ledger pairing guarantees that deleting one payment later reverts
        // only that specific installment's transaction without destroying the
        // transactions of the other settled installments.
        for (
          var i = inst.paidInstallmentsCount + 1;
          i <= inst.numberOfInstallments;
          i++
        ) {
          final txId = _uuid.v4();
          await _db
              .into(_db.transactionsTable)
              .insert(
                TransactionsTableCompanion.insert(
                  id: txId,
                  accountId: inst.accountId,
                  type: 'expense',
                  amountMinor: inst.installmentAmountMinor,
                  currency: inst.currency,
                  transactionDate: now,
                  description: TextNormalizer.auto(
                    'تسویه قسط ${inst.title} — $i از ${inst.numberOfInstallments}',
                  ),
                  sourceType: const Value('installment'),
                  sourceId: Value(id),
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
                  payloadJson: jsonEncode({
                    'id': txId,
                    'account_id': inst.accountId,
                    'amount_minor': inst.installmentAmountMinor,
                    'type': 'expense',
                  }),
                  idempotencyKey: _uuid.v4(),
                  queuedAt: now,
                ),
              );

          await _db
              .into(_db.installmentPaymentsTable)
              .insert(
                InstallmentPaymentsTableCompanion.insert(
                  id: _uuid.v4(),
                  installmentId: id,
                  amountMinor: inst.installmentAmountMinor,
                  installmentIndex: i,
                  ledgerTransactionId: Value(txId),
                  notes: const Value('تسویه کامل'),
                  paidAt: now,
                  createdAt: now,
                ),
              );
        }

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'installments',
                entityId: id,
                operation: 'UPDATE',
                payloadJson: jsonEncode({
                  'id': id,
                  'paidRemaining': remainingMinor,
                  'count': remainingCount,
                }),
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      if (e is StateError) return DatabaseFailure(e.message).asFailure();
      return DatabaseFailure('تسویه کامل انجام نشد. دوباره تلاش کنید.')
          .asFailure();
    }
  }

  @override
  Future<Result<void>> updateInstallment(InstallmentEntity installment) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(
        _db.installmentsTable,
      )..where((tbl) => tbl.id.equals(installment.id))).write(
        InstallmentsTableCompanion(
          title: Value(installment.title),
          totalAmountMinor: Value(installment.totalAmount.minorUnits),
          installmentAmountMinor: Value(
            installment.installmentAmount.minorUnits,
          ),
          numberOfInstallments: Value(installment.numberOfInstallments),
          recurrenceIntervalDays: Value(installment.recurrenceIntervalDays),
          nextDueDate: Value(installment.nextDueDate.millisecondsSinceEpoch),
          // The user may move the next due date or change the interval:
          // re-anchor the schedule on what they chose.
          firstDueDate: Value(
            InstallmentSchedule.inferFirstDue(
              nextDue: installment.nextDueDate,
              intervalDays: installment.recurrenceIntervalDays,
              paidCount: installment.paidInstallmentsCount,
            ).millisecondsSinceEpoch,
          ),
          notes: Value(installment.notes),
          updatedAt: Value(now),
        ),
      );

      await _db
          .into(_db.syncQueueTable)
          .insert(
            SyncQueueTableCompanion.insert(
              syncEntityName: 'installments',
              entityId: installment.id,
              operation: 'UPDATE',
              payloadJson: jsonEncode({
                'id': installment.id,
                'title': installment.title,
                'total': installment.totalAmount.minorUnits,
              }),
              idempotencyKey: _uuid.v4(),
              queuedAt: now,
            ),
          );

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('ویرایش قسط انجام نشد.').asFailure();
    }
  }

  @override
  Future<List<InstallmentPaymentEntity>> getPaymentHistory(
    String installmentId,
  ) async {
    final query = _db.select(_db.installmentPaymentsTable)
      ..where(
        (tbl) =>
            tbl.installmentId.equals(installmentId) & tbl.deletedAt.isNull(),
      )
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.paidAt)]);
    final rows = await query.get();
    return rows
        .map(
          (r) => InstallmentPaymentEntity(
            id: r.id,
            installmentId: r.installmentId,
            amountMinor: r.amountMinor,
            installmentIndex: r.installmentIndex,
            ledgerTransactionId: r.ledgerTransactionId,
            notes: r.notes,
            paidAt: DateTime.fromMillisecondsSinceEpoch(r.paidAt),
          ),
        )
        .toList();
  }

  @override
  Future<Result<void>> deletePayment(String paymentId) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final payment = await (_db.select(
          _db.installmentPaymentsTable,
        )..where((tbl) => tbl.id.equals(paymentId))).getSingleOrNull();
        if (payment == null || payment.deletedAt != null) return;

        final inst =
            await (_db.select(_db.installmentsTable)
                  ..where((tbl) => tbl.id.equals(payment.installmentId)))
                .getSingleOrNull();
        if (inst == null) return;

        // 1. Money returns to the linked account (Toman/Rial aware).
        await _debitAccount(inst, -payment.amountMinor, now);

        // 2. The linked ledger expense is soft-deleted (reverts analytics).
        final txId = payment.ledgerTransactionId;
        if (txId != null) {
          await (_db.update(
            _db.transactionsTable,
          )..where((tbl) => tbl.id.equals(txId))).write(
            TransactionsTableCompanion(
              deletedAt: Value(now),
              updatedAt: Value(now),
              syncStatus: const Value(3),
            ),
          );
        }

        // 3. Drop the history row and recompute plan state.
        await (_db.update(_db.installmentPaymentsTable)
              ..where((tbl) => tbl.id.equals(paymentId)))
            .write(InstallmentPaymentsTableCompanion(deletedAt: Value(now)));

        final newPaidCount = (inst.paidInstallmentsCount - 1).clamp(
          0,
          inst.numberOfInstallments,
        );
        final isCompleted = newPaidCount >= inst.numberOfInstallments;
        // Anchored on the first due date — the old formula used the plan's
        // creation date, which is not when installment #1 is due.
        final nextDueEpoch = _nextDueAfter(inst, newPaidCount);

        await (_db.update(
          _db.installmentsTable,
        )..where((tbl) => tbl.id.equals(inst.id))).write(
          InstallmentsTableCompanion(
            paidInstallmentsCount: Value(newPaidCount),
            nextDueDate: Value(nextDueEpoch),
            status: Value(
              isCompleted
                  ? InstallmentStatus.completed.code
                  : InstallmentStatus.ongoing.code,
            ),
            updatedAt: Value(now),
          ),
        );

        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'installments',
                entityId: inst.id,
                operation: 'UPDATE',
                payloadJson: jsonEncode({
                  'id': inst.id,
                  'deletedPayment': paymentId,
                  'paidCount': newPaidCount,
                }),
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف پرداخت انجام نشد.').asFailure();
    }
  }
}
