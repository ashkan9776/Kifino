import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../design_system/tokens/colors.dart';
import '../design_system/tokens/radii.dart';
import 'app_card.dart';
import 'app_money_text.dart';

// Status pills live in the design system (they pair every colour with an
// icon, so status is never conveyed by colour alone); re-exported here so
// screens get the whole kit from one import.
export '../design_system/components/financial/app_status_badge.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// KIFINO 2 KIT — the building blocks every screen is composed from.
///
/// Screens should read like a list of these: a hero, a stat row, a list
/// group, a sheet. Anything bespoke is a smell; extend the kit instead.
/// ─────────────────────────────────────────────────────────────────────────

/// Dark ink summary surface (net worth, module summaries). Text on it uses
/// [AppColors.onInk] / [AppColors.onInkSecondary].
class AppHeroCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const AppHeroCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(KifinoRadii.xl);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: isDark ? KifinoPalette.heroDark : KifinoPalette.heroLight,
          borderRadius: radius,
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Label + value pair used inside an [AppHeroCard].
class AppHeroStat extends StatelessWidget {
  final String label;
  final Widget value;
  final IconData? icon;
  final Color? iconColor;

  const AppHeroStat({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.onInk).withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor ?? AppColors.onInk),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onInkSecondary,
                ),
              ),
              MoneyTextStyle(
                style: AppTypography.moneySub.copyWith(
                  color: AppColors.onInk,
                  fontWeight: FontWeight.w700,
                ),
                child: DefaultTextStyle.merge(
                  style: AppTypography.moneySub.copyWith(
                    color: AppColors.onInk,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: value,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A small metric on a normal surface: label, value, optional icon & tone.
class AppStatTile extends StatelessWidget {
  final String label;
  final Widget value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  const AppStatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final tone = color ?? Theme.of(context).colorScheme.primary;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: tone),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          MoneyTextStyle(
            style: AppTypography.moneyTile.copyWith(color: colors.textPrimary),
            child: DefaultTextStyle.merge(
              style: AppTypography.moneyTile.copyWith(
                color: colors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}

/// A card of rows separated by inset dividers (settings lists, details).
class AppListGroup extends StatelessWidget {
  final List<Widget> children;
  final String? title;
  final EdgeInsetsGeometry margin;

  const AppListGroup({
    super.key,
    required this.children,
    this.title,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final visible = children.whereType<Widget>().toList();
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
              child: Text(
                title!,
                style: AppTypography.labelLarge.copyWith(
                  color: context.customColors.textSecondary,
                ),
              ),
            ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, child) in visible.indexed) ...[
                  if (i > 0) const Divider(indent: 64),
                  child,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row: icon badge, title/subtitle, then a value and/or chevron.
class AppListRow extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool destructive;
  final bool enabled;

  const AppListRow({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.destructive = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final tone = destructive
        ? colors.expense
        : (iconColor ?? Theme.of(context).colorScheme.primary);
    final lead =
        leading ??
        (icon == null
            ? null
            : AppIconBadge(icon: icon!, color: tone, size: 38, iconSize: 19));

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                if (lead != null) ...[lead, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          color: destructive
                              ? colors.expense
                              : colors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 8),
                  // Hugs its text next to the chevron (a Flexible here split
                  // the row 50/50 and floated the value mid-row).
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                if (onTap != null && showChevron && trailing == null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal single-select filter chips («همه / دریافتی / صادره»).
class AppFilterBar<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  const AppFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final (value, label) = options[i];
          return ChoiceChip(
            label: Text(label),
            selected: value == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(value),
          );
        },
      ),
    );
  }
}

/// Titled inline notice (info / warning / error) inside a screen.
class AppNotice extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(KifinoRadii.md),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: context.customColors.textPrimary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Opens the one standard bottom sheet: drag handle, title row with close,
/// scrollable body that rises above the keyboard, optional pinned action.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  Widget? primaryAction,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    builder: (sheetContext) {
      final insets = MediaQuery.viewInsetsOf(sheetContext).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: AppTypography.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'بستن',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: builder(sheetContext),
                ),
              ),
              if (primaryAction != null)
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: primaryAction,
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Grid of selectable icon tiles (categories, account types, templates).
class AppChoiceGrid<T> extends StatelessWidget {
  final List<AppChoice<T>> choices;
  final T? selected;
  final ValueChanged<T> onSelected;
  final int columns;

  const AppChoiceGrid({
    super.key,
    required this.choices,
    required this.selected,
    required this.onSelected,
    this.columns = 4,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in choices)
              SizedBox(
                width: width,
                child: _ChoiceTile(
                  choice: c,
                  // Action-only tiles (null value) are never "selected".
                  selected: c.value != null && c.value == selected,
                  onTap: () =>
                      c.onTap != null ? c.onTap!() : onSelected(c.value as T),
                  colors: colors,
                ),
              ),
          ],
        );
      },
    );
  }
}

class AppChoice<T> {
  final T? value;
  final String label;
  final IconData icon;
  final Color color;

  /// Overrides selection (e.g. a «more…» / «manage» tile).
  final VoidCallback? onTap;

  const AppChoice({
    this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

class _ChoiceTile<T> extends StatelessWidget {
  final AppChoice<T> choice;
  final bool selected;
  final VoidCallback onTap;
  final KifinoColorsExtension colors;

  const _ChoiceTile({
    required this.choice,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(KifinoRadii.md);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? choice.color.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? choice.color : colors.surfaceBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              children: [
                AppIconBadge(
                  icon: choice.icon,
                  color: choice.color,
                  size: 36,
                  iconSize: 18,
                ),
                const SizedBox(height: 6),
                Text(
                  choice.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Parses `#RRGGBB` / `AARRGGBB` category colors; null when unusable.
Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.replaceFirst('#', '');
  final v = int.tryParse(
    cleaned.length == 6 ? 'FF$cleaned' : cleaned,
    radix: 16,
  );
  return v == null ? null : Color(v);
}

/// A figure shown under the headline of an [AppSummaryHero].
class AppHeroFigure {
  final String label;
  final Widget value;
  final IconData? icon;
  final Color? color;

  const AppHeroFigure({
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });
}

/// The standard module summary: a caption, one headline value and up to
/// three supporting figures, on the ink surface.
class AppSummaryHero extends StatelessWidget {
  final String caption;
  final Widget headline;
  final String? footnote;
  final List<AppHeroFigure> figures;
  final VoidCallback? onTap;

  /// Optional 0..1 progress shown under the headline (goals, budgets…).
  final double? progress;
  final Color? progressColor;

  const AppSummaryHero({
    super.key,
    required this.caption,
    required this.headline,
    this.footnote,
    this.figures = const [],
    this.onTap,
    this.progress,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return AppHeroCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.onInkSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          MoneyTextStyle(
            style: AppTypography.moneyHeadline.copyWith(color: AppColors.onInk),
            child: DefaultTextStyle.merge(
              style: AppTypography.moneyHeadline.copyWith(
                color: AppColors.onInk,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: headline,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusPill,
              child: LinearProgressIndicator(
                value: progress!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                color: progressColor ?? AppColors.primaryBlueDark,
              ),
            ),
          ],
          if (footnote != null) ...[
            const SizedBox(height: 6),
            Text(
              footnote!,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onInkSecondary,
              ),
            ),
          ],
          if (figures.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (final f in figures)
                  Expanded(
                    child: AppHeroStat(
                      label: f.label,
                      icon: f.icon,
                      iconColor: f.color,
                      value: f.value,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
