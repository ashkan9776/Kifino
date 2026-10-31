import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../utils/date_utils.dart';
import '../utils/icon_utils.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';
import 'app_money_text.dart';

class AppTransactionTile extends StatelessWidget {
  final TransactionEntity transaction;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const AppTransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (iconData, iconBg, iconColor) = switch (transaction.type) {
      TransactionType.income => (
          Icons.arrow_downward_rounded,
          isDark ? colors.incomeBg : AppColors.incomeBgLight,
          colors.income,
        ),
      TransactionType.expense => (
          transaction.categoryIconCodePoint != null
              ? IconUtils.getIconData(transaction.categoryIconCodePoint!)
              : Icons.arrow_upward_rounded,
          isDark ? colors.expenseBg : AppColors.expenseBgLight,
          colors.expense,
        ),
      TransactionType.transfer => (
          Icons.swap_horiz_rounded,
          isDark ? colors.surfaceVariant : AppColors.lightSurfaceVariant,
          colors.transfer,
        ),
      _ => (
          Icons.receipt_rounded,
          isDark ? colors.surfaceVariant : AppColors.lightSurfaceVariant,
          Theme.of(context).colorScheme.primary,
        ),
    };

    final tile = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: AppSpacing.borderRadiusMd,
                ),
                child: Icon(iconData, color: iconColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.description.isNotEmpty
                          ? transaction.description
                          : (transaction.categoryName ?? 'تراکنش'),
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (transaction.accountName != null) ...[
                          Text(
                            transaction.accountName!,
                            style: AppTypography.labelMedium.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const Text(' • '),
                        ],
                        Text(
                          AppDateFormatter.formatRelative(transaction.date, locale: 'fa'),
                          style: AppTypography.labelMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppMoneyText(
                money: transaction.amount,
                sign: transaction.type == TransactionType.income
                    ? MoneyDisplaySign.positiveNegative
                    : (transaction.type == TransactionType.expense
                        ? MoneyDisplaySign.negativeOnly
                        : MoneyDisplaySign.none),
                style: AppTypography.moneyTile,
                colorCode: true,
                usePersianDigits: true,
              ),
            ],
          ),
        ),
      ),
    );

    if (onDelete != null) {
      return Dismissible(
        key: Key(transaction.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.expense,
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
        ),
        onDismissed: (_) => onDelete!(),
        child: tile,
      );
    }

    return tile;
  }
}
