import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../utils/money.dart';
import '../../../widgets/app_money_text.dart';

/// Compact metric card for headline financial figures: Income,
/// Expense, Profit, Debt, Receivable — icon + label + big tabular value.
class AppMetricCard extends StatelessWidget {
  final String label;
  final Money value;
  final IconData icon;
  final Color color;
  final MoneyDisplaySign sign;

  /// Optional compact delta line, e.g. «۸.۴٪ این ماه».
  final String? delta;

  const AppMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.sign = MoneyDisplaySign.none,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AppMoneyText(
            money: value,
            sign: sign,
            style: AppTypography.moneyTile.copyWith(color: color),
            colorCode: false,
          ),
          if (delta != null) ...[
            const SizedBox(height: 2),
            Text(
              delta!,
              style: AppTypography.labelMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
