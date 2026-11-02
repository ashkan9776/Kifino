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

    // Setup initial source and destination accounts
    await accountRepository.createAccount(
      AccountEntity(
        id: 'acc-src',
        name: 'Source Account',
        type: AccountType.bankCard,
        currency: Currency.toman,
        initialBalance: const Money(
          minorUnits: 1000000,
          currency: Currency.toman,
        ),
        currentBalance: const Money(
          minorUnits: 1000000,
          currency: Currency.toman,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await accountRepository.createAccount(
      AccountEntity(
        id: 'acc-dest',
        name: 'Destination Account',
        type: AccountType.cashWallet,
        currency: Currency.toman,
        initialBalance: const Money(
          minorUnits: 200000,
          currency: Currency.toman,
        ),
        currentBalance: const Money(
          minorUnits: 200000,
          currency: Currency.toman,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionRepositoryImpl in-memory tests', () {
    test(
      'Expense reduces account balance and enqueues sync operation',
      () async {
        final expense = TransactionEntity(
          id: 'tx-exp-1',
          accountId: 'acc-src',
          amount: const Money(minorUnits: 300000, currency: Currency.toman),
          type: TransactionType.expense,
          date: DateTime.now(),
          description: 'Lunch',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final result = await transactionRepository.createTransaction(expense);
        expect(result.isSuccess, isTrue);

        // Verify balance reduced: 1,000,000 - 300,000 = 700,000
        final accounts = await accountRepository.getAccounts();
        final src = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-src');
        expect(src.currentBalance.minorUnits, equals(700000));

        // Verify sync queue item was added
        final queueItems = await db.select(db.syncQueueTable).get();
        expect(queueItems.length, equals(1));
      },
    );

    test('Income increases account balance', () async {
      final income = TransactionEntity(
        id: 'tx-inc-1',
        accountId: 'acc-src',
        amount: const Money(minorUnits: 500000, currency: Currency.toman),
        type: TransactionType.income,
        date: DateTime.now(),
        description: 'Salary Bonus',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await transactionRepository.createTransaction(income);
      expect(result.isSuccess, isTrue);

      // Verify balance increased: 1,000,000 + 500,000 = 1,500,000
      final accounts = await accountRepository.getAccounts();
      final src = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-src');
      expect(src.currentBalance.minorUnits, equals(1500000));
    });

    test(
      'Transfer deducts from source and credits destination atomically',
      () async {
        final transfer = TransactionEntity(
          id: 'tx-trf-1',
          accountId: 'acc-src',
          destinationAccountId: 'acc-dest',
          amount: const Money(minorUnits: 400000, currency: Currency.toman),
          type: TransactionType.transfer,
          date: DateTime.now(),
          description: 'Transfer to Cash',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final result = await transactionRepository.createTransaction(transfer);
        expect(result.isSuccess, isTrue);

        final accounts = await accountRepository.getAccounts();
        final src = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-src');
        final dest = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-dest');

        // src: 1,000,000 - 400,000 = 600,000
        expect(src.currentBalance.minorUnits, equals(600000));
        // dest: 200,000 + 400,000 = 600,000
        expect(dest.currentBalance.minorUnits, equals(600000));
      },
    );

    test(
      'Soft delete reverts balance, and restore re-applies balance',
      () async {
        final expense = TransactionEntity(
          id: 'tx-to-delete',
          accountId: 'acc-src',
          amount: const Money(minorUnits: 250000, currency: Currency.toman),
          type: TransactionType.expense,
          date: DateTime.now(),
          description: 'Temporary Expense',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await transactionRepository.createTransaction(expense);

        // Balance was 1,000,000 - 250,000 = 750,000
        var accounts = await accountRepository.getAccounts();
        var src = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-src');
        expect(src.currentBalance.minorUnits, equals(750000));

        // Delete -> Reverts to 1,000,000
        await transactionRepository.softDeleteTransaction('tx-to-delete');
        accounts = await accountRepository.getAccounts();
        src = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-src');
        expect(src.currentBalance.minorUnits, equals(1000000));

        // Restore -> Returns to 750,000
        await transactionRepository.restoreTransaction('tx-to-delete');
        accounts = await accountRepository.getAccounts();
        src = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-src');
        expect(src.currentBalance.minorUnits, equals(750000));
      },
    );

    test(
      'Updating an expense amount adjusts source balance correctly',
      () async {
        final expense = TransactionEntity(
          id: 'tx-edit-1',
          accountId: 'acc-src',
          amount: const Money(minorUnits: 300000, currency: Currency.toman),
          type: TransactionType.expense,
          date: DateTime.now(),
          description: 'Groceries',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await transactionRepository.createTransaction(expense);
        // 1,000,000 - 300,000 = 700,000

        final updated = await transactionRepository.updateTransaction(
          expense.copyWith(
            amount: const Money(minorUnits: 450000, currency: Currency.toman),
          ),
        );
        expect(updated.isSuccess, isTrue);

        final accounts = await accountRepository.getAccounts();
        final src = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-src');
        // 1,000,000 - 450,000 = 550,000
        expect(src.currentBalance.minorUnits, equals(550000));
        expect(updated.dataOrNull!.amount.minorUnits, equals(450000));
      },
    );

    test(
      'Changing an expense into a transfer moves balances correctly',
      () async {
        final expense = TransactionEntity(
          id: 'tx-edit-2',
          accountId: 'acc-src',
          amount: const Money(minorUnits: 200000, currency: Currency.toman),
          type: TransactionType.expense,
          date: DateTime.now(),
          description: 'Will become transfer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await transactionRepository.createTransaction(expense);
        // 1,000,000 - 200,000 = 800,000

        final updated = await transactionRepository.updateTransaction(
          expense.copyWith(
            type: TransactionType.transfer,
            destinationAccountId: 'acc-dest',
          ),
        );
        expect(updated.isSuccess, isTrue);

        final accounts = await accountRepository.getAccounts();
        final src = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-src');
        final dest = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-dest');
        // src: 1,000,000 - 200,000 = 800,000 (same effect, now as transfer)
        expect(src.currentBalance.minorUnits, equals(800000));
        // dest: 200,000 + 200,000 = 400,000
        expect(dest.currentBalance.minorUnits, equals(400000));
      },
    );

    test('Update bumps version and marks row pending-sync', () async {
      final expense = TransactionEntity(
        id: 'tx-edit-3',
        accountId: 'acc-src',
        amount: const Money(minorUnits: 100000, currency: Currency.toman),
        type: TransactionType.expense,
        date: DateTime.now(),
        description: 'Version check',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await transactionRepository.createTransaction(expense);
      final updated = await transactionRepository.updateTransaction(
        expense.copyWith(description: 'Version check edited'),
      );

      expect(updated.isSuccess, isTrue);
      expect(updated.dataOrNull!.version, equals(2));
      expect(updated.dataOrNull!.syncStatus, equals(2));
      expect(updated.dataOrNull!.description, equals('Version check edited'));
    });
  });
}
