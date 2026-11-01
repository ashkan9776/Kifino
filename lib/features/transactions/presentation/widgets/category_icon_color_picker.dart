import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/icon_utils.dart';

/// Curated finance-focused Material icons shared by the category editor.
///
/// Kept in presentation (not in core [IconUtils], whose smaller registry would
/// fall back to a generic icon) so every glyph offered in the picker is also
/// resolvable back from its stored `iconCodePoint` anywhere in the feature.
class CategoryIconAssets {
  CategoryIconAssets._();

  /// ~30 curated Material (rounded) finance/lifestyle icons.
  static const List<IconData> icons = [
    Icons.shopping_bag_rounded,
    Icons.restaurant_rounded,
    Icons.restaurant_menu_rounded,
    Icons.local_taxi_rounded,
    Icons.directions_car_rounded,
    Icons.flight_rounded,
    Icons.home_rounded,
    Icons.bolt_rounded,
    Icons.medical_services_rounded,
    Icons.health_and_safety_rounded,
    Icons.school_rounded,
    Icons.fitness_center_rounded,
    Icons.movie_rounded,
    Icons.sports_esports_rounded,
    Icons.pets_rounded,
    Icons.redeem_rounded,
    Icons.payments_rounded,
    Icons.checkroom_rounded,
    Icons.local_cafe_rounded,
    Icons.smartphone_rounded,
    Icons.wifi_rounded,
    Icons.subscriptions_rounded,
    Icons.savings_rounded,
    Icons.work_rounded,
    Icons.child_care_rounded,
    // laundry_rounded does not exist in this Flutter SDK's icon font —
    // local_laundry_service_rounded (washing machine) is the same subject.
    Icons.local_laundry_service_rounded,
    Icons.gas_meter_rounded,
    Icons.volunteer_activism_rounded,
    // repair_rounded is likewise unavailable; construction_rounded (hammer &
    // wrench) carries the "repair" meaning.
    Icons.construction_rounded,
    Icons.agriculture_rounded,
  ];

  static final Map<int, IconData> _byCodePoint = {
    for (final icon in icons) icon.codePoint: icon,
  };

  /// Resolves a DB codePoint to a constant IconData: curated set first, then
  /// the core registry (covers seeded default icons), then the safe fallback.
  static IconData resolve(int codePoint) =>
      _byCodePoint[codePoint] ?? IconUtils.getIconData(codePoint);

  /// Preset brand palette (12 colors, `RRGGBB`, no leading `#`).
  static const List<String> presetHexes = [
    'FF5C6C', // red
    'FF9F43', // orange
    'FFB547', // amber
    'FFCA58', // yellow
    '25C997', // green
    '39E6A5', // mint
    '20C8E8', // teal
    '247BFF', // blue
    '6366F1', // indigo
    '8B7CFF', // purple
    'F472B6', // pink
    '64748B', // grey
  ];

  /// Parses stored colorHex values robustly: accepts `RRGGBB`, `AARRGGBB` and
  /// an optional leading `#` (seeded rows are stored like `#EF4444`).
  static Color colorFromHex(String hex) {
    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    final parsed = int.tryParse(value, radix: 16) ?? 0xFF64748B;
    return Color(parsed);
  }

  /// Normalizes any stored colorHex back to the bare `RRGGBB` form used by
  /// [presetHexes] so selections can be compared.
  static String normalizeHex(String hex) =>
      hex.trim().replaceFirst('#', '').toUpperCase();
}

/// Grid of selectable category icons. [selectedCodePoint] gets a ring
/// highlight; tapping reports the picked icon's codePoint back via [onSelect].
class CategoryIconGrid extends StatelessWidget {
  final int selectedCodePoint;
  final ValueChanged<int> onSelect;

  const CategoryIconGrid({
    super.key,
    required this.selectedCodePoint,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final idleColor = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1,
      children: CategoryIconAssets.icons.map((icon) {
        final isSelected = icon.codePoint == selectedCodePoint;
        return InkWell(
          onTap: () => onSelect(icon.codePoint),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: 0.12)
                  : (isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurfaceVariant),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: isSelected ? primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isSelected ? primary : idleColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Row of 12 preset color swatches. The selected swatch gets a ring
/// highlight (colored outline with a gap) plus a contrast-checked checkmark.
class CategoryColorPalette extends StatelessWidget {
  final String selectedHex;
  final ValueChanged<String> onSelect;

  const CategoryColorPalette({
    super.key,
    required this.selectedHex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: CategoryIconAssets.presetHexes.map((hex) {
        final color = CategoryIconAssets.colorFromHex(hex);
        final isSelected =
            CategoryIconAssets.normalizeHex(hex) ==
            CategoryIconAssets.normalizeHex(selectedHex);
        return InkWell(
          onTap: () => onSelect(hex),
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: isDark
                    ? Border.all(color: Colors.white24, width: 0.5)
                    : null,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: color.computeLuminance() > 0.6
                          ? Colors.black87
                          : Colors.white,
                    )
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
