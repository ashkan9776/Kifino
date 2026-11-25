import 'package:flutter/material.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/app_kit.dart';

import '../../../../core/constants/app_currency.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_responsive_container.dart';
import '../../../../core/widgets/app_skeleton.dart';

import '../../../../core/widgets/app_date_picker.dart';
import '../../../../core/widgets/optional_account_selector.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../domain/entities/debt_entity.dart';
import '../bloc/debt_bloc.dart';
import '../widgets/edit_debt_sheet.dart';

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
    DebtType selectedType = _selectedFilter == 2
        ? DebtType.receivable
        : DebtType.debt;
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
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.lightSurface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSheetHeader(
                      title: l10n.isPersian
                          ? 'ثبت بدهی یا طلب جدید'
                          : 'New Debt or Receivable',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<DebtType>(
                      segments: [
                        ButtonSegment(
                          value: DebtType.debt,
                          label: Text(l10n.payables),
                        ),
                        ButtonSegment(
                          value: DebtType.receivable,
                          label: Text(l10n.receivables),
                        ),
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
                        PersianThousandsSeparatorTextInputFormatter(
                          enabled: isFaLocale(context),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.amount,
                        prefixIcon: const Icon(Icons.payments_outlined),
                        suffixText: AppCurrency.base.symbol,
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.isPersian ? 'تاریخ سررسید' : 'Due date',
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
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: l10n.save,
                      onPressed: () {
                        final name = nameController.text.trim();
                        final amountVal =
                            int.tryParse(
                              normalizeNumericInput(amountController.text),
                            ) ??
                            0;
                        if (name.isNotEmpty && amountVal > 0) {
                          final now = DateTime.now();
                          context.read<DebtBloc>().add(
                            DebtCreateSubmitted(
                              DebtEntity(
                                id: '',
                                contactName: name,
                                type: selectedType,
                                totalAmount: Money.fromMinor(
                                  amountVal,
                                  AppCurrency.base,
                                ),
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
    final accountsFuture = sl.isRegistered<AccountRepository>()
        ? sl<AccountRepository>().getAccounts()
        : Future.value(const Success(<AccountEntity>[]));
    String? selectedAccountId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      inputFormatters: [
                        PersianThousandsSeparatorTextInputFormatter(
                          enabled: isFaLocale(context),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.isPersian
                            ? 'مبلغ پرداختی'
                            : 'Payment Amount',
                        prefixIcon: const Icon(Icons.payment_rounded),
                        suffixText: AppCurrency.base.symbol,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OptionalAccountSelector(
                      accountsFuture: accountsFuture,
                      compatibleCurrency: debt.totalAmount.currency,
                      selectedAccountId: selectedAccountId,
                      label: debt.type == DebtType.debt
                          ? (l10n.isPersian
                                ? 'برداشت از حساب (اختیاری)'
                                : 'Deduct from account (optional)')
                          : (l10n.isPersian
                                ? 'واریز به حساب (اختیاری)'
                                : 'Deposit to account (optional)'),
                      onChanged: (val) =>
                          setModalState(() => selectedAccountId = val),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: l10n.confirm,
                      onPressed: () {
                        final amountVal =
                            int.tryParse(
                              normalizeNumericInput(amountController.text),
                            ) ??
                            0;
                        if (amountVal > 0) {
                          context.read<DebtBloc>().add(
                            DebtPaymentSubmitted(
                              id: debt.id,
                              amount: Money.fromMinor(
                                amountVal,
                                debt.totalAmount.currency,
                              ),
                              accountId: selectedAccountId,
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
    ).whenComplete(amountController.dispose);
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
          appBar: AppBar(title: Text(l10n.debtsAndLoans)),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDebtDialog(context),
            child: const Icon(Icons.add),
          ),
          body: AppResponsiveContainer(
            maxWidth: 960,
            child: BlocConsumer<DebtBloc, DebtState>(
              listenWhen: (prev, curr) => curr is DebtFailure,
              listener: (context, state) {
                if (state is DebtFailure) {
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
              builder: (context, state) {
                if (state is DebtLoading) {
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
                          height: 80,
                          borderRadius: AppSpacing.borderRadiusMd,
                        ),
                        SizedBox(height: AppSpacing.md),
                        AppSkeleton(
                          height: 80,
                          borderRadius: AppSpacing.borderRadiusMd,
                        ),
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
                // Nothing recorded yet: one clear call to action instead of a hero
                // full of zeros above an empty list.
                if (allDebts.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.handshake_outlined,
                    title: l10n.isPersian
                        ? 'هنوز بدهی یا طلبی ثبت نکرده‌اید'
                        : 'Nothing here yet',
                    description: l10n.isPersian
                        ? 'پولی که به کسی بدهکارید یا از کسی طلب دارید را ثبت کنید تا موعدش یادتان بماند.'
                        : 'Add your first one to start tracking it.',
                    actionLabel: l10n.isPersian ? 'ثبت بدهی یا طلب' : 'Add',
                    onAction: () => _showAddDebtDialog(context),
                  );
                }
                final filteredDebts = allDebts.where((d) {
                  if (_selectedFilter == 1) {
                    return d.type == DebtType.debt;
                  }
                  if (_selectedFilter == 2) {
                    return d.type == DebtType.receivable;
                  }
                  return true;
                }).toList();

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    // Net position: what others owe me minus what I owe.
                    AppHeroCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.isPersian ? 'خالص طلب و بدهی' : 'Net position',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.onInkSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppMoneyText(
                            money:
                                state.totalReceivableRemaining -
                                state.totalDebtRemaining,
                            sign: MoneyDisplaySign.positiveNegative,
                            colorCode: false,
                            style: AppTypography.moneyHeadline.copyWith(
                              color: AppColors.onInk,
                            ),
                            usePersianDigits: true,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: AppHeroStat(
                                  label: l10n.receivables,
                                  icon: Icons.south_west_rounded,
                                  iconColor: AppColors.incomeDark,
                                  value: AppMoneyText(
                                    money: state.totalReceivableRemaining,
                                    usePersianDigits: true,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: AppHeroStat(
                                  label: l10n.payables,
                                  icon: Icons.north_east_rounded,
                                  iconColor: AppColors.expenseDark,
                                  value: AppMoneyText(
                                    money: state.totalDebtRemaining,
                                    usePersianDigits: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppFilterBar<int>(
                      options: [
                        (0, l10n.all),
                        (1, l10n.payables),
                        (2, l10n.receivables),
                      ],
                      selected: _selectedFilter,
                      onSelected: (v) => setState(() => _selectedFilter = v),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (filteredDebts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: AppEmptyState(
                          icon: Icons.handshake_outlined,
                          title: l10n.isPersian
                              ? 'موردی یافت نشد'
                              : 'No records found',
                          description: l10n.isPersian
                              ? 'موردی در این دسته‌بندی وجود ندارد.'
                              : 'No items in this category.',
                        ),
                      )
                    else
                      ...filteredDebts.map((debt) {
                        final isReceivable = debt.type == DebtType.receivable;
                        final typeColor = isReceivable
                            ? AppColors.income
                            : AppColors.expense;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        AppIconBadge(
                                          icon: isReceivable
                                              ? Icons.south_west_rounded
                                              : Icons.north_east_rounded,
                                          color: typeColor,
                                          size: 38,
                                          iconSize: 19,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              debt.contactName,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            if (debt.dueDate != null)
                                              Text(
                                                '${l10n.dueDate}: ${AppDateFormatter.formatShort(debt.dueDate!, locale: l10n.localeName)}',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: debt.isOverdue
                                                          ? AppColors.danger
                                                          : (isDark
                                                                ? AppColors
                                                                      .darkSubtext
                                                                : AppColors
                                                                      .lightSubtext),
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        AppMoneyText(
                                          money: debt.remainingAmount,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: typeColor,
                                              ),
                                        ),
                                        if (debt.isSettled)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.income
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              l10n.settled,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
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
                                      value: (debt.progressPercent / 100.0)
                                          .clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor: isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        typeColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        TextNormalizer.auto(
                                          '${debt.progressPercent.toStringAsFixed(0)}% ${l10n.settled}',
                                        ),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: isDark
                                                  ? AppColors.darkSubtext
                                                  : AppColors.lightSubtext,
                                            ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                            ),
                                            tooltip: l10n.isPersian
                                                ? 'ویرایش'
                                                : 'Edit',
                                            onPressed: () => EditDebtSheet.show(
                                              context,
                                              debt,
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () => _showPaymentDialog(
                                              context,
                                              debt,
                                            ),
                                            icon: const Icon(
                                              Icons.add,
                                              size: 16,
                                            ),
                                            label: Text(
                                              l10n.isPersian
                                                  ? 'ثبت پرداخت'
                                                  : 'Pay',
                                            ),
                                            style: TextButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ),
                                        ],
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
      ),
    );
  }
}
