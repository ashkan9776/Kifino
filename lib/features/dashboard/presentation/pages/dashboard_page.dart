import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_currency.dart';
import '../../../../core/design_system/tokens/colors.dart';
import '../../../../core/design_system/tokens/radii.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_account_card.dart';
import '../../../../core/widgets/app_budget_progress.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_responsive_container.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_transaction_tile.dart';
import '../../../accounts/presentation/bloc/accounts_bloc.dart';
import '../../../budgets/presentation/bloc/budget_bloc.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../widgets/upcoming_section.dart';

/// Kifino 2 home: what I have, what moved this month, what is coming, and
/// the few actions I take every day. Business and accounting tools live in
/// one compact card at the end instead of crowding the top.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _hideBalances = false;

  static String _greeting(bool isPersian) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return isPersian ? 'صبح بخیر' : 'Good morning';
    if (hour >= 12 && hour < 17) {
      return isPersian ? 'ظهر بخیر' : 'Good afternoon';
    }
    if (hour >= 17 && hour < 21) return isPersian ? 'عصر بخیر' : 'Good evening';
    return isPersian ? 'شب بخیر' : 'Good night';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.customColors;
    final today = JalaliDate.fromDateTime(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: AppSpacing.md,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(l10n.isPersian),
              style: AppTypography.titleLarge.copyWith(
                color: colors.textPrimary,
              ),
            ),
            Text(
              l10n.isPersian
                  ? today.formatFull()
                  : AppDateFormatter.format(DateTime.now(), locale: 'en'),
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
            tooltip: l10n.search,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.push('/notifications'),
            tooltip: l10n.isPersian ? 'اعلان‌ها' : 'Notifications',
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: AppResponsiveContainer(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            _HeroCard(
              hidden: _hideBalances,
              onToggleHidden: () =>
                  setState(() => _hideBalances = !_hideBalances),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _QuickActions(),
            const SizedBox(height: AppSpacing.lg),
            const UpcomingSection(),
            const _InsightCard(),
            const _BudgetSection(),
            AppSectionHeader(
              title: l10n.accounts,
              actionLabel: l10n.all,
              onAction: () => context.push('/accounts'),
            ),
            const _AccountsStrip(),
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(
              title: l10n.recentTransactions,
              actionLabel: l10n.all,
              onAction: () => context.go('/activity'),
            ),
            const _RecentTransactions(),
            const SizedBox(height: AppSpacing.lg),
            const _ToolsCard(),
          ],
        ),
      ),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final bool hidden;
  final VoidCallback onToggleHidden;

  const _HeroCard({required this.hidden, required this.onToggleHidden});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accounts = context.watch<AccountsBloc>().state;
    final txState = context.watch<TransactionBloc>().state;

    if (accounts is AccountsLoading || txState is TransactionLoading) {
      return const AppSkeleton(height: 196);
    }

    final base = AppCurrency.base;
    final total = accounts is AccountsLoaded ? accounts.totalBalance : null;

    // This Jalali month — the period people actually budget in.
    final monthStart = startOfJalaliMonth(DateTime.now());
    var income = 0;
    var expense = 0;
    if (txState is TransactionLoaded) {
      for (final tx in txState.transactions) {
        if (tx.date.isBefore(monthStart) || !tx.amount.isCompatibleWith(base)) {
          continue;
        }
        final minor = tx.amount.normalizeTo(base).minorUnits;
        if (tx.type == TransactionType.income) income += minor;
        if (tx.type == TransactionType.expense) expense += minor;
      }
    }
    final spentRatio = income <= 0
        ? (expense > 0 ? 1.0 : 0.0)
        : (expense / income).clamp(0.0, 1.0);
    final monthName = JalaliDate.fromDateTime(DateTime.now()).monthName;

    String masked(String s) => hidden ? '••••••' : s;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: isDark ? KifinoPalette.heroDark : KifinoPalette.heroLight,
          borderRadius: BorderRadius.circular(KifinoRadii.xl),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(KifinoRadii.xl),
          onTap: () => context.go('/analytics'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.netWorth,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.onInkSecondary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onToggleHidden,
                      visualDensity: VisualDensity.compact,
                      tooltip: hidden
                          ? (l10n.isPersian ? 'نمایش مبالغ' : 'Show amounts')
                          : (l10n.isPersian ? 'پنهان کردن مبالغ' : 'Hide'),
                      icon: Icon(
                        hidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: AppColors.onInkSecondary,
                      ),
                    ),
                  ],
                ),
                if (hidden)
                  Text(
                    '••••••••',
                    style: AppTypography.moneyHeadline.copyWith(
                      color: AppColors.onInk,
                    ),
                  )
                else if (total != null)
                  AppMoneyText(
                    money: total,
                    style: AppTypography.moneyHeadline.copyWith(
                      color: AppColors.onInk,
                    ),
                    usePersianDigits: true,
                    animated: true,
                  )
                else
                  const AppSkeleton(width: 160, height: 34),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.isPersian ? 'جریان $monthName' : 'This month',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.onInkSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: AppSpacing.borderRadiusPill,
                  child: LinearProgressIndicator(
                    value: spentRatio,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    color: spentRatio >= 0.9
                        ? AppColors.expenseDark
                        : AppColors.primaryBlueDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _HeroFigure(
                        icon: Icons.south_west_rounded,
                        color: AppColors.incomeDark,
                        label: l10n.income,
                        value: masked(
                          Money.fromMinor(
                            income,
                            base,
                          ).format(usePersianDigits: true),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _HeroFigure(
                        icon: Icons.north_east_rounded,
                        color: AppColors.expenseDark,
                        label: l10n.expense,
                        value: masked(
                          Money.fromMinor(
                            expense,
                            base,
                          ).format(usePersianDigits: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroFigure extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _HeroFigure({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.onInkSecondary,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.moneySub.copyWith(
                  color: AppColors.onInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Quick actions ────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.customColors;
    final actions = [
      (
        Icons.north_east_rounded,
        l10n.expense,
        colors.expense,
        () => context.push('/transaction/new', extra: 'expense'),
      ),
      (
        Icons.south_west_rounded,
        l10n.income,
        colors.income,
        () => context.push('/transaction/new', extra: 'income'),
      ),
      (
        Icons.swap_horiz_rounded,
        l10n.isPersian ? 'انتقال' : 'Transfer',
        colors.transfer,
        () => context.push('/transaction/new', extra: 'transfer'),
      ),
      (
        Icons.event_repeat_rounded,
        l10n.isPersian ? 'تکراری' : 'Recurring',
        Theme.of(context).colorScheme.primary,
        () => context.push('/recurring'),
      ),
      (
        Icons.auto_awesome_outlined,
        l10n.isPersian ? 'دستیار' : 'Assistant',
        Theme.of(context).colorScheme.tertiary,
        () => context.push('/ai'),
      ),
    ];

    return Row(
      children: [
        for (final (icon, label, color, onTap) in actions)
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: AppSpacing.borderRadiusMd,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    AppIconBadge(
                      icon: icon,
                      color: color,
                      size: 50,
                      iconSize: 23,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Insight ──────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.customColors;
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final txState = context.watch<TransactionBloc>().state;
    if (txState is! TransactionLoaded || txState.transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    final catTotals = <String, int>{};
    for (final tx in txState.transactions) {
      // Uncategorized spending says nothing useful ("«سایر» is 100%"), so
      // the insight only speaks about real categories.
      if (tx.type == TransactionType.expense &&
          tx.categoryName != null &&
          now.difference(tx.date).inDays <= 30 &&
          tx.amount.isCompatibleWith(AppCurrency.base)) {
        final cat = tx.categoryName!;
        catTotals[cat] =
            (catTotals[cat] ?? 0) +
            tx.amount.normalizeTo(AppCurrency.base).minorUnits;
      }
    }
    if (catTotals.isEmpty) return const SizedBox.shrink();
    final top = catTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final total = catTotals.values.fold<int>(0, (a, b) => a + b);
    final share = (top.value * 100 / total).round();
    // A single category is trivially 100% — not an insight.
    if (catTotals.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        onTap: () => context.go('/analytics'),
        backgroundColor: isDark
            ? AppColors.primaryTintDark
            : AppColors.primaryTintLight,
        borderColor: primary.withValues(alpha: 0.18),
        child: Row(
          children: [
            Icon(Icons.insights_rounded, color: primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.isPersian
                    ? TextNormalizer.auto(
                        '«${top.key}» با $share٪ بیشترین سهم هزینه‌های ۳۰ روز اخیر را دارد.',
                      )
                    : '"${top.key}" is $share% of your spending in the last 30 days.',
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: primary),
          ],
        ),
      ),
    );
  }
}

// ─── Budgets ──────────────────────────────────────────────────────────────

class _BudgetSection extends StatelessWidget {
  const _BudgetSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<BudgetBloc>().state;
    if (state is! BudgetLoaded || state.budgets.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: l10n.budgets,
          actionLabel: l10n.all,
          onAction: () => context.go('/analytics'),
        ),
        AppBudgetProgress(
          budget: state.budgets.first,
          onTap: () => context.go('/analytics'),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

// ─── Accounts ─────────────────────────────────────────────────────────────

class _AccountsStrip extends StatelessWidget {
  const _AccountsStrip();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<AccountsBloc>().state;
    if (state is! AccountsLoaded) return const AppSkeleton(height: 120);
    if (state.accounts.isEmpty) {
      return AppCard(
        onTap: () => context.push('/accounts'),
        child: Row(
          children: [
            AppIconBadge(
              icon: Icons.add_card_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(l10n.isPersian ? 'ساخت اولین حساب' : 'Create an account'),
          ],
        ),
      );
    }
    final accounts = state.accounts.where((a) => !a.isArchived).toList();
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => SizedBox(
          width: accounts.length == 1
              ? MediaQuery.sizeOf(context).width - AppSpacing.md * 2
              : 220,
          child: AppAccountCard(account: accounts[i]),
        ),
      ),
    );
  }
}

// ─── Recent transactions ──────────────────────────────────────────────────

class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = context.watch<TransactionBloc>().state;
    if (state is! TransactionLoaded) return const AppSkeleton(height: 160);
    if (state.transactions.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: l10n.noTransactionsYet,
          description: l10n.noTransactionsDesc,
          actionLabel: l10n.addTransaction,
          onAction: () => context.push('/transaction/new'),
        ),
      );
    }
    final recent = state.transactions.take(5).toList();
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (final (i, tx) in recent.indexed) ...[
            if (i > 0) const Divider(indent: 70),
            AppTransactionTile(
              transaction: tx,
              onTap: () => context.push('/transaction/new', extra: tx),
              onDelete: tx.isOwnedByModule
                  ? null
                  : () => context.read<TransactionBloc>().add(
                      TransactionDeleteSubmitted(tx.id),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Business & accounting tools ──────────────────────────────────────────

class _ToolsCard extends StatelessWidget {
  const _ToolsCard();

  @override
  Widget build(BuildContext context) {
    final isPersian = context.l10n.isPersian;
    final colors = context.customColors;
    final tools = [
      (
        Icons.receipt_long_outlined,
        isPersian ? 'فاکتور' : 'Invoice',
        '/business',
        colors.business,
      ),
      (
        Icons.fact_check_outlined,
        isPersian ? 'چک‌ها' : 'Checks',
        '/checks',
        colors.warning,
      ),
      (
        Icons.calendar_month_outlined,
        isPersian ? 'اقساط' : 'Loans',
        '/installments',
        colors.asset,
      ),
      (
        Icons.flag_outlined,
        isPersian ? 'اهداف' : 'Goals',
        '/goals',
        colors.income,
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPersian ? 'ابزارها' : 'Tools',
            style: AppTypography.titleSmall.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final (icon, label, route, color) in tools)
                Expanded(
                  child: InkWell(
                    onTap: () => context.push(route),
                    borderRadius: AppSpacing.borderRadiusMd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          AppIconBadge(icon: icon, color: color, size: 40),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: AppTypography.labelMedium.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          InkWell(
            onTap: () => context.push('/accounting'),
            borderRadius: AppSpacing.borderRadiusMd,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 20,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPersian
                          ? 'حسابداری دوبل — اسناد، دفاتر و ترازنامه'
                          : 'Double-entry accounting',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
