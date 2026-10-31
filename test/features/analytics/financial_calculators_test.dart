import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/analytics/domain/services/financial_calculators.dart';
import 'package:kifino/features/budgets/domain/entities/budget_entity.dart';
import 'package:kifino/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  group('CashFlowCalculator Tests', () {
    final now = DateTime.now();

    test('Computes total income, expense, net cash flow, and daily average accurately', () {
      final transactions = <TransactionEntity>[
        TransactionEntity(
          id: 'tx-1',
          accountId: 'acc-1',
          categoryId: 'cat-income',
          amount: const Money(minorUnits: 10000000, currency: Currency.irr), // 10,000,000
          type: TransactionType.income,
          description: 'حقوق',
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
        TransactionEntity(
          id: 'tx-2',
          accountId: 'acc-1',
          categoryId: 'cat-food',
          amount: const Money(minorUnits: 3000000, currency: Currency.irr), // 3,000,000
          type: TransactionType.expense,
          description: 'خرید غذا',
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = CashFlowCalculator.calculate(
        transactions: transactions,
        currency: Currency.irr,
        daysCount: 30,
      );

      expect(result.totalIncome.minorUnits, equals(10000000));
      expect(result.totalExpense.minorUnits, equals(3000000));
      expect(result.netCashFlow.minorUnits, equals(7000000));
      expect(result.dailyAverageExpense.minorUnits, equals(100000)); // 3,000,000 / 30
    });
  });

  group('RunwayCalculator Tests', () {
    test('Calculates runway months based on liquid balance and monthly expense', () {
      const liquid = Money(minorUnits: 50000000, currency: Currency.irr); // 50M
      const monthlyExpense = Money(minorUnits: 10000000, currency: Currency.irr); // 10M

      final runway = RunwayCalculator.calculate(
        liquidBalance: liquid,
        averageMonthlyExpense: monthlyExpense,
      );

      expect(runway, equals(5.0));
    });

    test('Returns 99.9 if expense is zero and balance is positive', () {
      final runway = RunwayCalculator.calculate(
        liquidBalance: const Money(minorUnits: 1000, currency: Currency.irr),
        averageMonthlyExpense: const Money(minorUnits: 0, currency: Currency.irr),
      );

      expect(runway, equals(99.9));
    });
  });

  group('SavingsRateCalculator Tests', () {
    test('Calculates positive savings rate', () {
      const income = Money(minorUnits: 10000000, currency: Currency.irr);
      const expense = Money(minorUnits: 4000000, currency: Currency.irr);

      final result = SavingsRateCalculator.calculate(
        totalIncome: income,
        totalExpense: expense,
      );

      expect(result.isPositive, isTrue);
      expect(result.percentage, equals(60.0));
    });

    test('Calculates negative savings rate when expenses exceed income', () {
      const income = Money(minorUnits: 5000000, currency: Currency.irr);
      const expense = Money(minorUnits: 7500000, currency: Currency.irr);

      final result = SavingsRateCalculator.calculate(
        totalIncome: income,
        totalExpense: expense,
      );

      expect(result.isPositive, isFalse);
      expect(result.percentage, equals(-50.0));
    });
  });

  group('BudgetAdherenceCalculator Tests', () {
    final now = DateTime.now();

    test('Calculates budget health metrics and over-budget counts correctly', () {
      final budgets = [
        BudgetEntity(
          id: 'b-1',
          name: 'Food',
          amountLimit: const Money(minorUnits: 1000000, currency: Currency.irr),
          amountSpent: const Money(minorUnits: 850000, currency: Currency.irr), // 85% -> near limit
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          createdAt: now,
          updatedAt: now,
        ),
        BudgetEntity(
          id: 'b-2',
          name: 'Transport',
          amountLimit: const Money(minorUnits: 500000, currency: Currency.irr),
          amountSpent: const Money(minorUnits: 600000, currency: Currency.irr), // 120% -> over budget
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          createdAt: now,
          updatedAt: now,
        ),
        BudgetEntity(
          id: 'b-3',
          name: 'Entertainment',
          amountLimit: const Money(minorUnits: 1000000, currency: Currency.irr),
          amountSpent: const Money(minorUnits: 200000, currency: Currency.irr), // 20% -> on track
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final health = BudgetAdherenceCalculator.calculate(budgets);

      expect(health.totalBudgets, equals(3));
      expect(health.overBudgetCount, equals(1));
      expect(health.nearLimitCount, equals(1));
      expect(health.onTrackCount, equals(1));
      expect(health.overallAdherencePercent, greaterThan(0.0));
    });
  });
}
