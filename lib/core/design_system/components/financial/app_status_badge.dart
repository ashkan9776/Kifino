import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';

/// Semantic status pill: small, tinted background, icon + label.
///
/// Never colour alone — the icon always repeats the meaning. Tones map to
/// financial states and resolve through the Kifino 2 semantic colours, so
/// they follow light/dark mode and any future palette change.
enum AppStatusTone { success, warning, danger, info, neutral, premium }

class AppStatusBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppStatusTone tone;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.icon,
    this.tone = AppStatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = context.customColors;
    final color = switch (tone) {
      AppStatusTone.success => c.income,
      AppStatusTone.warning => c.warning,
      AppStatusTone.danger => c.expense,
      AppStatusTone.info => c.receivable,
      AppStatusTone.neutral => c.textSecondary,
      AppStatusTone.premium => c.business,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
