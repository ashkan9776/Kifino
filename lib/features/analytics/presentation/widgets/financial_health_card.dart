import 'package:flutter/material.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_kit.dart';
import '../../../../core/widgets/app_money_text.dart';

/// «وضعیت مالی»: four health metrics as a 2×2 grid. A metric with no data
/// shows «—» in a neutral tone instead of a made-up score.
class FinancialHealthCard extends StatelessWidget {
  /// Null when there is no spending to measure a runway against.
  final double? runwayMonths;

  /// Null when there is no income in the period.
  final double? savingsRatePercent;

  /// Null when no budget is set.
  final double? budgetAdherencePercent;
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
    final l10n = context.l10n;
    final colors = context.customColors;
    final neutral = colors.textTertiary;

    Color tone(double? v, double good, double ok) => v == null
        ? neutral
        : v >= good
        ? colors.income
        : (v >= ok ? colors.warning : colors.expense);

    Widget text(String s, Color c) => Text(
      s,
      style: TextStyle(color: c, fontWeight: FontWeight.w700),
    );

    final runway = runwayMonths;
    final savings = savingsRatePercent;
    final adherence = budgetAdherencePercent;

    final tiles = [
      AppStatTile(
        label: l10n.runway,
        icon: Icons.hourglass_bottom_rounded,
        color: tone(runway, 6, 3),
        value: text(
          runway == null
              ? '—'
              : TextNormalizer.auto(
                  '${runway > 99 ? '+۹۹' : runway.toStringAsFixed(1)} ${l10n.months}',
                ),
          tone(runway, 6, 3),
        ),
      ),
      AppStatTile(
        label: l10n.savingsRate,
        icon: Icons.savings_outlined,
        color: tone(savings, 20, 0),
        value: text(
          savings == null
              ? '—'
              : TextNormalizer.auto('${savings.toStringAsFixed(0)}٪'),
          tone(savings, 20, 0),
        ),
      ),
      AppStatTile(
        label: l10n.budgetAdherence,
        icon: Icons.donut_large_rounded,
        color: tone(adherence, 85, 65),
        value: text(
          adherence == null
              ? '—'
              : TextNormalizer.auto('${adherence.toStringAsFixed(0)}٪'),
          tone(adherence, 85, 65),
        ),
      ),
      AppStatTile(
        label: l10n.isPersian ? 'میانگین هزینه روزانه' : 'Daily average',
        icon: Icons.today_outlined,
        color: colors.textSecondary,
        value: AppMoneyText(
          money: dailyAverageExpense,
          usePersianDigits: true,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          title: l10n.isPersian ? 'وضعیت مالی' : 'Financial health',
        ),
        Row(
          children: [
            Expanded(child: tiles[0]),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: tiles[1]),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(child: tiles[2]),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: tiles[3]),
          ],
        ),
      ],
    );
  }
}
