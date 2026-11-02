import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  TransactionRepositoryImpl(this._db);

  TransactionEntity _toEntity(
    TransactionData tx, {
    String? accountName,
    String? destAccountName,
    String? categoryName,
    int? categoryIconCodePoint,
    String? categoryColorHex,
  }) {
    final currency = Currency.fromCode(tx.currency);
    return TransactionEntity(
      id: tx.id,
      accountId: tx.accountId,
      destinationAccountId: tx.destinationAccountId,
      categoryId: tx.categoryId,
      amount: Money.fromMinor(tx.amountMinor, currency),
      type: TransactionType.fromCode(tx.type),
      date: DateTime.fromMillisecondsSinceEpoch(tx.transactionDate),
      description: tx.description,
      notes: tx.notes,
      isBusiness: tx.isBusiness,
      attachmentUri: tx.attachmentUri,
      createdAt: DateTime.fromMillisecondsSinceEpoch(tx.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(tx.updatedAt),
      deletedAt: tx.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(tx.deletedAt!)
          : null,
      syncStatus: tx.syncStatus,
      version: tx.version,
      accountName: accountName,
      destinationAccountName: destAccountName,
      categoryName: categoryName,
      categoryIconCodePoint: categoryIconCodePoint,
      categoryColorHex: categoryColorHex,
    );
  }

  @override
  Stream<List<TransactionEntity>> watchTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? accountId,
    String? categoryId,
    bool? isBusiness,
    int? limit,
    int? offset,
  }) {
    // Custom join between transactions, accounts, and categories
    final query = _db.select(_db.transactionsTable).join([
      leftOuterJoin(
        _db.accountsTable,
        _db.accountsTable.id.equalsExp(_db.transactionsTable.accountId),
      ),
      leftOuterJoin(
        _db.categoriesTable,
        _db.categoriesTable.id.equalsExp(_db.transactionsTable.categoryId),
      ),
    ]);

    query.where(_db.transactionsTable.deletedAt.isNull());

    if (startDate != null) {
      query.where(
        _db.transactionsTable.transactionDate.isBiggerOrEqualValue(
          startDate.millisecondsSinceEpoch,
        ),
      );
    }
    if (endDate != null) {
      query.where(
        _db.transactionsTable.transactionDate.isSmallerOrEqualValue(
          endDate.millisecondsSinceEpoch,
        ),
      );
    }
    if (accountId != null) {
      query.where(_db.transactionsTable.accountId.equals(accountId));
    }
    if (categoryId != null) {
      query.where(_db.transactionsTable.categoryId.equals(categoryId));
    }
    if (isBusiness != null) {
      query.where(_db.transactionsTable.isBusiness.equals(isBusiness));
    }

    query.orderBy([OrderingTerm.desc(_db.transactionsTable.transactionDate)]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.watch().map((rows) {
      return rows.map((row) {
        final tx = row.readTable(_db.transactionsTable);
        final acc = row.readTableOrNull(_db.accountsTable);
        final cat = row.readTableOrNull(_db.categoriesTable);

        return _toEntity(
          tx,
          accountName: acc?.name,
          categoryName: cat?.name,
          categoryIconCodePoint: cat?.iconCodePoint,
          categoryColorHex: cat?.colorHex,
        );
      }).toList();
    });
  }

  @override
  Stream<TransactionEntity?> watchTransactionById(String id) {
    final query = _db.select(_db.transactionsTable)
      ..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().map(
      (row) => row != null ? _toEntity(row) : null,
    );
  }

  void _validateTransaction(TransactionEntity transaction) {
    if (transaction.type == TransactionType.transfer) {
      if (transaction.destinationAccountId == null ||
          transaction.destinationAccountId!.trim().isEmpty) {
        throw ArgumentError('انتقال وجه نیازمند انتخاب حساب مقصد است.');
      }
      if (transaction.accountId == transaction.destinationAccountId) {
        throw ArgumentError('حساب مبدأ و مقصد در انتقال نمی‌تواند یکسان باشد.');
      }
    }
  }

  /// Applies or reverses the balance effect of [tx].
  /// When [reverse] is true, inverts the balance change.
  Future<void> _applyBalanceEffect(
    TransactionEntity tx, {
    required int now,
    bool reverse = false,
  }) async {
    // 1. Source Account
    final sourceAccount = await (_db.select(
      _db.accountsTable,
    )..where((t) => t.id.equals(tx.accountId))).getSingle();
    final sourceCurrency = Currency.fromCode(sourceAccount.currency);
    Money effectiveAmount = tx.amount;
    if (effectiveAmount.currency != sourceCurrency) {
      if (effectiveAmount.isCompatibleWith(sourceCurrency)) {
        effectiveAmount = effectiveAmount.normalizeTo(sourceCurrency);
      } else {
        throw StateError(
          'Currency mismatch: transaction ${effectiveAmount.currency.code} vs source account ${sourceCurrency.code}',
        );
      }
    }

    int sourceDiff = 0;
    if (tx.type == TransactionType.expense ||
        tx.type == TransactionType.debtPayment) {
      sourceDiff = reverse
          ? effectiveAmount.minorUnits
          : -effectiveAmount.minorUnits;
    } else if (tx.type == TransactionType.income ||
        tx.type == TransactionType.receivablePayment) {
      sourceDiff = reverse
          ? -effectiveAmount.minorUnits
          : effectiveAmount.minorUnits;
    } else if (tx.type == TransactionType.transfer) {
      sourceDiff = reverse
          ? effectiveAmount.minorUnits
          : -effectiveAmount.minorUnits;
    }

    await (_db.update(
      _db.accountsTable,
    )..where((t) => t.id.equals(sourceAccount.id))).write(
      AccountsTableCompanion(
        currentBalanceMinor: Value(
          sourceAccount.currentBalanceMinor + sourceDiff,
        ),
        updatedAt: Value(now),
      ),
    );

    // 2. Destination Account (for transfers)
    if (tx.type == TransactionType.transfer &&
        tx.destinationAccountId != null) {
      final destAccount = await (_db.select(
        _db.accountsTable,
      )..where((t) => t.id.equals(tx.destinationAccountId!))).getSingle();
      final destCurrency = Currency.fromCode(destAccount.currency);
      Money destEffectiveAmount = tx.amount;
      if (destEffectiveAmount.currency != destCurrency) {
        if (destEffectiveAmount.isCompatibleWith(destCurrency)) {
          destEffectiveAmount = destEffectiveAmount.normalizeTo(destCurrency);
        } else {
          throw StateError(
            'Currency mismatch: transaction ${destEffectiveAmount.currency.code} vs destination account ${destCurrency.code}',
          );
        }
      }

      final destDiff = reverse
          ? -destEffectiveAmount.minorUnits
          : destEffectiveAmount.minorUnits;
      await (_db.update(
        _db.accountsTable,
      )..where((t) => t.id.equals(destAccount.id))).write(
        AccountsTableCompanion(
          currentBalanceMinor: Value(
            destAccount.currentBalanceMinor + destDiff,
          ),
          updatedAt: Value(now),
        ),
      );
    }
  }

  @override
  Future<Result<TransactionEntity>> createTransaction(
    TransactionEntity transaction,
  ) async {
    try {
      _validateTransaction(transaction);
      final now = DateTime.now().millisecondsSinceEpoch;
      final txId = transaction.id.isEmpty ? _uuid.v4() : transaction.id;

      await _db.transaction(() async {
        // 1. Currency safety net: validate source account currency
        final sourceAccount = await (_db.select(
          _db.accountsTable,
        )..where((t) => t.id.equals(transaction.accountId))).getSingle();
        final accountCurrency = Currency.fromCode(sourceAccount.currency);
        Money effectiveAmount = transaction.amount;
        if (effectiveAmount.currency != accountCurrency) {
          if (effectiveAmount.isCompatibleWith(accountCurrency)) {
            effectiveAmount = effectiveAmount.normalizeTo(accountCurrency);
          } else {
            throw StateError(
              'Currency mismatch: transaction ${effectiveAmount.currency.code} vs account ${accountCurrency.code}',
            );
          }
        }

        // Validate destination currency compatibility if transfer
        if (transaction.type == TransactionType.transfer &&
            transaction.destinationAccountId != null) {
          final destAccount =
              await (_db.select(_db.accountsTable)..where(
                    (t) => t.id.equals(transaction.destinationAccountId!),
                  ))
                  .getSingle();
          final destCurrency = Currency.fromCode(destAccount.currency);
          if (transaction.amount.currency != destCurrency &&
              !transaction.amount.isCompatibleWith(destCurrency)) {
            throw StateError(
              'Currency mismatch: transaction ${transaction.amount.currency.code} vs destination account ${destCurrency.code}',
            );
          }
        }

        // 2. Insert transaction
        final companion = TransactionsTableCompanion.insert(
          id: txId,
          accountId: transaction.accountId,
          destinationAccountId: Value(transaction.destinationAccountId),
          categoryId: Value(transaction.categoryId),
          type: transaction.type.code,
          amountMinor: effectiveAmount.minorUnits,
          currency: effectiveAmount.currency.code,
          transactionDate: transaction.date.millisecondsSinceEpoch,
          description: transaction.description,
          notes: Value(transaction.notes),
          isBusiness: Value(transaction.isBusiness),
          attachmentUri: Value(transaction.attachmentUri),
          createdAt: now,
          updatedAt: now,
          syncStatus: const Value(1), // Pending sync
        );
        await _db.into(_db.transactionsTable).insert(companion);

        // 3. Adjust account balances via unified helper
        final insertedTx = transaction.copyWith(
          id: txId,
          amount: effectiveAmount,
        );
        await _applyBalanceEffect(insertedTx, now: now, reverse: false);

        // 4. Push to Outbox Sync Queue (with complete payload)
        final idempotencyKey = _uuid.v4();
        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'transactions',
                entityId: txId,
                operation: 'INSERT',
                payloadJson: jsonEncode({
                  'id': txId,
                  'account_id': transaction.accountId,
                  'destination_account_id': transaction.destinationAccountId,
                  'category_id': transaction.categoryId,
                  'amount_minor': effectiveAmount.minorUnits,
                  'currency': effectiveAmount.currency.code,
                  'type': transaction.type.code,
                  'date': transaction.date.millisecondsSinceEpoch,
                  'description': transaction.description,
                  'notes': transaction.notes,
                  'is_business': transaction.isBusiness,
                  'attachment_uri': transaction.attachmentUri,
                  'version': 1,
                }),
                idempotencyKey: idempotencyKey,
                queuedAt: now,
              ),
            );
      });

      final created = await (_db.select(
        _db.transactionsTable,
      )..where((t) => t.id.equals(txId))).getSingle();
      return Success(_toEntity(created));
    } catch (e) {
      if (e is ArgumentError) {
        return DatabaseFailure(e.message.toString()).asFailure();
      }
      if (e is StateError) return DatabaseFailure(e.message).asFailure();
      return DatabaseFailure('ثبت تراکنش انجام نشد. دوباره تلاش کنید.')
          .asFailure();
    }
  }

  @override
  Future<Result<TransactionEntity>> updateTransaction(
    TransactionEntity transaction,
  ) async {
    try {
      _validateTransaction(transaction);
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        // 1. Load the existing row (must exist and not be soft-deleted)
        final existing = await (_db.select(
          _db.transactionsTable,
        )..where((t) => t.id.equals(transaction.id))).getSingleOrNull();
        if (existing == null || existing.deletedAt != null) {
          throw StateError('Transaction ${transaction.id} not found');
        }
        final old = _toEntity(existing);

        // 2. Revert the old balance effect
        await _applyBalanceEffect(old, now: now, reverse: true);

        // 3. Apply the new balance effect
        final newSource = await (_db.select(
          _db.accountsTable,
        )..where((t) => t.id.equals(transaction.accountId))).getSingle();

        final newAccountCurrency = Currency.fromCode(newSource.currency);
        Money effectiveAmount = transaction.amount;
        if (effectiveAmount.currency != newAccountCurrency) {
          if (effectiveAmount.isCompatibleWith(newAccountCurrency)) {
            effectiveAmount = effectiveAmount.normalizeTo(newAccountCurrency);
          } else {
            throw StateError(
              'Currency mismatch: transaction ${effectiveAmount.currency.code} vs account ${newAccountCurrency.code}',
            );
          }
        }

        // Validate destination currency compatibility if transfer
        if (transaction.type == TransactionType.transfer &&
            transaction.destinationAccountId != null) {
          final destAccount =
              await (_db.select(_db.accountsTable)..where(
                    (t) => t.id.equals(transaction.destinationAccountId!),
                  ))
                  .getSingle();
          final destCurrency = Currency.fromCode(destAccount.currency);
          if (transaction.amount.currency != destCurrency &&
              !transaction.amount.isCompatibleWith(destCurrency)) {
            throw StateError(
              'Currency mismatch: transaction ${transaction.amount.currency.code} vs destination account ${destCurrency.code}',
            );
          }
        }

        final updatedTx = transaction.copyWith(amount: effectiveAmount);
        await _applyBalanceEffect(updatedTx, now: now, reverse: false);

        // 4. Persist the edited values
        final newVersion = existing.version + 1;
        await (_db.update(
          _db.transactionsTable,
        )..where((t) => t.id.equals(transaction.id))).write(
          TransactionsTableCompanion(
            accountId: Value(transaction.accountId),
            destinationAccountId: Value(transaction.destinationAccountId),
            categoryId: Value(transaction.categoryId),
            type: Value(transaction.type.code),
            amountMinor: Value(effectiveAmount.minorUnits),
            currency: Value(effectiveAmount.currency.code),
            transactionDate: Value(transaction.date.millisecondsSinceEpoch),
            description: Value(transaction.description),
            notes: Value(transaction.notes),
            isBusiness: Value(transaction.isBusiness),
            attachmentUri: Value(transaction.attachmentUri),
            updatedAt: Value(now),
            version: Value(newVersion),
            syncStatus: const Value(2), // Pending update
          ),
        );

        // 5. Push to Outbox Sync Queue
        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'transactions',
                entityId: transaction.id,
                operation: 'UPDATE',
                payloadJson: jsonEncode({
                  'id': transaction.id,
                  'account_id': transaction.accountId,
                  'destination_account_id': transaction.destinationAccountId,
                  'category_id': transaction.categoryId,
                  'amount_minor': effectiveAmount.minorUnits,
                  'currency': effectiveAmount.currency.code,
                  'type': transaction.type.code,
                  'date': transaction.date.millisecondsSinceEpoch,
                  'description': transaction.description,
                  'notes': transaction.notes,
                  'is_business': transaction.isBusiness,
                  'attachment_uri': transaction.attachmentUri,
                  'version': newVersion,
                }),
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      final updated = await (_db.select(
        _db.transactionsTable,
      )..where((t) => t.id.equals(transaction.id))).getSingle();
      return Success(_toEntity(updated));
    } catch (e) {
      if (e is ArgumentError) {
        return DatabaseFailure(e.message.toString()).asFailure();
      }
      if (e is StateError) return DatabaseFailure(e.message).asFailure();
      return DatabaseFailure('ویرایش تراکنش انجام نشد. دوباره تلاش کنید.')
          .asFailure();
    }
  }

  @override
  Future<Result<void>> softDeleteTransaction(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final tx = await (_db.select(
          _db.transactionsTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (tx == null || tx.deletedAt != null) {
          // Idempotent: already deleted or not found
          return;
        }
        final txEntity = _toEntity(tx);

        // Revert account balances
        await _applyBalanceEffect(txEntity, now: now, reverse: true);

        // Mark deleted & increment version
        final newVersion = tx.version + 1;
        await (_db.update(
          _db.transactionsTable,
        )..where((t) => t.id.equals(id))).write(
          TransactionsTableCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            version: Value(newVersion),
            syncStatus: const Value(3), // Pending delete
          ),
        );

        // Enqueue deletion in outbox
        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'transactions',
                entityId: id,
                operation: 'DELETE',
                payloadJson: jsonEncode({'id': id, 'version': newVersion}),
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('حذف تراکنش انجام نشد. دوباره تلاش کنید.')
          .asFailure();
    }
  }

  @override
  Future<Result<void>> restoreTransaction(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final tx = await (_db.select(
          _db.transactionsTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (tx == null || tx.deletedAt == null) {
          // Idempotent: already active or not found
          return;
        }
        final txEntity = _toEntity(tx);

        // Reapply account balances
        await _applyBalanceEffect(txEntity, now: now, reverse: false);

        // Unset deletedAt & increment version
        final newVersion = tx.version + 1;
        await (_db.update(
          _db.transactionsTable,
        )..where((t) => t.id.equals(id))).write(
          TransactionsTableCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(now),
            version: Value(newVersion),
            syncStatus: const Value(2), // Pending update
          ),
        );

        // Enqueue update in outbox
        await _db
            .into(_db.syncQueueTable)
            .insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'transactions',
                entityId: id,
                operation: 'UPDATE',
                payloadJson: jsonEncode({
                  'id': id,
                  'account_id': tx.accountId,
                  'destination_account_id': tx.destinationAccountId,
                  'category_id': tx.categoryId,
                  'amount_minor': tx.amountMinor,
                  'currency': tx.currency,
                  'type': tx.type,
                  'date': tx.transactionDate,
                  'description': tx.description,
                  'notes': tx.notes,
                  'is_business': tx.isBusiness,
                  'attachment_uri': tx.attachmentUri,
                  'version': newVersion,
                  'deleted_at': null,
                }),
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('بازگردانی تراکنش انجام نشد. دوباره تلاش کنید.')
          .asFailure();
    }
  }

  @override
  Future<Result<void>> recomputeBalances() async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.transaction(() async {
        final accounts = await _db.select(_db.accountsTable).get();
        final activeTxs = await (_db.select(
          _db.transactionsTable,
        )..where((t) => t.deletedAt.isNull())).get();

        for (final account in accounts) {
          final accountCurrency = Currency.fromCode(account.currency);
          int computedBalance = account.initialBalanceMinor;

          for (final tx in activeTxs) {
            final txCurrency = Currency.fromCode(tx.currency);
            final txAmount = Money.fromMinor(tx.amountMinor, txCurrency);

            if (tx.accountId == account.id) {
              Money effectiveAmount = txAmount;
              if (effectiveAmount.currency != accountCurrency &&
                  effectiveAmount.isCompatibleWith(accountCurrency)) {
                effectiveAmount = effectiveAmount.normalizeTo(accountCurrency);
              }

              if (tx.type == 'expense' || tx.type == 'debtPayment') {
                computedBalance -= effectiveAmount.minorUnits;
              } else if (tx.type == 'income' ||
                  tx.type == 'receivablePayment') {
                computedBalance += effectiveAmount.minorUnits;
              } else if (tx.type == 'transfer') {
                computedBalance -= effectiveAmount.minorUnits;
              }
            }

            if (tx.destinationAccountId == account.id &&
                tx.type == 'transfer') {
              Money effectiveAmount = txAmount;
              if (effectiveAmount.currency != accountCurrency &&
                  effectiveAmount.isCompatibleWith(accountCurrency)) {
                effectiveAmount = effectiveAmount.normalizeTo(accountCurrency);
              }
              computedBalance += effectiveAmount.minorUnits;
            }
          }

          if (computedBalance != account.currentBalanceMinor) {
            await (_db.update(
              _db.accountsTable,
            )..where((t) => t.id.equals(account.id))).write(
              AccountsTableCompanion(
                currentBalanceMinor: Value(computedBalance),
                updatedAt: Value(now),
              ),
            );
          }
        }
      });
      return const Success(null);
    } catch (e) {
      return DatabaseFailure('محاسبه مجدد مانده حساب‌ها انجام نشد.')
          .asFailure();
    }
  }

  @override
  Future<Result<List<TransactionEntity>>> getRecentTransactions({
    int limit = 10,
  }) async {
    try {
      final query = _db.select(_db.transactionsTable)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.transactionDate)])
        ..limit(limit);

      final rows = await query.get();
      return Success(rows.map((r) => _toEntity(r)).toList());
    } catch (e) {
      return DatabaseFailure('خواندن تراکنش‌ها انجام نشد.').asFailure();
    }
  }
}
