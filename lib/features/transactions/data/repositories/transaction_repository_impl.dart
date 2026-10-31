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
      deletedAt: tx.deletedAt != null ? DateTime.fromMillisecondsSinceEpoch(tx.deletedAt!) : null,
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
      query.where(_db.transactionsTable.transactionDate.isBiggerOrEqualValue(startDate.millisecondsSinceEpoch));
    }
    if (endDate != null) {
      query.where(_db.transactionsTable.transactionDate.isSmallerOrEqualValue(endDate.millisecondsSinceEpoch));
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
    final query = _db.select(_db.transactionsTable)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull().map((row) => row != null ? _toEntity(row) : null);
  }

  @override
  Future<Result<TransactionEntity>> createTransaction(TransactionEntity transaction) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final txId = transaction.id.isEmpty ? _uuid.v4() : transaction.id;

      await _db.transaction(() async {
        // 1. Currency safety net: the stored amount must speak the account's
        // currency. Iranian pairs convert exactly (×10); a foreign mismatch
        // is refused instead of silently corrupting the balance.
        final sourceAccount = await (_db.select(_db.accountsTable)
              ..where((t) => t.id.equals(transaction.accountId)))
            .getSingle();
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

        // 3. Adjust account balances
        int newSourceBalance = sourceAccount.currentBalanceMinor;
        if (transaction.type == TransactionType.expense) {
          newSourceBalance -= effectiveAmount.minorUnits;
        } else if (transaction.type == TransactionType.income) {
          newSourceBalance += effectiveAmount.minorUnits;
        } else if (transaction.type == TransactionType.transfer) {
          newSourceBalance -= effectiveAmount.minorUnits;

          if (transaction.destinationAccountId != null) {
            final destAccount = await (_db.select(_db.accountsTable)
                  ..where((t) => t.id.equals(transaction.destinationAccountId!)))
                .getSingle();
            final newDestBalance = destAccount.currentBalanceMinor + effectiveAmount.minorUnits;
            await (_db.update(_db.accountsTable)..where((t) => t.id.equals(destAccount.id))).write(
              AccountsTableCompanion(
                currentBalanceMinor: Value(newDestBalance),
                updatedAt: Value(now),
              ),
            );
          }
        }

        await (_db.update(_db.accountsTable)..where((t) => t.id.equals(sourceAccount.id))).write(
          AccountsTableCompanion(
            currentBalanceMinor: Value(newSourceBalance),
            updatedAt: Value(now),
          ),
        );

        // 4. Push to Outbox Sync Queue
        final idempotencyKey = _uuid.v4();
        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'transactions',
                entityId: txId,
                operation: 'INSERT',
                payloadJson: jsonEncode({
                  'id': txId,
                  'account_id': transaction.accountId,
                  'amount_minor': effectiveAmount.minorUnits,
                  'currency': effectiveAmount.currency.code,
                  'type': transaction.type.code,
                  'date': transaction.date.millisecondsSinceEpoch,
                  'description': transaction.description,
                }),
                idempotencyKey: idempotencyKey,
                queuedAt: now,
              ),
            );
      });

      final created = await (_db.select(_db.transactionsTable)..where((t) => t.id.equals(txId))).getSingle();
      return Success(_toEntity(created));
    } catch (e) {
      return DatabaseFailure('ثبت تراکنش انجام نشد. دوباره تلاش کنید.').asFailure();
    }
  }

  @override
  Future<Result<TransactionEntity>> updateTransaction(TransactionEntity transaction) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        // 1. Load the existing row (must exist and not be soft-deleted)
        final existing = await (_db.select(_db.transactionsTable)
              ..where((t) => t.id.equals(transaction.id)))
            .getSingleOrNull();
        if (existing == null || existing.deletedAt != null) {
          throw StateError('Transaction ${transaction.id} not found');
        }
        final old = _toEntity(existing);

        // 2. Revert the old balance effect (mirrors softDeleteTransaction)
        final oldSource = await (_db.select(_db.accountsTable)
              ..where((t) => t.id.equals(old.accountId)))
            .getSingle();

        int revertedSource = oldSource.currentBalanceMinor;
        if (old.type == TransactionType.expense) {
          revertedSource += old.amount.minorUnits;
        } else if (old.type == TransactionType.income) {
          revertedSource -= old.amount.minorUnits;
        } else if (old.type == TransactionType.transfer) {
          revertedSource += old.amount.minorUnits;

          if (old.destinationAccountId != null) {
            final oldDest = await (_db.select(_db.accountsTable)
                  ..where((t) => t.id.equals(old.destinationAccountId!)))
                .getSingle();
            await (_db.update(_db.accountsTable)..where((t) => t.id.equals(oldDest.id))).write(
              AccountsTableCompanion(
                currentBalanceMinor: Value(oldDest.currentBalanceMinor - old.amount.minorUnits),
                updatedAt: Value(now),
              ),
            );
          }
        }

        await (_db.update(_db.accountsTable)..where((t) => t.id.equals(oldSource.id))).write(
          AccountsTableCompanion(
            currentBalanceMinor: Value(revertedSource),
            updatedAt: Value(now),
          ),
        );

        // 3. Apply the new balance effect (mirrors createTransaction)
        final newSource = await (_db.select(_db.accountsTable)
              ..where((t) => t.id.equals(transaction.accountId)))
            .getSingle();

        // Same currency safety net as createTransaction.
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

        int newSourceBalance = newSource.currentBalanceMinor;
        if (transaction.type == TransactionType.expense) {
          newSourceBalance -= effectiveAmount.minorUnits;
        } else if (transaction.type == TransactionType.income) {
          newSourceBalance += effectiveAmount.minorUnits;
        } else if (transaction.type == TransactionType.transfer) {
          if (transaction.destinationAccountId == null) {
            throw StateError('Transfer requires a destination account');
          }
          newSourceBalance -= effectiveAmount.minorUnits;

          final newDest = await (_db.select(_db.accountsTable)
                ..where((t) => t.id.equals(transaction.destinationAccountId!)))
              .getSingle();
          await (_db.update(_db.accountsTable)..where((t) => t.id.equals(newDest.id))).write(
            AccountsTableCompanion(
              currentBalanceMinor: Value(newDest.currentBalanceMinor + effectiveAmount.minorUnits),
              updatedAt: Value(now),
            ),
          );
        }

        await (_db.update(_db.accountsTable)..where((t) => t.id.equals(newSource.id))).write(
          AccountsTableCompanion(
            currentBalanceMinor: Value(newSourceBalance),
            updatedAt: Value(now),
          ),
        );

        // 4. Persist the edited values
        await (_db.update(_db.transactionsTable)..where((t) => t.id.equals(transaction.id))).write(
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
            version: Value(transaction.version + 1),
            syncStatus: const Value(2), // Pending update
          ),
        );

        // 5. Push to Outbox Sync Queue
        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'transactions',
                entityId: transaction.id,
                operation: 'UPDATE',
                payloadJson: jsonEncode({
                  'id': transaction.id,
                  'account_id': transaction.accountId,
                  'destination_account_id': transaction.destinationAccountId,
                  'amount_minor': effectiveAmount.minorUnits,
                  'currency': effectiveAmount.currency.code,
                  'type': transaction.type.code,
                  'date': transaction.date.millisecondsSinceEpoch,
                  'description': transaction.description,
                }),
                idempotencyKey: _uuid.v4(),
                queuedAt: now,
              ),
            );
      });

      final updated = await (_db.select(_db.transactionsTable)..where((t) => t.id.equals(transaction.id))).getSingle();
      return Success(_toEntity(updated));
    } catch (e) {
      return DatabaseFailure('ویرایش تراکنش انجام نشد. دوباره تلاش کنید.').asFailure();
    }
  }

  @override
  Future<Result<void>> softDeleteTransaction(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final tx = await (_db.select(_db.transactionsTable)..where((t) => t.id.equals(id))).getSingle();
        final txEntity = _toEntity(tx);

        // Revert account balances
        final sourceAccount = await (_db.select(_db.accountsTable)
              ..where((t) => t.id.equals(txEntity.accountId)))
            .getSingle();

        int revertedSource = sourceAccount.currentBalanceMinor;
        if (txEntity.type == TransactionType.expense) {
          revertedSource += txEntity.amount.minorUnits;
        } else if (txEntity.type == TransactionType.income) {
          revertedSource -= txEntity.amount.minorUnits;
        } else if (txEntity.type == TransactionType.transfer) {
          revertedSource += txEntity.amount.minorUnits;

          if (txEntity.destinationAccountId != null) {
            final destAccount = await (_db.select(_db.accountsTable)
                  ..where((t) => t.id.equals(txEntity.destinationAccountId!)))
                .getSingle();
            final revertedDest = destAccount.currentBalanceMinor - txEntity.amount.minorUnits;
            await (_db.update(_db.accountsTable)..where((t) => t.id.equals(destAccount.id))).write(
              AccountsTableCompanion(
                currentBalanceMinor: Value(revertedDest),
                updatedAt: Value(now),
              ),
            );
          }
        }

        await (_db.update(_db.accountsTable)..where((t) => t.id.equals(sourceAccount.id))).write(
          AccountsTableCompanion(
            currentBalanceMinor: Value(revertedSource),
            updatedAt: Value(now),
          ),
        );

        // Mark deleted
        await (_db.update(_db.transactionsTable)..where((t) => t.id.equals(id))).write(
          TransactionsTableCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            syncStatus: const Value(3), // Pending delete
          ),
        );

        // Enqueue deletion in outbox
        await _db.into(_db.syncQueueTable).insert(
              SyncQueueTableCompanion.insert(
                syncEntityName: 'transactions',
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
      return DatabaseFailure('حذف تراکنش انجام نشد. دوباره تلاش کنید.').asFailure();
    }
  }

  @override
  Future<Result<void>> restoreTransaction(String id) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        final tx = await (_db.select(_db.transactionsTable)..where((t) => t.id.equals(id))).getSingle();
        final txEntity = _toEntity(tx);

        // Reapply account balances
        final sourceAccount = await (_db.select(_db.accountsTable)
              ..where((t) => t.id.equals(txEntity.accountId)))
            .getSingle();

        int rebalanced = sourceAccount.currentBalanceMinor;
        if (txEntity.type == TransactionType.expense) {
          rebalanced -= txEntity.amount.minorUnits;
        } else if (txEntity.type == TransactionType.income) {
          rebalanced += txEntity.amount.minorUnits;
        } else if (txEntity.type == TransactionType.transfer) {
          rebalanced -= txEntity.amount.minorUnits;

          if (txEntity.destinationAccountId != null) {
            final destAccount = await (_db.select(_db.accountsTable)
                  ..where((t) => t.id.equals(txEntity.destinationAccountId!)))
                .getSingle();
            final destRebalanced = destAccount.currentBalanceMinor + txEntity.amount.minorUnits;
            await (_db.update(_db.accountsTable)..where((t) => t.id.equals(destAccount.id))).write(
              AccountsTableCompanion(
                currentBalanceMinor: Value(destRebalanced),
                updatedAt: Value(now),
              ),
            );
          }
        }

        await (_db.update(_db.accountsTable)..where((t) => t.id.equals(sourceAccount.id))).write(
          AccountsTableCompanion(
            currentBalanceMinor: Value(rebalanced),
            updatedAt: Value(now),
          ),
        );

        // Unset deletedAt
        await (_db.update(_db.transactionsTable)..where((t) => t.id.equals(id))).write(
          TransactionsTableCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(now),
            syncStatus: const Value(1),
          ),
        );
      });

      return const Success(null);
    } catch (e) {
      return DatabaseFailure('بازگردانی تراکنش انجام نشد. دوباره تلاش کنید.').asFailure();
    }
  }

  @override
  Future<Result<List<TransactionEntity>>> getRecentTransactions({int limit = 10}) async {
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
