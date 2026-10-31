import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';
import 'package:kifino/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';
import 'package:kifino/features/transactions/presentation/bloc/transaction_bloc.dart';

void main() {
  late AppDatabase db;
  late AccountRepositoryImpl accountRepo;
  late TransactionRepositoryImpl txRepo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accountRepo = AccountRepositoryImpl(db);
    txRepo = TransactionRepositoryImpl(db);

    await accountRepo.createAccount(AccountEntity(
      id: 'acc-bloc',
      name: 'Bank',
      type: AccountType.bankCard,
      currency: Currency.toman,
      initialBalance: const Money(minorUnits: 1000000, currency: Currency.toman),
      currentBalance: const Money(minorUnits: 1000000, currency: Currency.toman),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionBloc Tests', () {
    blocTest<TransactionBloc, TransactionState>(
      'emits [TransactionLoading, TransactionLoaded] on WatchTransactionsStarted',
      build: () => TransactionBloc(txRepo),
      act: (bloc) => bloc.add(const WatchTransactionsStarted()),
      expect: () => [
        isA<TransactionLoading>(),
        isA<TransactionLoaded>().having((s) => s.transactions.length, 'length', equals(0)),
      ],
    );

    blocTest<TransactionBloc, TransactionState>(
      'correctly computes totalIncome, totalExpense, and netCashFlow on transaction creation',
      build: () => TransactionBloc(txRepo),
      act: (bloc) async {
        bloc.add(const WatchTransactionsStarted());
        await pumpEventQueue();

        bloc.add(TransactionCreateSubmitted(TransactionEntity(
          id: 'tx-1',
          accountId: 'acc-bloc',
          amount: const Money(minorUnits: 200000, currency: Currency.toman),
          type: TransactionType.expense,
          date: DateTime.now(),
          description: 'Groceries',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )));
      },
      expect: () => [
        isA<TransactionLoading>(),
        isA<TransactionLoaded>().having((s) => s.transactions.length, 'empty', equals(0)),
        isA<TransactionOperationSuccess>(),
        isA<TransactionLoaded>()
            .having((s) => s.totalExpense.minorUnits, 'totalExpense', equals(200000))
            .having((s) => s.netCashFlow.minorUnits, 'netCashFlow', equals(-200000)),
      ],
    );
  });
}
