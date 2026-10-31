import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';

/// Semantic status pill: small, tinted background, icon + label.
///
/// Never color alone — the icon always repeats the meaning (,).
/// Variants map to financial states: paid/success, pending/warning,
/// overdue/failed, info, neutral.
enum AppStatusTone { success, warning, danger, info, neutral }

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
    final (Color color, Color bg) = switch ((tone, isDark)) {
      (AppStatusTone.success, false) => (const Color(0xFF25C997), const Color(0xFFE7FAF3)),
      (AppStatusTone.success, true) => (const Color(0xFF39E6A5), const Color(0xFF0B2E24)),
      (AppStatusTone.warning, false) => (const Color(0xFFFFB547), const Color(0xFFFFF4E0)),
      (AppStatusTone.warning, true) => (const Color(0xFFFFCA58), const Color(0xFF33230A)),
      (AppStatusTone.danger, false) => (const Color(0xFFFF5C6C), const Color(0xFFFFECEE)),
      (AppStatusTone.danger, true) => (const Color(0xFFFF7A87), const Color(0xFF3A1218)),
      (AppStatusTone.info, false) => (const Color(0xFF4C9AFF), const Color(0xFFEAF3FF)),
      (AppStatusTone.info, true) => (const Color(0xFF4C9AFF), const Color(0xFF0E2036)),
      (AppStatusTone.neutral, false) => (const Color(0xFF687386), const Color(0xFFF1F5F9)),
      (AppStatusTone.neutral, true) => (const Color(0xFF94A3B8), const Color(0xFF12243A)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
