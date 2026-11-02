import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../features/accounts/domain/entities/account_entity.dart';
import '../utils/text_normalizer.dart';
import 'app_card.dart';
import 'app_money_text.dart';

class AppAccountCard extends StatelessWidget {
  final AccountEntity account;
  final VoidCallback? onTap;

  const AppAccountCard({super.key, required this.account, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconData = switch (account.type) {
      AccountType.bankCard => Icons.credit_card_rounded,
      AccountType.cashWallet => Icons.account_balance_wallet_rounded,
      AccountType.savings => Icons.savings_rounded,
      AccountType.credit => Icons.credit_score_rounded,
      AccountType.investment => Icons.trending_up_rounded,
      AccountType.crypto => Icons.currency_bitcoin_rounded,
    };

    return AppCard(
      onTap: onTap,
      width: 240,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      backgroundColor: isDark
          ? AppColors.darkSurfaceVariant
          : AppColors.lightSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.1),
                  borderRadius: AppSpacing.borderRadiusSm,
                ),
                child: Icon(
                  iconData,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              if (account.cardNumberLastFour != null)
                Text(
                  '•••• ${TextNormalizer.auto(account.cardNumberLastFour!)}',
                  style: AppTypography.labelMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: AppTypography.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              AppMoneyText(
                money: account.currentBalance,
                style: AppTypography.moneyTile,
                usePersianDigits: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
