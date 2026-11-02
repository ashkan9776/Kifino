import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:kifino/features/debts/domain/entities/debt_entity.dart';

void main() {
  late AppDatabase db;
  late DebtRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DebtRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DebtRepositoryImpl Tests', () {
    final now = DateTime.now();

    test('Creates debt and records partial payments', () async {
      final debt = DebtEntity(
        id: 'debt-1',
        contactName: 'رضا علوی',
        type: DebtType.debt,
        totalAmount: const Money(
          minorUnits: 10000000,
          currency: Currency.irr,
        ), // 10M
        dueDate: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      final createRes = await repository.createDebt(debt);
      expect(createRes.isSuccess, isTrue);

      // Record partial payment of 4M
      await repository.addPayment(
        'debt-1',
        const Money(minorUnits: 4000000, currency: Currency.irr),
      );

      final debts = await repository.getDebts();
      expect(debts.isSuccess, isTrue);
      final updated = debts.dataOrNull!.first;
      expect(updated.paidAmount.minorUnits, equals(4000000));
      expect(updated.remainingAmount.minorUnits, equals(6000000));
      expect(updated.isSettled, isFalse);

      // Pay remaining 6M
      await repository.addPayment(
        'debt-1',
        const Money(minorUnits: 6000000, currency: Currency.irr),
      );
      final debtsAfter = await repository.getDebts();
      final settled = debtsAfter.dataOrNull!.first;
      expect(settled.isSettled, isTrue);
    });

    test('Soft deletes debt record', () async {
      final debt = DebtEntity(
        id: 'debt-del',
        contactName: 'تست حذف',
        type: DebtType.receivable,
        totalAmount: const Money(minorUnits: 5000000, currency: Currency.irr),
        createdAt: now,
        updatedAt: now,
      );

      await repository.createDebt(debt);
      await repository.deleteDebt('debt-del');

      final list = await repository.getDebts();
      expect(list.dataOrNull!.isEmpty, isTrue);
    });
  });
}
