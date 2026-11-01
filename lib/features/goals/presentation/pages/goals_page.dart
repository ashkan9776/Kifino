import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_amount_field.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_skeleton.dart';

import '../../../../core/widgets/app_date_picker.dart';import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../../domain/entities/goal_entity.dart';
import '../bloc/goal_bloc.dart';
import '../widgets/edit_goal_sheet.dart';

class GoalsPage extends StatelessWidget {
  const GoalsPage({super.key});

  void _showAddGoalSheet(BuildContext context) {
    final l10n = context.l10n;
    final currency = context.read<SettingsCubit>().state.currency;
    final nameController = TextEditingController();
    int targetAmountMinor = 0;
    DateTime? targetDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AppBottomSheet(
              child: Container(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSheetHeader(
                        title: l10n.isPersian ? 'هدف مالی جدید' : 'New Financial Goal',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: l10n.isPersian ? 'نام هدف (مثلاً سفر شمال)' : 'Goal Name (e.g. Trip)',
                          prefixIcon: const Icon(Icons.flag_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppAmountField(
                        currency: currency,
                        autoFocus: false,
                        onAmountMinorChanged: (value) => setModalState(() => targetAmountMinor = value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.isPersian ? 'تاریخ هدف (اختیاری)' : 'Target date (optional)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showAppDatePicker(
                                context: context,
                                initialDate: now,
                                firstDate: now,
                                lastDate: now.add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setModalState(() => targetDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_month_rounded, size: 18),
                            label: Text(
                              targetDate != null
                                  ? AppDateFormatter.formatShort(targetDate!, locale: l10n.localeName)
                                  : (l10n.isPersian ? 'انتخاب تاریخ' : 'Select date'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: l10n.save,
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isNotEmpty && targetAmountMinor > 0) {
                            final now = DateTime.now();
                            context.read<GoalBloc>().add(
                                  GoalCreateSubmitted(
                                    GoalEntity(
                                      id: '',
                                      name: name,
                                      targetAmount: Money.fromMinor(targetAmountMinor, currency),
                                      currentAmount: Money.zero(currency),
                                      targetDate: targetDate,
                                      createdAt: now,
                                      updatedAt: now,
                                    ),
                                  ),
                                );
                            Navigator.pop(bottomSheetContext);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showContributeSheet(BuildContext context, GoalEntity goal) {
    final l10n = context.l10n;
    int amountMinor = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AppBottomSheet(
              child: Container(
                padding: const EdgeInsets.only(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  top: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSheetHeader(
                      title:
                          '${l10n.isPersian ? 'ثبت پس‌انداز برای' : 'Add savings to'}: ${goal.name}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${l10n.isPersian ? 'مانده' : 'Remaining'}: ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                          ),
                        ),
                        AppMoneyText(
                          money: goal.remainingAmount.abs(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppAmountField(
                      currency: goal.targetAmount.currency,
                      onAmountMinorChanged: (value) => setModalState(() => amountMinor = value),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: l10n.isPersian ? 'ثبت پس‌انداز' : 'Add savings',
                      onPressed: amountMinor > 0
                          ? () {
                              context.read<GoalBloc>().add(
                                    GoalContributeSubmitted(
                                      goal.id,
                                      Money.fromMinor(amountMinor, goal.targetAmount.currency),
                                    ),
                                  );
                              Navigator.pop(bottomSheetContext);
                            }
                          : null,
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

  Future<void> _confirmDelete(BuildContext context, GoalEntity goal) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.isPersian ? 'حذف هدف' : 'Delete goal'),
        content: Text(
          l10n.isPersian
              ? 'آیا از حذف هدف «${goal.name}» مطمئن هستید؟'
              : 'Are you sure you want to delete "${goal.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<GoalBloc>().add(GoalDeleteSubmitted(goal.id));
    }
  }

  Color _statusColor(GoalStatus status) {
    switch (status) {
      case GoalStatus.achieved:
        return AppColors.income;
      case GoalStatus.active:
        return AppColors.primary;
      case GoalStatus.cancelled:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider<GoalBloc>(
      create: (_) => GoalBloc(sl())..add(const WatchGoalsStarted()),
      child: BlocListener<GoalBloc, GoalState>(
        listener: (context, state) {
          if (state is GoalOperationSuccess) {
            final successMessage = switch (state.op) {
              'create' => l10n.isPersian ? 'هدف ایجاد شد' : 'Goal created',
              'achieve' => l10n.isPersian ? 'هدف دستیافت!' : 'Goal achieved!',
              'delete' => l10n.isPersian ? 'هدف حذف شد' : 'Goal deleted',
              _ => l10n.isPersian ? 'پس‌انداز ثبت شد' : 'Savings recorded',
            };
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(successMessage)),
            );
          } else if (state is GoalFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.isPersian ? 'خطا: ${state.message}' : 'Error: ${state.message}'),
              ),
            );
          }
        },
        child: ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.isPersian ? 'اهداف مالی' : 'Financial goals'),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddGoalSheet(context),
            child: const Icon(Icons.add),
          ),
          body: BlocBuilder<GoalBloc, GoalState>(
            builder: (context, state) {
              if (state is GoalLoading) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      AppSkeleton(height: 120, borderRadius: AppSpacing.borderRadiusLg),
                      SizedBox(height: AppSpacing.md),
                      AppSkeleton(height: 100, borderRadius: AppSpacing.borderRadiusLg),
                      SizedBox(height: AppSpacing.md),
                      AppSkeleton(height: 100, borderRadius: AppSpacing.borderRadiusLg),
                    ],
                  ),
                );
              }

              if (state is GoalLoaded) {
                final goals = state.goals;

                if (goals.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.flag_rounded,
                    title: l10n.isPersian ? 'هدف مالی نداری' : 'No financial goals yet',
                    description: l10n.isPersian
                        ? 'اولین هدف پس‌اندازت را بساز و قدم به قدم به آن برس.'
                        : 'Create your first savings goal and track your progress toward it.',
                    actionLabel: l10n.isPersian ? 'ایجاد هدف' : 'Create goal',
                    onAction: () => _showAddGoalSheet(context),
                  );
                }

                final theme = Theme.of(context);
                final isDark = theme.brightness == Brightness.dark;

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // Summary Card
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.isPersian ? 'کل پس‌انداز' : 'Total saved',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  TextNormalizer.auto('${state.overallPercent.toStringAsFixed(0)}%'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          AppMoneyText(
                            money: state.totalSaved,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            child: LinearProgressIndicator(
                              value: (state.overallPercent / 100.0).clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.isPersian ? 'هدف کل' : 'Total target',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                ),
                              ),
                              AppMoneyText(
                                money: state.totalTarget,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Goal Cards
                    ...goals.map((goal) {
                      final statusColor = _statusColor(goal.status);
                      final statusLabel = switch (goal.status) {
                        GoalStatus.achieved => l10n.isPersian ? 'دستیافت' : 'Achieved',
                        GoalStatus.active => l10n.isPersian ? 'فعال' : 'Active',
                        GoalStatus.cancelled => l10n.isPersian ? 'لغو شده' : 'Cancelled',
                      };

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      goal.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                child: LinearProgressIndicator(
                                  value: (goal.progressPercent / 100.0).clamp(0.0, 1.0),
                                  minHeight: 8,
                                  backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${l10n.isPersian ? 'مانده' : 'Remaining'}: ',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                          ),
                                        ),
                                        Flexible(
                                          child: AppMoneyText(
                                            money: goal.remainingAmount.abs(),
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (goal.targetDate != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          size: 14,
                                          color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          AppDateFormatter.formatShort(goal.targetDate!, locale: l10n.localeName),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppButton(
                                      label: l10n.isPersian ? 'ثبت پس‌انداز' : 'Add savings',
                                      onPressed: goal.status == GoalStatus.active
                                          ? () => _showContributeSheet(context, goal)
                                          : null,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => EditGoalSheet.show(context, goal),
                                    icon: const Icon(Icons.edit_outlined),
                                    tooltip: l10n.isPersian ? 'ویرایش' : 'Edit',
                                  ),
                                  IconButton(
                                    onPressed: () => _confirmDelete(context, goal),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    color: AppColors.danger,
                                    tooltip: l10n.delete,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                );
              }

              // GoalInitial / GoalFailure
              return AppEmptyState(
                icon: Icons.flag_rounded,
                title: l10n.isPersian ? 'هدف مالی نداری' : 'No financial goals yet',
                description: l10n.isPersian
                    ? 'اولین هدف پس‌اندازت را بساز و قدم به قدم به آن برس.'
                    : 'Create your first savings goal and track your progress toward it.',
              );
            },
          ),
        ),
      ),
        ),
      ),
    );
  }
}
