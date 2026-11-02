import 'package:bloc_test/bloc_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';
import 'package:kifino/features/accounts/presentation/bloc/accounts_bloc.dart';

void main() {
  late AppDatabase db;
  late AccountRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = AccountRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AccountsBloc Tests', () {
    blocTest<AccountsBloc, AccountsState>(
      'emits [AccountsLoading, AccountsLoaded] when WatchAccountsStarted is dispatched',
      build: () => AccountsBloc(repository),
      act: (bloc) => bloc.add(const WatchAccountsStarted()),
      expect: () => [
        isA<AccountsLoading>(),
        isA<AccountsLoaded>().having(
          (s) => s.totalBalance.minorUnits,
          'totalBalance',
          equals(0),
        ),
      ],
    );

    blocTest<AccountsBloc, AccountsState>(
      'updates totalBalance when account is created',
      build: () => AccountsBloc(repository),
      act: (bloc) async {
        bloc.add(const WatchAccountsStarted());
        await pumpEventQueue();
        bloc.add(
          AccountCreateRequested(
            AccountEntity(
              id: 'acc-new',
              name: 'Wallet',
              type: AccountType.cashWallet,
              currency: Currency.toman,
              initialBalance: const Money(
                minorUnits: 500000,
                currency: Currency.toman,
              ),
              currentBalance: const Money(
                minorUnits: 500000,
                currency: Currency.toman,
              ),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
        );
      },
      expect: () => [
        isA<AccountsLoading>(),
        isA<AccountsLoaded>().having(
          (s) => s.totalBalance.minorUnits,
          'empty',
          equals(0),
        ),
        isA<AccountsLoaded>().having(
          (s) => s.totalBalance.minorUnits,
          'updated',
          equals(500000),
        ),
      ],
    );
  });
}
