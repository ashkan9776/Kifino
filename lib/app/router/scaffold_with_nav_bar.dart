import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';
import '../../core/design_system/tokens/colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _openQuickAddSheet(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = [
      (
        Icons.trending_up_rounded,
        l10n.isPersian ? 'درآمد' : 'Income',
        isDark ? AppColors.incomeDark : AppColors.incomeLight,
        () => context.push('/transaction/new', extra: 'income'),
      ),
      (
        Icons.trending_down_rounded,
        l10n.isPersian ? 'هزینه' : 'Expense',
        isDark ? AppColors.expenseDark : AppColors.expenseLight,
        () => context.push('/transaction/new', extra: 'expense'),
      ),
      (
        Icons.swap_horiz_rounded,
        l10n.isPersian ? 'انتقال' : 'Transfer',
        isDark ? AppColors.transferDark : AppColors.transferLight,
        () => context.push('/transaction/new', extra: 'transfer'),
      ),
      (
        Icons.event_repeat_rounded,
        l10n.isPersian ? 'تکراری' : 'Recurring',
        isDark ? AppColors.primaryBlueDark : AppColors.primaryBlueLight,
        () => context.push('/recurring'),
      ),
      (
        Icons.handshake_rounded,
        l10n.isPersian ? 'بدهی' : 'Debt',
        isDark ? AppColors.debtOrangeDark : AppColors.debtOrangeLight,
        () => context.push('/debts'),
      ),
      (
        Icons.credit_card_rounded,
        l10n.isPersian ? 'قسط' : 'Installment',
        isDark ? AppColors.accentIndigoLight : AppColors.accentIndigo,
        () => context.push('/installments'),
      ),
    ];

    final isDesktopOrTablet =
        MediaQuery.sizeOf(context).width >= AppSpacing.mobileBreakpoint;

    showModalBottomSheet<void>(
      context: context,
      constraints: BoxConstraints(
        maxWidth: isDesktopOrTablet ? 540 : double.infinity,
      ),
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            // The theme's drag handle already gives the top breathing room.
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.isPersian ? 'افزودن' : 'Add',
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.05,
                  children: [
                    for (final (icon, label, color, onTap) in actions)
                      _QuickAddTile(
                        icon: icon,
                        label: label,
                        color: color,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          onTap();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktopOrTablet = width >= AppSpacing.mobileBreakpoint;
    final isDesktop = width >= 1000.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDesktopOrTablet) {
      // Rail layout has no bottomNavigationBar, so inset the whole shell from
      // the system gesture bar; the strip below stays in scaffold background.
      return ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onTap,
                  extended: isDesktop,
                  minExtendedWidth: 230,
                  labelType: isDesktop
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                      horizontal: AppSpacing.sm,
                    ),
                    child: isDesktop
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: KifinoPalette.actionLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    l10n.isPersian ? 'کیفینو' : 'Kifino',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                width: 195,
                                child: FilledButton.icon(
                                  onPressed: () => _openQuickAddSheet(context),
                                  icon: const Icon(Icons.add_rounded, size: 20),
                                  label: Text(
                                    l10n.isPersian
                                        ? 'ثبت تراکنش'
                                        : 'Add Transaction',
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : FloatingActionButton(
                            onPressed: () => _openQuickAddSheet(context),
                            elevation: 0,
                            backgroundColor: isDark
                                ? AppColors.primaryBlueDark
                                : AppColors.primaryBlueLight,
                            foregroundColor: isDark
                                ? AppColors.darkBackground
                                : Colors.white,
                            child: const Icon(Icons.add_rounded, size: 28),
                          ),
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: IconButton(
                          tooltip: l10n.isPersian
                              ? 'تنظیمات و بیشتر'
                              : 'Settings & More',
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => context.push('/more'),
                        ),
                      ),
                    ),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.dashboard_outlined),
                      selectedIcon: const Icon(Icons.dashboard_rounded),
                      label: Text(l10n.navHome),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.receipt_long_outlined),
                      selectedIcon: const Icon(Icons.receipt_long_rounded),
                      label: Text(l10n.navActivity),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.insights_outlined),
                      selectedIcon: const Icon(Icons.insights_rounded),
                      label: Text(l10n.navAnalytics),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.business_center_outlined),
                      selectedIcon: const Icon(Icons.business_center_rounded),
                      label: Text(l10n.navBusiness),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.menu_rounded),
                      selectedIcon: const Icon(Icons.menu_open_rounded),
                      label: Text(l10n.navMore),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        onAdd: () => _openQuickAddSheet(context),
      ),
    );
  }
}

/// Kifino 2 bottom bar: a full-width surface attached to the screen edge
/// (hairline on top, no floating shadow) holding the five destinations and
/// the add button as one calm row.
class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final destinations = [
      (
        Icons.space_dashboard_outlined,
        Icons.space_dashboard_rounded,
        l10n.navHome,
      ),
      (
        Icons.receipt_long_outlined,
        Icons.receipt_long_rounded,
        l10n.navActivity,
      ),
      (Icons.insights_outlined, Icons.insights_rounded, l10n.navAnalytics),
      (Icons.storefront_outlined, Icons.storefront_rounded, l10n.navBusiness),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, l10n.navMore),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                for (final (index, (icon, selectedIcon, label))
                    in destinations.indexed)
                  _NavItem(
                    icon: icon,
                    selectedIcon: selectedIcon,
                    label: label,
                    selected: currentIndex == index,
                    onTap: () => onTap(index),
                  ),
                const SizedBox(width: 6),
                _NavAddButton(onTap: onAdd),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? AppColors.primaryBlueDark
        : AppColors.primaryBlueLight;
    final tint = isDark
        ? AppColors.primaryTintDark
        : AppColors.primaryTintLight;
    final idle = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;
    final color = selected ? primary : idle;

    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppSpacing.borderRadiusMd,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 48 : 36,
                height: 28,
                decoration: BoxDecoration(
                  color: selected ? tint : Colors.transparent,
                  borderRadius: AppSpacing.borderRadiusPill,
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: AppTypography.labelSmall.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavAddButton extends StatelessWidget {
  final VoidCallback onTap;

  const _NavAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: context.l10n.addTransaction,
      excludeSemantics: true,
      child: Material(
        color: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlueLight,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              Icons.add_rounded,
              color: isDark ? AppColors.darkBackground : Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAddTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAddTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusLg,
        child: Container(
          decoration: BoxDecoration(
            color: surface.withValues(alpha: 0.6),
            borderRadius: AppSpacing.borderRadiusLg,
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
