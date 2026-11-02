import '../../../../core/utils/money.dart';
import '../../../budgets/domain/entities/budget_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class CashFlowResult {
  final Money totalIncome;
  final Money totalExpense;
  final Money netCashFlow;
  final Money dailyAverageExpense;

  const CashFlowResult({
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashFlow,
    required this.dailyAverageExpense,
  });
}

class CashFlowCalculator {
  static CashFlowResult calculate({
    required List<TransactionEntity> transactions,
    required Currency currency,
    int daysCount = 30,
  }) {
    int incomeMinor = 0;
    int expenseMinor = 0;

    for (final tx in transactions) {
      if (tx.type == TransactionType.income) {
        incomeMinor += tx.amount.minorUnits;
      } else if (tx.type == TransactionType.expense) {
        expenseMinor += tx.amount.minorUnits;
      }
    }

    final totalIncome = Money.fromMinor(incomeMinor, currency);
    final totalExpense = Money.fromMinor(expenseMinor, currency);
    final netCashFlow = totalIncome - totalExpense;

    final effectiveDays = daysCount > 0 ? daysCount : 1;
    final dailyMinor = (expenseMinor / effectiveDays).round();
    final dailyAverageExpense = Money.fromMinor(dailyMinor, currency);

    return CashFlowResult(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netCashFlow: netCashFlow,
      dailyAverageExpense: dailyAverageExpense,
    );
  }
}

class RunwayCalculator {
  /// Calculates financial runway in months:
  /// runwayMonths = liquidBalance / averageMonthlyExpense
  static double calculate({
    required Money liquidBalance,
    required Money averageMonthlyExpense,
  }) {
    if (averageMonthlyExpense.minorUnits <= 0) {
      return liquidBalance.minorUnits > 0 ? 99.9 : 0.0;
    }
    final months = liquidBalance.minorUnits / averageMonthlyExpense.minorUnits;
    return double.parse(months.toStringAsFixed(1));
  }
}

class SavingsRateResult {
  final double percentage;
  final bool isPositive;

  const SavingsRateResult({required this.percentage, required this.isPositive});
}

class SavingsRateCalculator {
  /// Savings Rate = ((Income - Expense) / Income) * 100
  static SavingsRateResult calculate({
    required Money totalIncome,
    required Money totalExpense,
  }) {
    if (totalIncome.minorUnits <= 0) {
      return const SavingsRateResult(percentage: 0.0, isPositive: false);
    }

    final savedMinor = totalIncome.minorUnits - totalExpense.minorUnits;
    final rate = (savedMinor / totalIncome.minorUnits) * 100;
    return SavingsRateResult(
      percentage: double.parse(rate.clamp(-100.0, 100.0).toStringAsFixed(1)),
      isPositive: savedMinor >= 0,
    );
  }
}

class BudgetHealthResult {
  final double overallAdherencePercent; // 0 - 100%
  final int totalBudgets;
  final int overBudgetCount;
  final int nearLimitCount;
  final int onTrackCount;

  const BudgetHealthResult({
    required this.overallAdherencePercent,
    required this.totalBudgets,
    required this.overBudgetCount,
    required this.nearLimitCount,
    required this.onTrackCount,
  });
}

class BudgetAdherenceCalculator {
  static BudgetHealthResult calculate(List<BudgetEntity> budgets) {
    if (budgets.isEmpty) {
      return const BudgetHealthResult(
        overallAdherencePercent: 100.0,
        totalBudgets: 0,
        overBudgetCount: 0,
        nearLimitCount: 0,
        onTrackCount: 0,
      );
    }

    int overCount = 0;
    int nearCount = 0;
    int onTrack = 0;
    int totalLimit = 0;
    int totalSpent = 0;

    for (final b in budgets) {
      totalLimit += b.amountLimit.minorUnits;
      totalSpent += b.amountSpent.minorUnits;

      if (b.isOverBudget) {
        overCount++;
      } else if (b.isNearLimit) {
        nearCount++;
      } else {
        onTrack++;
      }
    }

    double adherence = 100.0;
    if (totalLimit > 0) {
      final spentRatio = totalSpent / totalLimit;
      if (spentRatio <= 1.0) {
        adherence = (1.0 - spentRatio * 0.2) * 100; // Still on budget
      } else {
        adherence = (1.0 / spentRatio) * 80; // Penalize overspend
      }
    }

    return BudgetHealthResult(
      overallAdherencePercent: double.parse(
        adherence.clamp(0.0, 100.0).toStringAsFixed(1),
      ),
      totalBudgets: budgets.length,
      overBudgetCount: overCount,
      nearLimitCount: nearCount,
      onTrackCount: onTrack,
    );
  }
}
