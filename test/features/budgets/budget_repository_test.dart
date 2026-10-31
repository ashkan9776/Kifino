import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:kifino/features/budgets/domain/entities/budget_entity.dart';

void main() {
  late AppDatabase db;
  late BudgetRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = BudgetRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BudgetRepositoryImpl in-memory tests', () {
    test('Creates and gets budgets accurately', () async {
      final now = DateTime.now();
      final budget = BudgetEntity(
        id: 'budget-1',
        name: 'ماهانه خوراک',
        amountLimit: const Money(minorUnits: 5000000, currency: Currency.irr),
        amountSpent: const Money(minorUnits: 1200000, currency: Currency.irr),
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      final result = await repository.createBudget(budget);
      expect(result.isSuccess, isTrue);

      final budgets = await repository.getActiveBudgets();
      expect(budgets.isSuccess, isTrue);
      expect(budgets.dataOrNull!.length, equals(1));
      expect(budgets.dataOrNull!.first.name, equals('ماهانه خوراک'));
      expect(budgets.dataOrNull!.first.amountLimit.minorUnits, equals(5000000));
    });

    test('Soft deletes budget', () async {
      final now = DateTime.now();
      final budget = BudgetEntity(
        id: 'b-del',
        name: 'حذف شونده',
        amountLimit: const Money(minorUnits: 1000000, currency: Currency.irr),
        amountSpent: const Money(minorUnits: 0, currency: Currency.irr),
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      await repository.createBudget(budget);
      await repository.deleteBudget('b-del');

      final active = await repository.getActiveBudgets();
      expect(active.dataOrNull!.isEmpty, isTrue);
    });
  });
}
