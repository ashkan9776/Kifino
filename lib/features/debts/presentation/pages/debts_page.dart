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

import '../../../../core/widgets/app_date_picker.dart';import '../../domain/entities/debt_entity.dart';
import '../bloc/debt_bloc.dart';

class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  int _selectedFilter = 0; // 0: All, 1: Debt, 2: Receivable

  void _showAddDebtDialog(BuildContext context) {
    final l10n = context.l10n;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DebtType selectedType = _selectedFilter == 2 ? DebtType.receivable : DebtType.debt;
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

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
                      title: l10n.isPersian ? 'ثبت بدهی یا طلب جدید' : 'New Debt or Receivable',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<DebtType>(
                      segments: [
                        ButtonSegment(value: DebtType.debt, label: Text(l10n.payables)),
                        ButtonSegment(value: DebtType.receivable, label: Text(l10n.receivables)),
                      ],
                      selected: {selectedType},
                      onSelectionChanged: (val) {
                        setModalState(() => selectedType = val.first);
                      },
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.personName,
                        prefixIcon: const Icon(Icons.person_outline_rounded),
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
                        labelText: l10n.amount,
                        prefixIcon: const Icon(Icons.payments_outlined),
                        suffixText: l10n.isPersian ? 'تومان' : '',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showAppDatePicker(
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
                                Text(l10n.isPersian ? 'تاریخ سررسید' : 'Due date'),
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
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: l10n.save,
                      onPressed: () {
                        final name = nameController.text.trim();
                        final amountVal = int.tryParse(normalizeNumericInput(amountController.text)) ?? 0;
                        if (name.isNotEmpty && amountVal > 0) {
                          final now = DateTime.now();
                          context.read<DebtBloc>().add(
                                DebtCreateSubmitted(
                                  DebtEntity(
                                    id: '',
                                    contactName: name,
                                    type: selectedType,
                                    totalAmount: Money.fromMinor(amountVal, Currency.irr),
                                    dueDate: dueDate,
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
            );
          },
        );
      },
    );
  }

  void _showPaymentDialog(BuildContext context, DebtEntity debt) {
    final l10n = context.l10n;
    final amountController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

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
                      '${l10n.isPersian ? 'ثبت پرداخت برای' : 'Record Payment for'} ${debt.contactName}',
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Text('${l10n.remaining}: '),
                    AppMoneyText(
                      money: debt.remainingAmount,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  inputFormatters: [
                    PersianThousandsSeparatorTextInputFormatter(enabled: isFaLocale(context)),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.isPersian ? 'مبلغ پرداختی' : 'Payment Amount',
                    prefixIcon: const Icon(Icons.payment_rounded),
                    suffixText: l10n.isPersian ? 'تومان' : '',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: l10n.confirm,
                  onPressed: () {
                    final amountVal = int.tryParse(normalizeNumericInput(amountController.text)) ?? 0;
                    if (amountVal > 0) {
                      context.read<DebtBloc>().add(
                            DebtPaymentSubmitted(
                              id: debt.id,
                              amount: Money.fromMinor(amountVal, debt.totalAmount.currency),
                            ),
                          );
                      Navigator.pop(bottomSheetContext);
                    }
                  },
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.debtsAndLoans),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDebtDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<DebtBloc, DebtState>(
        builder: (context, state) {
          if (state is DebtLoading) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppSkeleton(height: 120, borderRadius: AppSpacing.borderRadiusLg),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(height: 80, borderRadius: AppSpacing.borderRadiusMd),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(height: 80, borderRadius: AppSpacing.borderRadiusMd),
                ],
              ),
            );
          }

          if (state is! DebtLoaded) {
            return AppEmptyState(
              icon: Icons.handshake_outlined,
              title: l10n.debtsAndLoans,
              description: l10n.isPersian
                  ? 'بدهی‌ها و طلب‌های خود را ثبت کنید تا هیچ موعد پرداختی را از دست ندهید.'
                  : 'Track your debts and receivables to stay on top of dues.',
            );
          }

          final allDebts = state.debts;
          final filteredDebts = allDebts.where((d) {
            if (_selectedFilter == 1) return d.type == DebtType.debt;
            if (_selectedFilter == 2) return d.type == DebtType.receivable;
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // Summary Scorecard
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.payables,
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
                            l10n.receivables,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AppMoneyText(
                            money: state.totalReceivableRemaining,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Filter Segments
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(l10n.all)),
                  ButtonSegment(value: 1, label: Text(l10n.payables)),
                  ButtonSegment(value: 2, label: Text(l10n.receivables)),
                ],
                selected: {_selectedFilter},
                onSelectionChanged: (val) {
                  setState(() => _selectedFilter = val.first);
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: AppSpacing.md),

              if (filteredDebts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppEmptyState(
                    icon: Icons.handshake_outlined,
                    title: l10n.isPersian ? 'موردی یافت نشد' : 'No records found',
                    description: l10n.isPersian
                        ? 'موردی در این دسته‌بندی وجود ندارد.'
                        : 'No items in this category.',
                  ),
                )
              else
                ...filteredDebts.map((debt) {
                  final isReceivable = debt.type == DebtType.receivable;
                  final typeColor = isReceivable ? AppColors.income : AppColors.expense;

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
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: typeColor.withValues(alpha: 0.12),
                                    child: Icon(
                                      isReceivable ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                      size: 18,
                                      color: typeColor,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        debt.contactName,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (debt.dueDate != null)
                                        Text(
                                          '${l10n.dueDate}: ${AppDateFormatter.formatShort(debt.dueDate!, locale: l10n.localeName)}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: debt.isOverdue
                                                ? AppColors.danger
                                                : (isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AppMoneyText(
                                    money: debt.remainingAmount,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: typeColor,
                                    ),
                                  ),
                                  if (debt.isSettled)
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
                          if (!debt.isSettled) ...[
                            const SizedBox(height: AppSpacing.sm),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (debt.progressPercent / 100.0).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                valueColor: AlwaysStoppedAnimation<Color>(typeColor),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  TextNormalizer.auto('${debt.progressPercent.toStringAsFixed(0)}% ${l10n.settled}'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showPaymentDialog(context, debt),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: Text(l10n.isPersian ? 'ثبت پرداخت' : 'Pay'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
