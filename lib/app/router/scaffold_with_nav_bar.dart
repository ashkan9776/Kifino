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
      (
        Icons.receipt_long_rounded,
        l10n.isPersian ? 'فاکتور' : 'Invoice',
        isDark ? AppColors.primaryBlueDark : AppColors.primaryBlueLight,
        () => context.push('/business'),
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
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
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: FloatingActionButton(
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

/// Modern floating dock: a pill with the five destinations plus a detached
/// gradient add-button beside it. Replaces the old center-docked FAB that
/// overlapped the middle tab.
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
      (Icons.dashboard_outlined, Icons.dashboard_rounded, l10n.navHome),
      (
        Icons.receipt_long_outlined,
        Icons.receipt_long_rounded,
        l10n.navActivity,
      ),
      (Icons.insights_outlined, Icons.insights_rounded, l10n.navAnalytics),
      (
        Icons.business_center_outlined,
        Icons.business_center_rounded,
        l10n.navBusiness,
      ),
      (Icons.more_horiz_rounded, Icons.more_horiz_rounded, l10n.navMore),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 62,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: AppSpacing.borderRadiusXl,
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.10,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
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
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _NavAddButton(onTap: onAdd),
          ],
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
    final idle = isDark
        ? AppColors.darkTextTertiary
        : AppColors.lightTextTertiary;
    final color = selected ? primary : idle;

    return Expanded(
      child: Tooltip(
        message: label,
        preferBelow: false,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppSpacing.borderRadiusMd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? selectedIcon : icon, size: 22, color: color),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: AppTypography.labelMedium.copyWith(
                        fontSize: 9.5,
                        color: color,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: isDark
                  ? KifinoPalette.actionDark
                  : KifinoPalette.actionLight,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: KifinoPalette.cyan500.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
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
