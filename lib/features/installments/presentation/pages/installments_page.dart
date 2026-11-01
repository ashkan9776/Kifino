import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/design_system/components/financial/app_status_badge.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../accounts/presentation/bloc/accounts_bloc.dart';
import '../../domain/entities/installment_entity.dart';
import '../bloc/installment_bloc.dart';
import '../widgets/edit_installment_sheet.dart';
import '../widgets/installment_history_sheet.dart';

class InstallmentsPage extends StatelessWidget {
  const InstallmentsPage({super.key});

  // ----------------------------------------------------
  // CREATE SHEET
  // ----------------------------------------------------
  void _showAddInstallmentDialog(BuildContext context) {
    final l10n = context.l10n;

    // Graceful empty state: installments deduct from an account, so without
    // one the create flow cannot complete (same guard as the business hub).
    final accState = context.read<AccountsBloc>().state;
    if (accState is AccountsLoaded && accState.accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.isPersian
                ? 'برای ثبت قسط ابتدا یک حساب بانکی یا نقدی بسازید.'
                : 'Create a bank or cash account first to track installments.',
          ),
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final countController = TextEditingController(
      text: l10n.isPersian ? '۱۲' : '12',
    );

    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return BlocBuilder<AccountsBloc, AccountsState>(
          builder: (context, accState) {
            String? selectedAccountId;
            if (accState is AccountsLoaded && accState.accounts.isNotEmpty) {
              selectedAccountId = accState.accounts.first.id;
            }

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
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.lightSurface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSheetHeader(
                            title: l10n.isPersian
                                ? 'ثبت وام یا اقساط جدید'
                                : 'New Loan / Installment',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              labelText: l10n.isPersian
                                  ? 'عنوان وام / کالا'
                                  : 'Title',
                              prefixIcon: const Icon(Icons.title_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianThousandsSeparatorTextInputFormatter(
                                enabled: isFaLocale(context),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.isPersian
                                  ? 'مبلغ هر قسط'
                                  : 'Installment Amount',
                              prefixIcon: const Icon(Icons.payments_outlined),
                              suffixText: l10n.isPersian ? 'تومان' : '',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: countController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianDigitsTextInputFormatter(
                                enabled: isFaLocale(context),
                              ),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.isPersian
                                  ? 'تعداد کل اقساط'
                                  : 'Total Installments Count',
                              prefixIcon: const Icon(
                                Icons.format_list_numbered_rounded,
                              ),
                              suffixText: l10n.isPersian ? 'قسط' : '',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // Next Due Date
                          InkWell(
                            onTap: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate,
                                firstDate: now.subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: now.add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setModalState(() => dueDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month_rounded,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.isPersian
                                            ? 'تاریخ اولین سررسید'
                                            : 'First due date',
                                      ),
                                    ],
                                  ),
                                  Text(
                                    AppDateFormatter.format(
                                      dueDate,
                                      locale: l10n.localeName,
                                    ),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.income,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (accState is AccountsLoaded &&
                              accState.accounts.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<String>(
                              initialValue: selectedAccountId,
                              decoration: InputDecoration(
                                labelText: l10n.isPersian
                                    ? 'حساب مبدا پرداخت اقساط'
                                    : 'Payment Account',
                                prefixIcon: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                              ),
                              items: accState.accounts.map((acc) {
                                return DropdownMenuItem(
                                  value: acc.id,
                                  child: Text(
                                    '${acc.name} (${acc.bankName ?? ""})',
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedAccountId = val);
                                }
                              },
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: l10n.save,
                            onPressed: () {
                              final title = titleController.text.trim();
                              final singleAmountVal =
                                  int.tryParse(
                                    normalizeNumericInput(
                                      amountController.text,
                                    ),
                                  ) ??
                                  0;
                              final totalCount =
                                  int.tryParse(
                                    normalizeNumericInput(countController.text),
                                  ) ??
                                  12;

                              // Never fail silently when no account is available.
                              if (selectedAccountId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.isPersian
                                          ? 'حساب مبدا پرداخت در دسترس نیست.'
                                          : 'No payment account available.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (title.isNotEmpty && singleAmountVal > 0) {
                                final now = DateTime.now();
                                final singleMoney = Money.fromMinor(
                                  singleAmountVal,
                                  Currency.irr,
                                );
                                final totalMoney = Money.fromMinor(
                                  singleAmountVal * totalCount,
                                  Currency.irr,
                                );

                                context.read<InstallmentBloc>().add(
                                  InstallmentCreateSubmitted(
                                    InstallmentEntity(
                                      id: '',
                                      title: title,
                                      accountId: selectedAccountId!,
                                      totalAmount: totalMoney,
                                      numberOfInstallments: totalCount,
                                      installmentAmount: singleMoney,
                                      startDate: now,
                                      nextDueDate: dueDate,
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
      },
    );
  }

  // ----------------------------------------------------
  // CONFIRMATION DIALOGS
  // ----------------------------------------------------
  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmLabel,
    bool danger = true,
  }) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: danger ? AppColors.danger : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _confirmPayRemaining(
    BuildContext context,
    InstallmentEntity inst,
  ) async {
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final remainingCount = inst.remainingInstallmentsCount;
    final confirmed = await _confirm(
      context,
      title: isFa ? 'تسویه زودهنگام' : 'Early payoff',
      content: isFa
          ? 'همه ${TextNormalizer.auto('$remainingCount')} قسط باقی‌مانده یکجا پرداخت می‌شود و از حساب شما کسر می‌گردد. در دفتر یک ردیف خلاصه ثبت می‌شود.'
          : 'All $remainingCount remaining installments are paid at once and deducted from your account. A single summary row is recorded in the ledger.',
      confirmLabel: isFa ? 'پرداخت کامل' : 'Pay in full',
      danger: false,
    );
    if (confirmed && context.mounted) {
      context.read<InstallmentBloc>().add(
        InstallmentPayRemainingSubmitted(inst.id),
      );
    }
  }

  Future<void> _confirmDeleteInstallment(
    BuildContext context,
    InstallmentEntity inst,
  ) async {
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final confirmed = await _confirm(
      context,
      title: isFa ? 'حذف قسط' : 'Delete installment',
      content: isFa
          ? 'آیا از حذف «${inst.title}» مطمئن هستید؟ پرداخت‌های ثبت‌شده باقی می‌مانند.'
          : 'Delete "${inst.title}"? Recorded payments are kept.',
      confirmLabel: l10n.delete,
    );
    if (confirmed && context.mounted) {
      context.read<InstallmentBloc>().add(InstallmentDeleteSubmitted(inst.id));
    }
  }

  // ----------------------------------------------------
  // COUNTDOWN CHIP
  // ----------------------------------------------------
  ({String label, Color color, IconData icon}) _countdown(
    InstallmentEntity inst,
    bool isFa,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(
      inst.nextDueDate.year,
      inst.nextDueDate.month,
      inst.nextDueDate.day,
    );
    final days = due.difference(today).inDays;

    if (days == 0) {
      return (
        label: isFa ? 'امروز' : 'Due today',
        color: AppColors.warning,
        icon: Icons.today_rounded,
      );
    }
    if (days > 0) {
      return (
        label: isFa
            ? '${TextNormalizer.auto('$days')} روز مانده'
            : '$days days left',
        color: AppColors.primary,
        icon: Icons.schedule_rounded,
      );
    }
    return (
      label: isFa
          ? '${TextNormalizer.auto('${-days}')} روز گذشته'
          : '${-days} days overdue',
      color: AppColors.danger,
      icon: Icons.error_outline_rounded,
    );
  }

  AppStatusBadge _statusBadge(InstallmentEntity inst, bool isFa, bool overdue) {
    if (inst.isCompleted) {
      return AppStatusBadge(
        label: isFa ? 'پرداخت‌شده کامل' : 'Paid in full',
        icon: Icons.check_circle_rounded,
        tone: AppStatusTone.success,
      );
    }
    if (overdue) {
      return AppStatusBadge(
        label: isFa ? 'معوق' : 'Overdue',
        icon: Icons.warning_amber_rounded,
        tone: AppStatusTone.danger,
      );
    }
    return AppStatusBadge(
      label: isFa ? 'جاری' : 'Ongoing',
      icon: Icons.autorenew_rounded,
      tone: AppStatusTone.info,
    );
  }

  // ----------------------------------------------------
  // INSTALLMENT CARD
  // ----------------------------------------------------
  Widget _buildInstallmentCard(BuildContext context, InstallmentEntity inst) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final isFa = l10n.isPersian;

    final isCompleted = inst.isCompleted;
    final countdown = _countdown(inst, isFa);
    // Display-only overdue flag: past due date while not completed. The DB is
    // never written from here.
    final isOverdue =
        !isCompleted &&
        (inst.status == InstallmentStatus.overdue ||
            countdown.color == AppColors.danger);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        // Danger-tinted border for overdue plans — display only.
        borderColor: isOverdue
            ? AppColors.danger.withValues(alpha: 0.45)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + status badge (title flexes so long Persian titles wrap).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    inst.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _statusBadge(inst, isFa, isOverdue),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Progress counter + remaining amount.
            Row(
              children: [
                Text(
                  TextNormalizer.auto(
                    '${inst.paidInstallmentsCount} از ${inst.numberOfInstallments} قسط',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkSubtext
                        : AppColors.lightSubtext,
                  ),
                ),
                const Spacer(),
                if (!isCompleted) ...[
                  Text(
                    '${isFa ? 'باقیمانده' : 'Remaining'}: ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.lightSubtext,
                    ),
                  ),
                  AppMoneyText(
                    money: inst.remainingAmount,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (inst.progressPercent / 100.0).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? AppColors.income : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              TextNormalizer.auto(
                '${inst.progressPercent.toStringAsFixed(0)}% پرداخت شده',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Due date + countdown chip.
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.isPersian ? "سررسید" : "Due"}: ${AppDateFormatter.formatShort(inst.nextDueDate, locale: l10n.localeName)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isOverdue ? AppColors.danger : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (!isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: countdown.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(countdown.icon, size: 12, color: countdown.color),
                        const SizedBox(width: 4),
                        Text(
                          countdown.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: countdown.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Overflow-safe action row: wraps instead of clipping.
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (!isCompleted)
                  TextButton.icon(
                    onPressed: () {
                      context.read<InstallmentBloc>().add(
                        InstallmentPaySubmitted(inst.id),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(isFa ? 'پرداخت قسط' : 'Pay installment'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (!isCompleted)
                  TextButton.icon(
                    onPressed: () => _confirmPayRemaining(context, inst),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: Text(isFa ? 'تسویه کامل' : 'Settle all'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: AppColors.income,
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => InstallmentHistorySheet.show(context, inst),
                  icon: const Icon(Icons.history_rounded, size: 16),
                  label: Text(isFa ? 'تاریخچه' : 'History'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => EditInstallmentSheet.show(context, inst),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(l10n.edit),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDeleteInstallment(context, inst),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: Text(l10n.delete),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // PAGE
  // ----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return BlocListener<InstallmentBloc, InstallmentState>(
      listener: (context, state) {
        if (state is InstallmentOperationSuccess) {
          final message = switch (state.op) {
            'pay' => l10n.isPersian ? 'قسط پرداخت شد' : 'Installment paid',
            'payRemaining' =>
              l10n.isPersian ? 'تسویه کامل انجام شد' : 'Fully settled',
            'update' => l10n.isPersian ? 'تغییرات ذخیره شد' : 'Changes saved',
            'delete' => l10n.isPersian ? 'قسط حذف شد' : 'Installment deleted',
            'deletePayment' =>
              l10n.isPersian
                  ? 'پرداخت حذف شد و مبلغ به حساب برگشت'
                  : 'Payment deleted; money returned to the account',
            _ => state.message,
          };
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message)));
        } else if (state is InstallmentFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.isPersian
                    ? 'خطا: ${state.message}'
                    : 'Error: ${state.message}',
              ),
            ),
          );
        }
      },
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.installments)),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showAddInstallmentDialog(context),
              child: const Icon(Icons.add),
            ),
            body: BlocBuilder<InstallmentBloc, InstallmentState>(
              builder: (context, state) {
                if (state is InstallmentLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        AppSkeleton(
                          height: 120,
                          borderRadius: AppSpacing.borderRadiusLg,
                        ),
                        SizedBox(height: AppSpacing.md),
                        AppSkeleton(
                          height: 90,
                          borderRadius: AppSpacing.borderRadiusMd,
                        ),
                      ],
                    ),
                  );
                }

                // InstallmentHistoryLoaded extends InstallmentLoaded, so the
                // list keeps rendering behind the open history sheet.
                if (state is! InstallmentLoaded) {
                  return AppEmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: l10n.installments,
                    description: l10n.isPersian
                        ? 'اقساط و وام‌های دریافتی را برای یادآوری و کسر خودکار سررسیدها ثبت کنید.'
                        : 'Track your loan installments and upcoming dues.',
                  );
                }

                final installments = state.installments;

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // Summary card
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isPersian
                                      ? 'باقیمانده کل وام‌ها'
                                      : 'Remaining Loans',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.darkSubtext
                                        : AppColors.lightSubtext,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AppMoneyText(
                                  money: state.totalDebtRemaining,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.expense,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 36,
                            width: 1,
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.isPersian
                                      ? 'تعهد ماهانه اقساط'
                                      : 'Monthly Dues',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.darkSubtext
                                        : AppColors.lightSubtext,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                AppMoneyText(
                                  money: state.monthlyInstallmentDues,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (installments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: AppEmptyState(
                          icon: Icons.calendar_month_outlined,
                          title: l10n.isPersian
                              ? 'هیچ وامی ثبت نشده است'
                              : 'No active loans',
                          description: l10n.isPersian
                              ? 'اقساط و وام‌های بانکی خود را با زدن دکمه + اضافه کنید.'
                              : 'Tap + to add your loans and installments.',
                        ),
                      )
                    else
                      ...installments.map(
                        (inst) => _buildInstallmentCard(context, inst),
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
