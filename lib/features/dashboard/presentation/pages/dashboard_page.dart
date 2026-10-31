import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_currency.dart';
import '../../../../core/design_system/tokens/colors.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_account_card.dart';
import '../../../../core/widgets/app_budget_progress.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_transaction_tile.dart';import '../../../accounts/presentation/bloc/accounts_bloc.dart';
import '../../../budgets/presentation/bloc/budget_bloc.dart';
import '../../../sync/presentation/bloc/sync_bloc.dart';
import '../../../sync/presentation/bloc/sync_state.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _hideBalances = false;

  static String _greeting(bool isPersian) {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return isPersian ? 'صبح بخیر 👋' : 'Good morning 👋';
    } else if (hour >= 12 && hour < 17) {
      return isPersian ? 'ظهر بخیر 👋' : 'Good afternoon 👋';
    } else if (hour >= 17 && hour < 21) {
      return isPersian ? 'عصر بخیر 👋' : 'Good evening 👋';
    }
    return isPersian ? 'شب بخیر 👋' : 'Good night 👋';
  }

  static String _trendText(double percent, bool isPersian) {
    if (percent.abs() < 0.5) {
      return isPersian ? 'بدون تغییر' : 'unchanged';
    }
    final rounded = percent.abs().round();
    final digits = TextNormalizer.toPersianDigits('$rounded');
    return isPersian
        ? '$digits٪ ${percent > 0 ? 'بیشتر' : 'کمتر'}'
        : '$rounded% ${percent > 0 ? 'higher' : 'lower'}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_greeting(l10n.isPersian)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
            tooltip: l10n.search,
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
            tooltip: l10n.isPersian ? 'اعلان‌ها' : 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => context.push('/ai'),
            tooltip: l10n.aiAssistant,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          // Net Worth & Monthly Balance Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: BlocBuilder<AccountsBloc, AccountsState>(
              builder: (context, accountsState) {
                return BlocBuilder<TransactionBloc, TransactionState>(
                  builder: (context, txState) {
                    if (accountsState is AccountsLoading || txState is TransactionLoading) {
                      return const AppSkeleton(height: 180);
                    }

                    final totalBalance = accountsState is AccountsLoaded
                        ? accountsState.totalBalance
                        : null;
                    final totalIncome = txState is TransactionLoaded
                        ? txState.totalIncome
                        : null;
                    final totalExpense = txState is TransactionLoaded
                        ? txState.totalExpense
                        : null;

                    // Month-over-month expense trend — real data, only shown
                    // when the previous window actually has expenses.
                    ({double? percent, bool higher})? trend;
                    if (txState is TransactionLoaded) {
                      final now = DateTime.now();
                      int last30 = 0;
                      int prev30 = 0;
                      for (final tx in txState.transactions) {
                        if (tx.type != TransactionType.expense ||
                            !tx.amount.isCompatibleWith(AppCurrency.base)) {
                          continue;
                        }
                        final minor = tx.amount.normalizeTo(AppCurrency.base).minorUnits;
                        final days = now.difference(tx.date).inDays;
                        if (days <= 30) {
                          last30 += minor;
                        } else if (days <= 60) {
                          prev30 += minor;
                        }
                      }
                      if (prev30 > 0) {
                        trend = (
                          percent: ((last30 - prev30) / prev30) * 100,
                          higher: last30 > prev30,
                        );
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: isDark
                            ? KifinoPalette.heroDark
                            : KifinoPalette.heroLight,
                        borderRadius: AppSpacing.borderRadiusLg,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryBlueLight.withValues(alpha: isDark ? 0.4 : 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    l10n.netWorth,
                                    style: AppTypography.labelLarge.copyWith(
                                      color: Colors.white.withValues(alpha: 0.75),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(
                                      _hideBalances
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      size: 18,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                    onPressed: () {
                                      setState(() => _hideBalances = !_hideBalances);
                                    },
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: l10n.isPersian
                                        ? (_hideBalances ? 'نمایش مبالغ' : 'مخفی‌سازی مبالغ')
                                        : (_hideBalances ? 'Show balances' : 'Hide balances'),
                                  ),
                                ],
                              ),
                              BlocBuilder<SyncBloc, SyncState>(
                                builder: (context, syncState) {
                                  final (String label, Color fg) = syncState.isSyncing
                                      ? (
                                          l10n.isPersian ? 'در حال همگام‌سازی…' : 'Syncing…',
                                          Colors.white,
                                        )
                                      : !syncState.isOnline
                                          ? (
                                              l10n.isPersian ? 'آفلاین — همگام‌سازی خودکار' : 'Offline — auto sync',
                                              const Color(0xFFFFD180),
                                            )
                                          : (
                                              l10n.isPersian ? 'همگام‌سازی فعال' : 'Sync active',
                                              const Color(0xFFB9F6CA),
                                            );
                                  return GestureDetector(
                                    onTap: () => context.push('/sync'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.14),
                                        borderRadius: AppSpacing.borderRadiusPill,
                                      ),
                                      child: Text(
                                        label,
                                        style: AppTypography.labelMedium.copyWith(color: fg),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (_hideBalances)
                            Text(
                              '••••••••',
                              style: AppTypography.displayLarge.copyWith(
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            )
                          else if (totalBalance != null)
                            AppMoneyText(
                              money: totalBalance,
                              style: AppTypography.displayLarge.copyWith(color: Colors.white),
                              usePersianDigits: true,
                              animated: true,
                            )
                          else
                            const AppSkeleton(width: 140, height: 36),
                          const SizedBox(height: AppSpacing.md),
                          const Divider(color: Colors.white24),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.income,
                                      style: AppTypography.labelMedium.copyWith(
                                        color: const Color(0xFFB9F6CA),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (_hideBalances)
                                      Text(
                                        '••••••',
                                        style: AppTypography.moneyTile.copyWith(
                                          color: Colors.white,
                                          letterSpacing: 2,
                                        ),
                                      )
                                    else if (totalIncome != null)
                                      AppMoneyText(
                                        money: totalIncome,
                                        sign: MoneyDisplaySign.positiveNegative,
                                        style: AppTypography.moneyTile.copyWith(
                                          color: Colors.white,
                                        ),
                                        colorCode: false,
                                        usePersianDigits: true,
                                      )
                                    else
                                      const AppSkeleton(width: 80, height: 20),
                                  ],
                                ),
                              ),
                              Container(height: 28, width: 1, color: Colors.white24),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.expense,
                                      style: AppTypography.labelMedium.copyWith(
                                        color: const Color(0xFFFFB4AB),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (_hideBalances)
                                      Text(
                                        '••••••',
                                        style: AppTypography.moneyTile.copyWith(
                                          color: Colors.white,
                                          letterSpacing: 2,
                                        ),
                                      )
                                    else if (totalExpense != null)
                                      AppMoneyText(
                                        money: totalExpense,
                                        sign: MoneyDisplaySign.negativeOnly,
                                        style: AppTypography.moneyTile.copyWith(
                                          color: Colors.white,
                                        ),
                                        colorCode: false,
                                        usePersianDigits: true,
                                      )
                                    else
                                      const AppSkeleton(width: 80, height: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        if (trend != null && trend.percent != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Icon(
                              trend.higher
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 16,
                              color: trend.higher
                                  ? const Color(0xFFFFD180)
                                  : const Color(0xFFB9F6CA),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                l10n.isPersian
                                    ? 'هزینه نسبت به ۳۰ روز قبل: ${_trendText(trend.percent!, l10n.isPersian)}'
                                    : 'Spending vs previous 30 days: ${_trendText(trend.percent!, l10n.isPersian)}',
                                style: AppTypography.labelMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      ],
                    ),
                  );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Quick Operations
          _buildQuickOperations(context, isDark, l10n.isPersian),
          const SizedBox(height: AppSpacing.md),

          // Accounting OS Banner / Quick Access
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppCard(
              onTap: () => context.push('/accounting'),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.account_balance, color: Colors.indigo, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isPersian ? 'سیستم حسابداری مالی (دوبل)' : 'Financial Accounting OS',
                            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.isPersian
                                ? 'اسناد دوبل، کدینگ سرفصل‌ها، دفاتر قانونی و تراز آزمایشی'
                                : 'General ledger, journal vouchers & trial balance',
                            style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_left_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Accounts Carousel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.accounts, style: AppTypography.titleMedium),
                TextButton(
                  onPressed: () => context.push('/accounts'),
                  child: Text(l10n.all),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SizedBox(
            height: 125,
            child: BlocBuilder<AccountsBloc, AccountsState>(
              builder: (context, state) {
                if (state is AccountsLoaded) {
                  if (state.accounts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: AppCard(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.isPersian
                                    ? 'هنوز حسابی نساخته‌ای'
                                    : 'No accounts yet',
                                style: AppTypography.bodyMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              AppButton(
                                label: l10n.isPersian ? 'ساخت حساب' : 'Create account',
                                variant: AppButtonVariant.primary,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                onPressed: () => context.push('/accounts'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    scrollDirection: Axis.horizontal,
                    itemCount: state.accounts.length,
                    separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, index) {
                      return AppAccountCard(account: state.accounts[index]);
                    },
                  );
                }
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: AppSkeleton(height: 110),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // AI Insight Card (data-driven, no fabricated values)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, txState) {
                final hasTransactions =
                    txState is TransactionLoaded && txState.transactions.isNotEmpty;

                String insight;
                String ctaLabel;
                if (!hasTransactions) {
                  insight = l10n.isPersian
                      ? 'اولین تراکنشت رو ثبت کن تا بینش‌های هوشمند اینجا ظاهر بشه.'
                      : 'Add your first transaction and smart insights will appear here.';
                  ctaLabel = l10n.isPersian ? 'ثبت تراکنش' : 'Add transaction';
                } else {
                  final txs = txState.transactions;
                  final now = DateTime.now();
                  final catTotals = <String, int>{};
                  for (final tx in txs) {
                    if (tx.type == TransactionType.expense &&
                        now.difference(tx.date).inDays <= 30) {
                      final cat = tx.categoryName ?? (l10n.isPersian ? 'سایر' : 'Other');
                      catTotals[cat] = (catTotals[cat] ?? 0) + tx.amount.minorUnits;
                    }
                  }
                  if (catTotals.isEmpty) {
                    insight = l10n.isPersian
                        ? 'در ۳۰ روز اخیر هزینه‌ای ثبت نشده است.'
                        : 'No expenses recorded in the last 30 days.';
                  } else {
                    final topEntry =
                        catTotals.entries.reduce((a, b) => a.value >= b.value ? a : b);
                    insight = l10n.isPersian
                        ? 'بیشترین هزینه ۳۰ روز اخیر شما در دسته «${topEntry.key}» بوده است.'
                        : 'Your biggest spending category in the last 30 days is "${topEntry.key}".';
                  }
                  ctaLabel = l10n.isPersian ? 'مشاهده تحلیل کامل' : 'View full analysis';
                }

                return InkWell(
                  onTap: () => hasTransactions
                      ? context.push('/ai')
                      : context.push('/transaction/new'),
                  borderRadius: AppSpacing.borderRadiusLg,
                  child: AppCard(
                    backgroundColor: isDark
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                    borderColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                insight,
                                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                ctaLabel,
                                style: AppTypography.labelMedium.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                  },
            ),
          ),
          // Budgets Section (if active budgets exist)
          BlocBuilder<BudgetBloc, BudgetState>(
            builder: (context, budgetState) {
              if (budgetState is BudgetLoaded && budgetState.budgets.isNotEmpty) {
                final topBudget = budgetState.budgets.first;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.budgets, style: AppTypography.titleMedium),
                          TextButton(
                            onPressed: () => context.go('/analytics'),
                            child: Text(l10n.all),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppBudgetProgress(
                        budget: topBudget,
                        onTap: () => context.go('/analytics'),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          // Recent Activity Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.recentTransactions, style: AppTypography.titleMedium),
                TextButton(
                  onPressed: () => context.go('/activity'),
                  child: Text(l10n.all),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Recent Transactions List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                if (state is TransactionLoaded) {
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

                  return AppCard(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.transactions.length.clamp(0, 5),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final tx = state.transactions[index];
                        return AppTransactionTile(
                          transaction: tx,
                          onTap: () => context.push('/transaction/new', extra: tx),
                          onDelete: () {
                            context.read<TransactionBloc>().add(TransactionDeleteSubmitted(tx.id));
                          },
                        );
                      },
                    ),
                  );
                }

                return const AppSkeleton(height: 140);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickOperations(BuildContext context, bool isDark, bool isPersian) {
    final actions = [
      (
        Icons.receipt_long_rounded,
        isPersian ? 'سند دوبل' : 'Voucher',
        Colors.indigo,
        () => context.push('/accounting/documents/create'),
      ),
      (
        Icons.point_of_sale_rounded,
        isPersian ? 'فاکتور' : 'Invoice',
        Colors.teal,
        () => context.push('/business'),
      ),
      (
        Icons.fact_check_rounded,
        isPersian ? 'چک صیادی' : 'Check',
        Colors.amber.shade800,
        () => context.push('/checks'),
      ),
      (
        Icons.credit_card_rounded,
        isPersian ? 'وام و اقساط' : 'Installment',
        Colors.deepPurple,
        () => context.push('/installments'),
      ),
      (
        Icons.balance_rounded,
        isPersian ? 'تراز مالی' : 'Trial Balance',
        Colors.blueGrey,
        () => context.push('/accounting/trial-balance'),
      ),
      (
        Icons.flag_circle_rounded,
        isPersian ? 'هدف مالی' : 'Goal',
        Colors.blue,
        () => context.push('/goals'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPersian ? 'عملیات سریع' : 'Quick Operations',
                style: AppTypography.titleMedium,
              ),
              Text(
                isPersian ? 'سیستم یکپارچه' : 'Financial OS',
                style: AppTypography.labelSmall.copyWith(
                  color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: actions.map((item) {
              final (icon, title, color, onTap) = item;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              title,
                              style: AppTypography.labelSmall.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 9.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
