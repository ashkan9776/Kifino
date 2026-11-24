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

    final colors = context.customColors;
    final accent = switch (account.type) {
      AccountType.cashWallet => colors.income,
      AccountType.savings => colors.asset,
      AccountType.credit => colors.expense,
      AccountType.investment || AccountType.crypto => colors.business,
      AccountType.bankCard => Theme.of(context).colorScheme.primary,
    };
    final subtitle = [
      account.type.titleFa,
      if (account.cardNumberLastFour != null)
        '•••• ${TextNormalizer.auto(account.cardNumberLastFour!)}',
    ].join('  ·  ');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: iconData,
                color: accent,
                size: 38,
                iconSize: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: AppTypography.titleSmall.copyWith(
                        color: colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppMoneyText(
            money: account.currentBalance,
            style: AppTypography.moneyTile.copyWith(
              fontSize: 17,
              color: colors.textPrimary,
            ),
            usePersianDigits: true,
          ),
        ],
      ),
    );
  }
}
