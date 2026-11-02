import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';
import 'package:kifino/features/checks/data/repositories/check_repository_impl.dart';
import 'package:kifino/features/checks/domain/entities/check_entity.dart';

void main() {
  late AppDatabase db;
  late AccountRepositoryImpl accountRepository;
  late CheckRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accountRepository = AccountRepositoryImpl(db);
    repository = CheckRepositoryImpl(db);

    await accountRepository.createAccount(
      AccountEntity(
        id: 'acc-check-1',
        name: 'جاری سپه',
        type: AccountType.bankCard,
        currency: Currency.irr,
        initialBalance: const Money(
          minorUnits: 5000000,
          currency: Currency.irr,
        ), // 5M
        currentBalance: const Money(
          minorUnits: 5000000,
          currency: Currency.irr,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('CheckRepositoryImpl Tests', () {
    final now = DateTime.now();

    test('Issued check clearance deducts from account and received check clearance credits account', () async {
      // 1. Issued Check for 2M
      final issuedCheck = CheckEntity(
        id: 'chk-issued-1',
        checkNumber: '123456',
        bankName: 'سپه',
        type: CheckType.issued,
        amount: const Money(minorUnits: 2000000, currency: Currency.irr),
        partyName: 'فروشگاه افق',
        dueDate: now.add(const Duration(days: 5)),
        accountId: 'acc-check-1',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createCheck(issuedCheck);

      // Clear issued check
      await repository.updateCheckStatus('chk-issued-1', CheckStatus.cleared);

      var accounts = await accountRepository.getAccounts();
      var account = accounts.dataOrNull!.firstWhere(
        (a) => a.id == 'acc-check-1',
      );
      expect(
        account.currentBalance.minorUnits,
        equals(3000000),
      ); // 5M - 2M = 3M

      // 2. Received Check for 4M
      final receivedCheck = CheckEntity(
        id: 'chk-recv-1',
        checkNumber: '998877',
        bankName: 'ملی',
        type: CheckType.received,
        amount: const Money(minorUnits: 4000000, currency: Currency.irr),
        partyName: 'شرکت پارت',
        dueDate: now.add(const Duration(days: 2)),
        accountId: 'acc-check-1',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createCheck(receivedCheck);

      // Clear received check
      await repository.updateCheckStatus('chk-recv-1', CheckStatus.cleared);

      accounts = await accountRepository.getAccounts();
      account = accounts.dataOrNull!.firstWhere((a) => a.id == 'acc-check-1');
      expect(
        account.currentBalance.minorUnits,
        equals(7000000),
      ); // 3M + 4M = 7M
    });
  });
}
