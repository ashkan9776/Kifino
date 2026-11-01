import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_amount_field.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_budget_progress.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../accounts/presentation/bloc/accounts_bloc.dart';
import '../../../budgets/presentation/bloc/budget_bloc.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../transactions/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/repositories/category_repository.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';
import '../../../budgets/domain/entities/budget_entity.dart';
import '../../domain/services/financial_calculators.dart';
import '../widgets/cash_flow_chart.dart';
import '../widgets/category_spending_chart.dart';
import '../widgets/financial_health_card.dart';

enum AnalyticsPeriod {
  thisMonth,
  last3Months,
  all,
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.thisMonth;
  List<CategoryEntity> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final result = await sl<CategoryRepository>().getCategories();
    result.fold(
      onSuccess: (cats) {
        if (mounted) setState(() => _categories = cats);
      },
      onFailure: (_) {},
    );
  }

  List<TransactionEntity> _filterByPeriod(List<TransactionEntity> transactions) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case AnalyticsPeriod.thisMonth:
        return transactions.where((tx) => now.difference(tx.date).inDays <= 30).toList();
      case AnalyticsPeriod.last3Months:
        return transactions.where((tx) => now.difference(tx.date).inDays <= 90).toList();
      case AnalyticsPeriod.all:
        return transactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.navAnalytics),
        elevation: 0,
      ),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, txState) {
          if (txState is TransactionLoading) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppSkeleton(height: 140, borderRadius: AppSpacing.borderRadiusLg),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(height: 200, borderRadius: AppSpacing.borderRadiusLg),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(height: 180, borderRadius: AppSpacing.borderRadiusLg),
                ],
              ),
            );
          }

          if (txState is! TransactionLoaded) {
            return AppEmptyState(
              icon: Icons.analytics_outlined,
              title: l10n.cashFlow,
              description: l10n.noTransactionsDesc,
            );
          }

          final filteredTxs = _filterByPeriod(txState.transactions);
          const defaultCurrency = Currency.irr;

          // Cash Flow calculations
          final days = _selectedPeriod == AnalyticsPeriod.thisMonth
              ? 30
              : (_selectedPeriod == AnalyticsPeriod.last3Months ? 90 : 180);
          final cashFlow = CashFlowCalculator.calculate(
            transactions: filteredTxs,
            currency: defaultCurrency,
            daysCount: days,
          );

          // Accounts Balance for Runway
          return BlocBuilder<AccountsBloc, AccountsState>(
            builder: (context, accState) {
              int totalLiquidBalance = 0;
              if (accState is AccountsLoaded) {
                totalLiquidBalance = accState.totalBalance.minorUnits;
              }
              final liquidMoney = Money.fromMinor(totalLiquidBalance, defaultCurrency);
              final runwayMonths = RunwayCalculator.calculate(
                liquidBalance: liquidMoney,
                averageMonthlyExpense: cashFlow.dailyAverageExpense * 30,
              );

              final savingsRate = SavingsRateCalculator.calculate(
                totalIncome: cashFlow.totalIncome,
                totalExpense: cashFlow.totalExpense,
              );

              return BlocBuilder<BudgetBloc, BudgetState>(
                builder: (context, budgetState) {
                  double adherencePercent = 100.0;
                  final activeBudgets = budgetState is BudgetLoaded ? budgetState.budgets : [];
                  if (budgetState is BudgetLoaded) {
                    adherencePercent = budgetState.health.overallAdherencePercent;
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    children: [
                      // Period Selector
                      Center(
                        child: SegmentedButton<AnalyticsPeriod>(
                          segments: [
                            ButtonSegment(
                              value: AnalyticsPeriod.thisMonth,
                              label: Text(l10n.periodThisMonth),
                            ),
                            ButtonSegment(
                              value: AnalyticsPeriod.last3Months,
                              label: Text(l10n.periodLast3Months),
                            ),
                            ButtonSegment(
                              value: AnalyticsPeriod.all,
                              label: Text(l10n.all),
                            ),
                          ],
                          selected: {_selectedPeriod},
                          onSelectionChanged: (newSelection) {
                            setState(() => _selectedPeriod = newSelection.first);
                          },
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Financial Health Scorecard
                      FinancialHealthCard(
                        runwayMonths: runwayMonths,
                        savingsRatePercent: savingsRate.percentage,
                        budgetAdherencePercent: adherencePercent,
                        dailyAverageExpense: cashFlow.dailyAverageExpense,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Cash Flow Chart
                      CashFlowChart(
                        transactions: filteredTxs,
                        currency: defaultCurrency,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Category Donut Chart
                      CategorySpendingChart(
                        transactions: filteredTxs,
                        categories: _categories,
                        currency: defaultCurrency,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Budgets Breakdown
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.activeBudgets,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          AppButton(
                            label: l10n.isPersian ? 'بودجه جدید' : 'New budget',
                            variant: AppButtonVariant.outline,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            onPressed: () => _showCreateBudgetSheet(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (activeBudgets.isEmpty)
                        AppCard(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: AppEmptyState(
                            icon: Icons.savings_outlined,
                            title: l10n.isPersian ? 'بودجه فعالی نداری' : 'No active budgets',
                            description: l10n.isPersian
                                ? 'برای دسته‌های پرخرج سقف بودجه بگذار تا هزینه‌هات کنترل بشه.'
                                : 'Set spending caps for high-spend categories to stay on track.',
                            actionLabel: l10n.isPersian ? 'ساخت بودجه' : 'Create budget',
                            onAction: () => _showCreateBudgetSheet(context),
                          ),
                        )
                      else
                        ...activeBudgets.map(
                          (b) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppBudgetProgress(budget: b),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
        ),
      ),
    );
  }

  Future<void> _showCreateBudgetSheet(BuildContext context) async {
    final l10n = context.l10n;
    final isPersian = l10n.isPersian;
    final currency = context.read<SettingsCubit>().state.currency;
    final nameController = TextEditingController();
    int? amountMinor;
    final selectedCategoryIds = <String>{};
    final expenseCategories =
        _categories.where((c) => c.type == CategoryType.expense).toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return AppBottomSheet(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSheetHeader(title: isPersian ? 'بودجه جدید' : 'New budget'),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: isPersian ? 'نام بودجه (مثلاً خوراک)' : 'Budget name (e.g. Food)',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppAmountField(
                      currency: currency,
                      autoFocus: false,
                      onAmountMinorChanged: (minor) => amountMinor = minor,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (expenseCategories.isNotEmpty) ...[
                      Text(
                        isPersian ? 'دسته‌ها (اختیاری)' : 'Categories (optional)',
                        style: Theme.of(sheetContext).textTheme.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final category in expenseCategories)
                            FilterChip(
                              label: Text(category.name),
                              selected: selectedCategoryIds.contains(category.id),
                              onSelected: (selected) {
                                setSheetState(() {
                                  selected
                                      ? selectedCategoryIds.add(category.id)
                                      : selectedCategoryIds.remove(category.id);
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    AppButton(
                      label: isPersian ? 'ایجاد بودجه' : 'Create budget',
                      onPressed: () {
                        final amount = amountMinor;
                        if (nameController.text.trim().isEmpty ||
                            amount == null ||
                            amount <= 0) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                isPersian
                                    ? 'نام و مبلغ بزرگ‌تر از صفر الزامی است'
                                    : 'Name and an amount greater than 0 are required',
                              ),
                            ),
                          );
                          return;
                        }
                        final now = DateTime.now();
                        final startOfMonth = startOfJalaliMonth(now);
                        final endOfMonth = endOfJalaliMonth(now);

                        context.read<BudgetBloc>().add(BudgetCreateSubmitted(BudgetEntity(
                              id: const Uuid().v4(),
                              name: nameController.text.trim(),
                              amountLimit: Money.fromMinor(amount, currency),
                              amountSpent: Money.zero(currency),
                              startDate: startOfMonth,
                              endDate: endOfMonth,
                              categoryIds: selectedCategoryIds.toList(),
                              createdAt: now,
                              updatedAt: now,
                            )));
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isPersian ? 'بودجه ساخته شد' : 'Budget created',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
