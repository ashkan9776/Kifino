import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';
import 'package:kifino/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  late AppDatabase db;
  late AccountRepositoryImpl accountRepository;
  late TransactionRepositoryImpl transactionRepository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accountRepository = AccountRepositoryImpl(db);
    transactionRepository = TransactionRepositoryImpl(db);

    // Setup accounts:
    // 1. Toman bank account
    await accountRepository.createAccount(
      AccountEntity(
        id: 'acc-toman',
        name: 'حساب تومانی',
        type: AccountType.bankCard,
        currency: Currency.toman,
        initialBalance: const Money(
          minorUnits: 1000000,
          currency: Currency.toman,
        ), // 1,000,000
        currentBalance: const Money(
          minorUnits: 1000000,
          currency: Currency.toman,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // 2. Rial bank account
    await accountRepository.createAccount(
      AccountEntity(
        id: 'acc-rial',
        name: 'حساب ریالی',
        type: AccountType.bankCard,
        currency: Currency.irr,
        initialBalance: const Money(
          minorUnits: 50000000,
          currency: Currency.irr,
        ), // 50,000,000
        currentBalance: const Money(
          minorUnits: 50000000,
          currency: Currency.irr,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // 3. USD cash account
    await accountRepository.createAccount(
      AccountEntity(
        id: 'acc-usd',
        name: 'کیف دلاری',
        type: AccountType.cashWallet,
        currency: Currency.usd,
        initialBalance: const Money(
          minorUnits: 50000,
          currency: Currency.usd,
        ), // $500.00
        currentBalance: const Money(minorUnits: 50000, currency: Currency.usd),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('P0-6 Account Balance Bugs in Transactions', () {
    test('1. Transfer to same account (source == destination) is rejected and does not alter balance', () async {
      final transferSame = TransactionEntity(
        id: 'tx-self-transfer',
        accountId: 'acc-toman',
        destinationAccountId: 'acc-toman',
        amount: const Money(minorUnits: 200000, currency: Currency.toman),
        type: TransactionType.transfer,
        date: DateTime.now(),
        description: 'Self transfer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await transactionRepository.createTransaction(
        transferSame,
      );
      expect(
        result.isFailure,
        isTrue,
        reason: 'Self-transfer must fail validation',
      );

      final acc = (await accountRepository.getAccounts()).dataOrNull!
          .firstWhere((a) => a.id == 'acc-toman');
      expect(
        acc.currentBalance.minorUnits,
        equals(1000000),
        reason: 'Balance must not change on rejected self-transfer',
      );
    });

    test('2. Transfer with null destinationAccountId in createTransaction is rejected', () async {
      final transferNoDest = TransactionEntity(
        id: 'tx-no-dest',
        accountId: 'acc-toman',
        destinationAccountId: null,
        amount: const Money(minorUnits: 150000, currency: Currency.toman),
        type: TransactionType.transfer,
        date: DateTime.now(),
        description: 'Transfer without destination',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await transactionRepository.createTransaction(
        transferNoDest,
      );
      expect(
        result.isFailure,
        isTrue,
        reason: 'Transfer without destination must fail',
      );

      final acc = (await accountRepository.getAccounts()).dataOrNull!
          .firstWhere((a) => a.id == 'acc-toman');
      expect(
        acc.currentBalance.minorUnits,
        equals(1000000),
        reason: 'Source balance must not decrease when destination is null',
      );
    });

    test('3. Cross-currency transfer: incompatible is rejected, compatible normalizes destination balance', () async {
      // Incompatible: Toman -> USD
      final transferIncompatible = TransactionEntity(
        id: 'tx-toman-usd',
        accountId: 'acc-toman',
        destinationAccountId: 'acc-usd',
        amount: const Money(minorUnits: 100000, currency: Currency.toman),
        type: TransactionType.transfer,
        date: DateTime.now(),
        description: 'Incompatible transfer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final incompResult = await transactionRepository.createTransaction(
        transferIncompatible,
      );
      expect(
        incompResult.isFailure,
        isTrue,
        reason: 'Transfer between incompatible currencies must fail',
      );

      // Compatible: Toman -> Rial (1 Toman = 10 Rial)
      final transferCompatible = TransactionEntity(
        id: 'tx-toman-rial',
        accountId: 'acc-toman',
        destinationAccountId: 'acc-rial',
        amount: const Money(
          minorUnits: 100000,
          currency: Currency.toman,
        ), // 100,000 Tomans
        type: TransactionType.transfer,
        date: DateTime.now(),
        description: 'Compatible transfer Toman to Rial',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final compResult = await transactionRepository.createTransaction(
        transferCompatible,
      );
      expect(compResult.isSuccess, isTrue);

      final accounts = (await accountRepository.getAccounts()).dataOrNull!;
      final tomanAcc = accounts.firstWhere((a) => a.id == 'acc-toman');
      final rialAcc = accounts.firstWhere((a) => a.id == 'acc-rial');

      // Toman: 1,000,000 - 100,000 = 900,000
      expect(tomanAcc.currentBalance.minorUnits, equals(900000));
      // Rial: 50,000,000 + (100,000 * 10) = 51,000,000 Rials!
      expect(
        rialAcc.currentBalance.minorUnits,
        equals(51000000),
        reason: 'Destination Rial balance must be multiplied by 10',
      );
    });

    test(
      '4. softDelete and restore idempotency, version increment and sync queue',
      () async {
        final expense = TransactionEntity(
          id: 'tx-idem',
          accountId: 'acc-toman',
          amount: const Money(minorUnits: 100000, currency: Currency.toman),
          type: TransactionType.expense,
          date: DateTime.now(),
          description: 'Idempotency test',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await transactionRepository.createTransaction(expense);
        // Balance is 900,000

        // First delete -> balance reverted to 1,000,000
        await transactionRepository.softDeleteTransaction('tx-idem');
        var acc = (await accountRepository.getAccounts()).dataOrNull!
            .firstWhere((a) => a.id == 'acc-toman');
        expect(acc.currentBalance.minorUnits, equals(1000000));

        // Second delete (double-tap/retry) -> MUST BE A NO-OP
        await transactionRepository.softDeleteTransaction('tx-idem');
        acc = (await accountRepository.getAccounts()).dataOrNull!.firstWhere(
          (a) => a.id == 'acc-toman',
        );
        expect(
          acc.currentBalance.minorUnits,
          equals(1000000),
          reason: 'Duplicate delete must not revert balance twice',
        );

        // First restore -> balance becomes 900,000 again
        await transactionRepository.restoreTransaction('tx-idem');
        acc = (await accountRepository.getAccounts()).dataOrNull!.firstWhere(
          (a) => a.id == 'acc-toman',
        );
        expect(acc.currentBalance.minorUnits, equals(900000));

        // Second restore -> MUST BE A NO-OP
        await transactionRepository.restoreTransaction('tx-idem');
        acc = (await accountRepository.getAccounts()).dataOrNull!.firstWhere(
          (a) => a.id == 'acc-toman',
        );
        expect(
          acc.currentBalance.minorUnits,
          equals(900000),
          reason: 'Duplicate restore must not apply balance twice',
        );

        // Check version and syncQueue on restore
        final txRow = await (db.select(
          db.transactionsTable,
        )..where((t) => t.id.equals('tx-idem'))).getSingle();
        expect(
          txRow.version,
          greaterThan(1),
          reason: 'Restoring transaction must increment version',
        );

        final syncRows =
            await (db.select(db.syncQueueTable)..where(
                  (t) =>
                      t.entityId.equals('tx-idem') &
                      t.operation.equals('UPDATE'),
                ))
                .get();
        expect(
          syncRows,
          isNotEmpty,
          reason: 'Restoring transaction must enqueue sync UPDATE operation',
        );
      },
    );

    test('5. createTransaction sync payload includes full fields', () async {
      final tx = TransactionEntity(
        id: 'tx-sync-full',
        accountId: 'acc-toman',
        destinationAccountId: 'acc-rial',
        categoryId: 'cat-123',
        amount: const Money(minorUnits: 50000, currency: Currency.toman),
        type: TransactionType.transfer,
        date: DateTime.now(),
        description: 'Full payload test',
        notes: 'Secret note',
        isBusiness: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await transactionRepository.createTransaction(tx);
      expect(result.isSuccess, isTrue);

      final syncRow = await (db.select(
        db.syncQueueTable,
      )..where((t) => t.entityId.equals('tx-sync-full'))).getSingle();
      final payload = jsonDecode(syncRow.payloadJson) as Map<String, dynamic>;

      expect(payload['destination_account_id'], equals('acc-rial'));
      expect(payload['category_id'], equals('cat-123'));
      expect(payload['notes'], equals('Secret note'));
      expect(payload['is_business'], equals(true));
    });

    test('6. recomputeBalances restores invariant: initialBalance + sum(effects) == currentBalance', () async {
      // Intentionally corrupt the account balance
      await (db.update(
        db.accountsTable,
      )..where((t) => t.id.equals('acc-toman'))).write(
        const AccountsTableCompanion(currentBalanceMinor: Value(99999999)),
      );

      // Create a few transactions
      await transactionRepository.createTransaction(
        TransactionEntity(
          id: 'tx-rec-1',
          accountId: 'acc-toman',
          amount: const Money(minorUnits: 150000, currency: Currency.toman),
          type: TransactionType.expense,
          date: DateTime.now(),
          description: 'Exp 1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await transactionRepository.createTransaction(
        TransactionEntity(
          id: 'tx-rec-2',
          accountId: 'acc-toman',
          amount: const Money(minorUnits: 400000, currency: Currency.toman),
          type: TransactionType.income,
          date: DateTime.now(),
          description: 'Inc 1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      // Recompute balances
      final result = await transactionRepository.recomputeBalances();
      expect(result.isSuccess, isTrue);

      final acc = (await accountRepository.getAccounts()).dataOrNull!
          .firstWhere((a) => a.id == 'acc-toman');
      // Initial: 1,000,000 - 150,000 + 400,000 = 1,250,000
      expect(
        acc.currentBalance.minorUnits,
        equals(1250000),
        reason: 'recomputeBalances must correct corrupted balance',
      );
    });

    test('7. Property-style randomized sequence preserves invariant initialBalance + sum(active) == currentBalance', () async {
      final rng = Random(42);
      final txIds = <String>[];
      int expectedNetChange = 0;

      for (int i = 0; i < 30; i++) {
        final action = rng.nextInt(
          4,
        ); // 0: add expense, 1: add income, 2: soft delete, 3: restore
        if (action == 0) {
          final amt = (rng.nextInt(50) + 1) * 1000;
          final id = 'rand-exp-$i';
          await transactionRepository.createTransaction(
            TransactionEntity(
              id: id,
              accountId: 'acc-toman',
              amount: Money(minorUnits: amt, currency: Currency.toman),
              type: TransactionType.expense,
              date: DateTime.now(),
              description: 'Rand Exp $i',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          txIds.add(id);
          expectedNetChange -= amt;
        } else if (action == 1) {
          final amt = (rng.nextInt(50) + 1) * 1000;
          final id = 'rand-inc-$i';
          await transactionRepository.createTransaction(
            TransactionEntity(
              id: id,
              accountId: 'acc-toman',
              amount: Money(minorUnits: amt, currency: Currency.toman),
              type: TransactionType.income,
              date: DateTime.now(),
              description: 'Rand Inc $i',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          txIds.add(id);
          expectedNetChange += amt;
        } else if (action == 2 && txIds.isNotEmpty) {
          final targetId = txIds[rng.nextInt(txIds.length)];
          final tx = await (db.select(
            db.transactionsTable,
          )..where((t) => t.id.equals(targetId))).getSingle();
          if (tx.deletedAt == null) {
            final effect = tx.type == 'expense'
                ? -tx.amountMinor
                : tx.amountMinor;
            expectedNetChange -= effect;
            await transactionRepository.softDeleteTransaction(targetId);
          }
        } else if (action == 3 && txIds.isNotEmpty) {
          final targetId = txIds[rng.nextInt(txIds.length)];
          final tx = await (db.select(
            db.transactionsTable,
          )..where((t) => t.id.equals(targetId))).getSingle();
          if (tx.deletedAt != null) {
            final effect = tx.type == 'expense'
                ? -tx.amountMinor
                : tx.amountMinor;
            expectedNetChange += effect;
            await transactionRepository.restoreTransaction(targetId);
          }
        }
      }

      final acc = (await accountRepository.getAccounts()).dataOrNull!
          .firstWhere((a) => a.id == 'acc-toman');
      final expectedBalance = 1000000 + expectedNetChange;
      expect(
        acc.currentBalance.minorUnits,
        equals(expectedBalance),
        reason: 'Balance must precisely match net active transactions',
      );
    });
  });
}
