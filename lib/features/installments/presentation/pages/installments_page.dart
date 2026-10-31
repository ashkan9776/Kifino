import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
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

class InstallmentsPage extends StatelessWidget {
  const InstallmentsPage({super.key});

  void _showAddInstallmentDialog(BuildContext context) {
    final l10n = context.l10n;
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final countController = TextEditingController(text: l10n.isPersian ? '۱۲' : '12');

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
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSheetHeader(
                            title: l10n.isPersian ? 'ثبت وام یا اقساط جدید' : 'New Loan / Installment',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(
                              labelText: l10n.isPersian ? 'عنوان وام / کالا' : 'Title',
                              prefixIcon: const Icon(Icons.title_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianThousandsSeparatorTextInputFormatter(enabled: isFaLocale(context)),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.isPersian ? 'مبلغ هر قسط' : 'Installment Amount',
                              prefixIcon: const Icon(Icons.payments_outlined),
                              suffixText: l10n.isPersian ? 'تومان' : '',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: countController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianDigitsTextInputFormatter(enabled: isFaLocale(context)),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.isPersian ? 'تعداد کل اقساط' : 'Total Installments Count',
                              prefixIcon: const Icon(Icons.format_list_numbered_rounded),
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
                                firstDate: now.subtract(const Duration(days: 365)),
                                lastDate: now.add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setModalState(() => dueDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_month_rounded, size: 20),
                                      const SizedBox(width: 8),
                                      Text(l10n.isPersian ? 'تاریخ اولین سررسید' : 'First due date'),
                                    ],
                                  ),
                                  Text(
                                    AppDateFormatter.format(dueDate, locale: l10n.localeName),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.income,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (accState is AccountsLoaded && accState.accounts.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            DropdownButtonFormField<String>(
                              initialValue: selectedAccountId,
                              decoration: InputDecoration(
                                labelText: l10n.isPersian ? 'حساب مبدا پرداخت اقساط' : 'Payment Account',
                                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                              ),
                              items: accState.accounts.map((acc) {
                                return DropdownMenuItem(
                                  value: acc.id,
                                  child: Text('${acc.name} (${acc.bankName ?? ""})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedAccountId = val);
                              },
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: l10n.save,
                            onPressed: () {
                              final title = titleController.text.trim();
                              final singleAmountVal = int.tryParse(normalizeNumericInput(amountController.text)) ?? 0;
                              final totalCount = int.tryParse(normalizeNumericInput(countController.text)) ?? 12;

                              if (title.isNotEmpty && singleAmountVal > 0 && selectedAccountId != null) {
                                final now = DateTime.now();
                                final singleMoney = Money.fromMinor(singleAmountVal, Currency.irr);
                                final totalMoney = Money.fromMinor(singleAmountVal * totalCount, Currency.irr);

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.installments),
      ),
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
                  AppSkeleton(height: 120, borderRadius: AppSpacing.borderRadiusLg),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(height: 90, borderRadius: AppSpacing.borderRadiusMd),
                ],
              ),
            );
          }

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
                            l10n.isPersian ? 'باقیمانده کل وام‌ها' : 'Remaining Loans',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
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
                    Container(height: 36, width: 1, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isPersian ? 'تعهد ماهانه اقساط' : 'Monthly Dues',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
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
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppEmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: l10n.isPersian ? 'هیچ وامی ثبت نشده است' : 'No active loans',
                    description: l10n.isPersian
                        ? 'اقساط و وام‌های بانکی خود را با زدن دکمه + اضافه کنید.'
                        : 'Tap + to add your loans and installments.',
                  ),
                )
              else
                ...installments.map((inst) {
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inst.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    TextNormalizer.auto(
                                      '${inst.paidInstallmentsCount} از ${inst.numberOfInstallments} قسط پرداخت شده',
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AppMoneyText(
                                    money: inst.installmentAmount,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${l10n.isPersian ? "سررسید" : "Due"}: ${AppDateFormatter.formatShort(inst.nextDueDate, locale: l10n.localeName)}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (inst.progressPercent / 100.0).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                TextNormalizer.auto('${inst.progressPercent.toStringAsFixed(0)}% پرداخت شده'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                ),
                              ),
                              if (!inst.isCompleted)
                                TextButton.icon(
                                  onPressed: () {
                                    context.read<InstallmentBloc>().add(InstallmentPaySubmitted(inst.id));
                                  },
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: Text(l10n.isPersian ? 'پرداخت قسط' : 'Pay installment'),
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.income.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    l10n.settled,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.income,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
        },
      ),
        ),
      ),
    );
  }
}
