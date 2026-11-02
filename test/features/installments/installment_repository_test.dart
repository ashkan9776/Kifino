import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:kifino/features/accounts/domain/entities/account_entity.dart';
import 'package:kifino/features/installments/data/repositories/installment_repository_impl.dart';
import 'package:kifino/features/installments/domain/entities/installment_entity.dart';

void main() {
  late AppDatabase db;
  late AccountRepositoryImpl accountRepository;
  late InstallmentRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    accountRepository = AccountRepositoryImpl(db);
    repository = InstallmentRepositoryImpl(db);

    // Create linked account with 20,000,000 initial balance
    await accountRepository.createAccount(
      AccountEntity(
        id: 'acc-inst-1',
        name: 'حساب ملت',
        type: AccountType.bankCard,
        currency: Currency.irr,
        initialBalance: const Money(
          minorUnits: 20000000,
          currency: Currency.irr,
        ),
        currentBalance: const Money(
          minorUnits: 20000000,
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

  group('InstallmentRepositoryImpl Tests', () {
    final now = DateTime.now();

    test('Pays next installment and deducts balance from linked account atomically', () async {
      final installment = InstallmentEntity(
        id: 'inst-1',
        title: 'وام مسکن',
        accountId: 'acc-inst-1',
        totalAmount: const Money(minorUnits: 12000000, currency: Currency.irr),
        numberOfInstallments: 12,
        installmentAmount: const Money(
          minorUnits: 1000000,
          currency: Currency.irr,
        ),
        startDate: now,
        nextDueDate: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      await repository.createInstallment(installment);

      // Pay first installment
      await repository.payNextInstallment('inst-1');

      final list = await repository.getInstallments();
      expect(list.isSuccess, isTrue);
      final updated = list.dataOrNull!.first;
      expect(updated.paidInstallmentsCount, equals(1));
      expect(updated.remainingInstallmentsCount, equals(11));

      // Verify account balance was deducted by 1,000,000
      final accounts = await accountRepository.getAccounts();
      final account = accounts.dataOrNull!.firstWhere(
        (a) => a.id == 'acc-inst-1',
      );
      expect(account.currentBalance.minorUnits, equals(19000000));
    });
  });
}
