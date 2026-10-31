import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money_text.dart';

class FinancialHealthCard extends StatelessWidget {
  final double runwayMonths;
  final double savingsRatePercent;
  final double budgetAdherencePercent;
  final Money dailyAverageExpense;

  const FinancialHealthCard({
    super.key,
    required this.runwayMonths,
    required this.savingsRatePercent,
    required this.budgetAdherencePercent,
    required this.dailyAverageExpense,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  Icons.shield_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.financialHealth,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              // Runway
              Expanded(
                child: _MetricItem(
                  label: l10n.runway,
                  valueText: TextNormalizer.auto(
                    TextNormalizer.auto(
                      '${runwayMonths > 99 ? '> 99' : runwayMonths.toStringAsFixed(1)} ${l10n.months}',
                    ),
                  ),
                  valueColor: runwayMonths >= 6
                      ? AppColors.income
                      : (runwayMonths >= 3 ? AppColors.warning : AppColors.danger),
                  icon: Icons.hourglass_top_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Savings Rate
              Expanded(
                child: _MetricItem(
                  label: l10n.savingsRate,
                  valueText: TextNormalizer.auto('${savingsRatePercent.toStringAsFixed(1)}%'),
                  valueColor: savingsRatePercent >= 20
                      ? AppColors.income
                      : (savingsRatePercent >= 0 ? AppColors.primary : AppColors.danger),
                  icon: Icons.savings_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              // Budget Adherence
              Expanded(
                child: _MetricItem(
                  label: l10n.budgetAdherence,
                  valueText: TextNormalizer.auto('${budgetAdherencePercent.toStringAsFixed(0)}%'),
                  valueColor: budgetAdherencePercent >= 85
                      ? AppColors.income
                      : (budgetAdherencePercent >= 65 ? AppColors.warning : AppColors.danger),
                  icon: Icons.pie_chart_outline_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Daily Average
              Expanded(
                child: AppCard(
                  backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l10n.dailyAverage,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AppMoneyText(
                        money: dailyAverageExpense,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String valueText;
  final Color valueColor;
  final IconData icon;

  const _MetricItem({
    required this.label,
    required this.valueText,
    required this.valueColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            valueText,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
