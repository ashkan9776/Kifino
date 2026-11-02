import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../features/budgets/domain/entities/budget_entity.dart';
import '../utils/text_normalizer.dart';
import 'app_card.dart';
import 'app_money_text.dart';

class AppBudgetProgress extends StatelessWidget {
  final BudgetEntity budget;
  final VoidCallback? onTap;

  const AppBudgetProgress({super.key, required this.budget, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    final percent = budget.usagePercent;
    final progressValue = (percent / 100.0).clamp(0.0, 1.0);

    // Color logic
    final Color statusColor;
    final String statusLabel;
    if (budget.isOverBudget) {
      statusColor = AppColors.danger;
      statusLabel = l10n.overBudget;
    } else if (budget.isNearLimit) {
      statusColor = AppColors.warning;
      statusLabel = l10n.nearLimit;
    } else {
      statusColor = AppColors.primary;
      statusLabel = l10n.onTrack;
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  budget.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  TextNormalizer.auto(
                    '${percent.toStringAsFixed(0)}% · $statusLabel',
                  ),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${l10n.spent}: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.darkSubtext
                            : AppColors.lightSubtext,
                      ),
                    ),
                    Flexible(
                      child: AppMoneyText(
                        money: budget.amountSpent,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      budget.isOverBudget
                          ? '${l10n.overBudget}: '
                          : '${l10n.remaining}: ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: budget.isOverBudget
                            ? AppColors.danger
                            : (isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext),
                      ),
                    ),
                    Flexible(
                      child: AppMoneyText(
                        money: budget.remainingAmount.abs(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: budget.isOverBudget ? AppColors.danger : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
