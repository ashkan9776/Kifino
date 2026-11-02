import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';

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

  group('AccountRepositoryImpl in-memory tests', () {
    test('Creates and watches account balances', () async {
      final account = AccountEntity(
        id: 'acc-1',
        name: 'Test Bank',
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
      );

      final createResult = await repository.createAccount(account);
      expect(createResult.isSuccess, isTrue);

      final accounts = await repository.getAccounts();
      expect(accounts.isSuccess, isTrue);
      expect(accounts.dataOrNull!.length, equals(1));
      expect(accounts.dataOrNull!.first.name, equals('Test Bank'));
      expect(
        accounts.dataOrNull!.first.currentBalance.minorUnits,
        equals(1000000),
      );
    });

    test('Archives and soft deletes accounts', () async {
      final account = AccountEntity(
        id: 'acc-to-archive',
        name: 'Archive Me',
        type: AccountType.cashWallet,
        currency: Currency.toman,
        initialBalance: const Money.zero(Currency.toman),
        currentBalance: const Money.zero(Currency.toman),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.createAccount(account);

      // Archive
      await repository.archiveAccount('acc-to-archive', true);
      final activeAccounts = await repository.getAccounts(
        includeArchived: false,
      );
      expect(activeAccounts.dataOrNull!.isEmpty, isTrue);

      final allAccounts = await repository.getAccounts(includeArchived: true);
      expect(allAccounts.dataOrNull!.length, equals(1));
      expect(allAccounts.dataOrNull!.first.isArchived, isTrue);

      // Soft Delete
      await repository.deleteAccount('acc-to-archive');
      final afterDelete = await repository.getAccounts(includeArchived: true);
      expect(afterDelete.dataOrNull!.isEmpty, isTrue);
    });
  });
}
