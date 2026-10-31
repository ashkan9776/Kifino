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
import '../../domain/entities/check_entity.dart';
import '../bloc/check_bloc.dart';

class ChecksPage extends StatefulWidget {
  const ChecksPage({super.key});

  @override
  State<ChecksPage> createState() => _ChecksPageState();
}

class _ChecksPageState extends State<ChecksPage> {
  int _selectedFilter = 0; // 0: All, 1: Issued, 2: Received

  void _showAddCheckDialog(BuildContext context) {
    final l10n = context.l10n;
    final numberController = TextEditingController();
    final sayadiController = TextEditingController();
    final bankController = TextEditingController();
    final partyController = TextEditingController();
    final amountController = TextEditingController();
    CheckType selectedType = _selectedFilter == 1 ? CheckType.issued : CheckType.received;
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
                            title: l10n.isPersian ? 'ثبت چک صیادی جدید' : 'New Sayadi Check',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SegmentedButton<CheckType>(
                            segments: [
                              ButtonSegment(value: CheckType.received, label: Text(l10n.isPersian ? 'دریافتی' : 'Received')),
                              ButtonSegment(value: CheckType.issued, label: Text(l10n.isPersian ? 'صادره' : 'Issued')),
                            ],
                            selected: {selectedType},
                            onSelectionChanged: (val) {
                              setModalState(() => selectedType = val.first);
                            },
                            showSelectedIcon: false,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: partyController,
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
                          TextField(
                            controller: bankController,
                            decoration: InputDecoration(
                              labelText: l10n.bankName,
                              prefixIcon: const Icon(Icons.account_balance_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: numberController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianDigitsTextInputFormatter(enabled: isFaLocale(context)),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.checkNumber,
                              prefixIcon: const Icon(Icons.confirmation_number_outlined),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: sayadiController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              PersianDigitsTextInputFormatter(enabled: isFaLocale(context)),
                            ],
                            decoration: InputDecoration(
                              labelText: l10n.isPersian ? 'شناسه صیادی (۱۶ رقمی)' : 'Sayadi ID (16 digits)',
                              prefixIcon: const Icon(Icons.qr_code_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          // Due Date Picker
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
                                      Text(l10n.isPersian ? 'تاریخ سررسید چک' : 'Due date'),
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
                                labelText: l10n.isPersian ? 'حساب بانکی متصل' : 'Linked Account',
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
                              final party = partyController.text.trim();
                              final bank = bankController.text.trim();
                              final number = numberController.text.trim();
                              final amountVal = int.tryParse(normalizeNumericInput(amountController.text)) ?? 0;

                              if (party.isNotEmpty && amountVal > 0 && number.isNotEmpty) {
                                final now = DateTime.now();
                                context.read<CheckBloc>().add(
                                      CheckCreateSubmitted(
                                        CheckEntity(
                                          id: '',
                                          checkNumber: number,
                                          sayadiId: sayadiController.text.trim().isNotEmpty ? sayadiController.text.trim() : null,
                                          bankName: bank.isNotEmpty ? bank : 'بانک ملی',
                                          type: selectedType,
                                          amount: Money.fromMinor(amountVal, Currency.irr),
                                          partyName: party,
                                          dueDate: dueDate,
                                          accountId: selectedAccountId,
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
        title: Text(l10n.checks),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCheckDialog(context),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<CheckBloc, CheckState>(
        builder: (context, state) {
          if (state is CheckLoading) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  AppSkeleton(height: 120, borderRadius: AppSpacing.borderRadiusLg),
                  SizedBox(height: AppSpacing.md),
                  AppSkeleton(height: 80, borderRadius: AppSpacing.borderRadiusMd),
                ],
              ),
            );
          }

          if (state is! CheckLoaded) {
            return AppEmptyState(
              icon: Icons.fact_check_outlined,
              title: l10n.checks,
              description: l10n.isPersian
                  ? 'مدیریت و ثبت چک‌های صیادی صادره و دریافتی.'
                  : 'Track your issued and received Sayadi checks.',
            );
          }

          final filteredChecks = state.checks.where((c) {
            if (_selectedFilter == 1) return c.type == CheckType.issued;
            if (_selectedFilter == 2) return c.type == CheckType.received;
            return true;
          }).toList();

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
                            l10n.isPersian ? 'چک‌های در انتظار پرداخت' : 'Pending Issued',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AppMoneyText(
                            money: state.totalPendingIssued,
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
                            l10n.isPersian ? 'چک‌های در انتظار وصول' : 'Pending Received',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AppMoneyText(
                            money: state.totalPendingReceived,
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
                  ButtonSegment(value: 1, label: Text(l10n.isPersian ? 'صادره' : 'Issued')),
                  ButtonSegment(value: 2, label: Text(l10n.isPersian ? 'دریافتی' : 'Received')),
                ],
                selected: {_selectedFilter},
                onSelectionChanged: (val) {
                  setState(() => _selectedFilter = val.first);
                },
                showSelectedIcon: false,
              ),
              const SizedBox(height: AppSpacing.md),

              if (filteredChecks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: AppEmptyState(
                    icon: Icons.fact_check_outlined,
                    title: l10n.isPersian ? 'چکی ثبت نشده است' : 'No checks found',
                    description: l10n.isPersian
                        ? 'برای ثبت چک صیادی، دکمه + را لمس کنید.'
                        : 'Tap + to register a check.',
                  ),
                )
              else
                ...filteredChecks.map((check) {
                  final isReceived = check.type == CheckType.received;
                  final typeColor = isReceived ? AppColors.income : AppColors.expense;

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
                                      Icons.account_balance_rounded,
                                      size: 18,
                                      color: typeColor,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        check.partyName,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${check.bankName} · شماره: ${TextNormalizer.auto(check.checkNumber)}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                        ),
                                      ),
                                      if (check.sayadiId != null && check.sayadiId!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'شناسه صیادی: ${TextNormalizer.auto(check.sayadiId!)}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: AppColors.primary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AppMoneyText(
                                    money: check.amount,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: typeColor,
                                    ),
                                  ),
                                  Text(
                                    AppDateFormatter.formatShort(check.dueDate, locale: l10n.localeName),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: check.isOverdue ? AppColors.danger : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (check.isCleared ? AppColors.income : AppColors.warning).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  check.status.titleFa,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: check.isCleared ? AppColors.income : AppColors.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (check.isPending)
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        context.read<CheckBloc>().add(
                                              CheckStatusUpdated(id: check.id, status: CheckStatus.cleared),
                                            );
                                      },
                                      child: Text(l10n.isPersian ? 'وصول شد' : 'Cleared'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        context.read<CheckBloc>().add(
                                              CheckStatusUpdated(id: check.id, status: CheckStatus.bounced),
                                            );
                                      },
                                      child: Text(
                                        l10n.isPersian ? 'برگشت خورد' : 'Bounced',
                                        style: const TextStyle(color: AppColors.danger),
                                      ),
                                    ),
                                  ],
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
