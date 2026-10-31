import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class CashFlowChart extends StatelessWidget {
  final List<TransactionEntity> transactions;
  final Currency currency;

  const CashFlowChart({
    super.key,
    required this.transactions,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    // Aggregate into 6 periods (e.g., past 6 intervals of 5 days each for a 30-day view)
    final now = DateTime.now();
    final intervalDays = 5;
    final intervalsCount = 6;

    final incomeValues = List.filled(intervalsCount, 0.0);
    final expenseValues = List.filled(intervalsCount, 0.0);
    int totalIncomeMinor = 0;
    int totalExpenseMinor = 0;

    for (final tx in transactions) {
      if (tx.isDeleted) continue;
      final diffDays = now.difference(tx.date).inDays;
      if (diffDays >= 0 && diffDays < (intervalDays * intervalsCount)) {
        final bucket = (intervalsCount - 1) - (diffDays ~/ intervalDays);
        if (bucket >= 0 && bucket < intervalsCount) {
          final amountMajor = tx.amount.minorUnits / 1000.0; // scale for chart display
          if (tx.type == TransactionType.income) {
            incomeValues[bucket] += amountMajor;
            totalIncomeMinor += tx.amount.minorUnits;
          } else if (tx.type == TransactionType.expense) {
            expenseValues[bucket] += amountMajor;
            totalExpenseMinor += tx.amount.minorUnits;
          }
        }
      }
    }

    final maxVal = [
      ...incomeValues,
      ...expenseValues,
      10.0,
    ].reduce((a, b) => a > b ? a : b);

    final barGroups = List.generate(intervalsCount, (i) {
      return BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: incomeValues[i],
            color: AppColors.income,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          BarChartRodData(
            toY: expenseValues[i],
            color: AppColors.expense,
            width: 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      );
    });

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    l10n.cashFlowTrend,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              // Legend: Income vs Expense
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.income,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.income,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.expense,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.expense,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.income,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                    ),
                  ),
                  AppMoneyText(
                    money: Money.fromMinor(totalIncomeMinor, currency),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.income,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.expense,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                    ),
                  ),
                  AppMoneyText(
                    money: Money.fromMinor(totalExpenseMinor, currency),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.15,
                barGroups: barGroups,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
