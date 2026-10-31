import '../../../../core/constants/app_currency.dart';
import '../../../../core/utils/money.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../budgets/domain/entities/budget_entity.dart';
import '../../../debts/domain/entities/debt_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class FinancialContextSummary {
  final Money netWorth;
  final Money monthlyIncome;
  final Money monthlyExpense;
  final double savingsRate;
  final double runwayMonths;
  final int overspentBudgetsCount;
  final Money totalDebts;
  final Money totalReceivables;
  final Map<String, int> topSpendingCategories;
  final int healthScore;

  const FinancialContextSummary({
    required this.netWorth,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.savingsRate,
    required this.runwayMonths,
    required this.overspentBudgetsCount,
    required this.totalDebts,
    required this.totalReceivables,
    required this.topSpendingCategories,
    required this.healthScore,
  });
}

class FinancialContextProvider {
  static FinancialContextSummary buildSummary({
    required List<AccountEntity> accounts,
    required List<TransactionEntity> transactions,
    required List<BudgetEntity> budgets,
    required List<DebtEntity> debts,
  }) {
    final currency = AppCurrency.base;

    // 1. Net worth
    int netWorthMinor = 0;
    for (final acc in accounts) {
      if (acc.currentBalance.isCompatibleWith(currency)) {
        netWorthMinor += acc.currentBalance.normalizeTo(currency).minorUnits;
      }
    }

    // 2. 30-day income and expense
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    int monthlyIncomeMinor = 0;
    int monthlyExpenseMinor = 0;
    final categoryTotals = <String, int>{};

    for (final tx in transactions) {
      if (tx.date.isAfter(thirtyDaysAgo) && tx.amount.isCompatibleWith(currency)) {
        final minor = tx.amount.normalizeTo(currency).minorUnits;
        if (tx.type == TransactionType.income) {
          monthlyIncomeMinor += minor;
        } else if (tx.type == TransactionType.expense) {
          monthlyExpenseMinor += minor;

          final catName = tx.categoryName ?? 'سایر';
          categoryTotals[catName] = (categoryTotals[catName] ?? 0) + minor;
        }
      }
    }

    // 3. Savings Rate
    double savingsRate = 0.0;
    if (monthlyIncomeMinor > 0) {
      savingsRate = ((monthlyIncomeMinor - monthlyExpenseMinor) / monthlyIncomeMinor) * 100.0;
    }

    // 4. Runway
    double runway = 99.0;
    if (monthlyExpenseMinor > 0) {
      runway = (netWorthMinor / monthlyExpenseMinor).clamp(0.0, 99.9);
    }

    // 5. Budgets overspent
    int overspentCount = 0;
    for (final b in budgets) {
      if (b.isOverBudget) overspentCount++;
    }

    // 6. Debts & Receivables
    int debtMinor = 0;
    int recMinor = 0;
    for (final d in debts) {
      if (!d.isSettled && d.remainingAmount.isCompatibleWith(currency)) {
        final minor = d.remainingAmount.normalizeTo(currency).minorUnits;
        if (d.type == DebtType.debt) {
          debtMinor += minor;
        } else {
          recMinor += minor;
        }
      }
    }

    // 7. Health Score (0 - 100)
    int score = 50;
    if (runway >= 6.0) {
      score += 20;
    } else if (runway >= 3.0) {
      score += 10;
    } else {
      score -= 15;
    }

    if (savingsRate >= 20.0) {
      score += 20;
    } else if (savingsRate > 0) {
      score += 10;
    } else {
      score -= 15;
    }

    if (overspentCount == 0) {
      score += 10;
    } else {
      score -= (overspentCount * 5);
    }

    score = score.clamp(10, 100);

    return FinancialContextSummary(
      netWorth: Money.fromMinor(netWorthMinor, currency),
      monthlyIncome: Money.fromMinor(monthlyIncomeMinor, currency),
      monthlyExpense: Money.fromMinor(monthlyExpenseMinor, currency),
      savingsRate: savingsRate,
      runwayMonths: runway,
      overspentBudgetsCount: overspentCount,
      totalDebts: Money.fromMinor(debtMinor, currency),
      totalReceivables: Money.fromMinor(recMinor, currency),
      topSpendingCategories: categoryTotals,
      healthScore: score,
    );
  }
}
