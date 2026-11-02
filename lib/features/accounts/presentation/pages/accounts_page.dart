import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/persian_input.dart';
import '../../../../core/widgets/app_amount_field.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/account_entity.dart';
import '../bloc/accounts_bloc.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  late final AccountsBloc _accountsBloc;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _accountsBloc = context.read<AccountsBloc>();
    // Include archived accounts so the local toggle can reveal them.
    _accountsBloc.add(const WatchAccountsStarted(includeArchived: true));
  }

  @override
  void dispose() {
    // Restore the app-wide default stream (active accounts only) so other
    // pages sharing this bloc are not affected by the archive toggle.
    _accountsBloc.add(const WatchAccountsStarted());
    super.dispose();
  }

  void _confirmDelete(AccountEntity account) {
    final l10n = context.l10n;
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.isPersian ? 'حذف حساب؟' : 'Delete account?'),
        content: Text(
          l10n.isPersian
              ? 'این عمل قابل بازگشت نیست'
              : 'This action cannot be undone',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.expenseLight,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        context.read<AccountsBloc>().add(AccountDeleteRequested(account.id));
      }
    });
  }

  void _showAddAccountSheet(BuildContext context) {
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final currency = context.read<SettingsCubit>().state.currency;

    final nameController = TextEditingController();
    final bankNameController = TextEditingController();
    final lastFourController = TextEditingController();
    AccountType selectedType = AccountType.bankCard;
    int initialBalanceMinor = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            void submit() {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isFa
                          ? 'لطفاً نام حساب را وارد کنید'
                          : 'Please enter an account name',
                    ),
                    backgroundColor: AppColors.expenseLight,
                  ),
                );
                return;
              }

              final now = DateTime.now();
              final bankName = bankNameController.text.trim();
              final lastFour = lastFourController.text.trim();

              final account = AccountEntity(
                id: const Uuid().v4(),
                name: name,
                type: selectedType,
                currency: currency,
                initialBalance: Money.fromMinor(initialBalanceMinor, currency),
                currentBalance: Money.fromMinor(initialBalanceMinor, currency),
                bankName: bankName.isNotEmpty ? bankName : null,
                cardNumberLastFour: lastFour.length == 4 ? lastFour : null,
                createdAt: now,
                updatedAt: now,
              );

              context.read<AccountsBloc>().add(AccountCreateRequested(account));
              Navigator.of(sheetContext).pop();
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(isFa ? 'حساب اضافه شد' : 'Account added'),
                  backgroundColor: AppColors.incomeLight,
                ),
              );
            }

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
                      AppSheetHeader(title: isFa ? 'حساب جدید' : 'New Account'),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: isFa ? 'نام حساب' : 'Account name',
                          prefixIcon: const Icon(
                            Icons.account_balance_wallet_rounded,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isFa ? 'نوع حساب' : 'Account type',
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: AccountType.values.map((type) {
                          return ChoiceChip(
                            label: Text(isFa ? type.titleFa : type.titleEn),
                            selected: selectedType == type,
                            onSelected: (_) =>
                                setModalState(() => selectedType = type),
                          );
                        }).toList(),
                      ),
                      if (selectedType == AccountType.bankCard) ...[
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: bankNameController,
                          decoration: InputDecoration(
                            labelText: isFa
                                ? 'نام بانک (اختیاری)'
                                : 'Bank name (optional)',
                            prefixIcon: const Icon(
                              Icons.account_balance_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: lastFourController,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          inputFormatters: [
                            PersianDigitsTextInputFormatter(
                              enabled: isFaLocale(context),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: isFa
                                ? '۴ رقم آخر کارت (اختیاری)'
                                : 'Card last 4 digits (optional)',
                            prefixIcon: const Icon(Icons.credit_card_rounded),
                            counterText: '',
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isFa
                            ? 'موجودی اولیه (اختیاری)'
                            : 'Initial balance (optional)',
                        style: AppTypography.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppAmountField(
                        currency: currency,
                        autoFocus: false,
                        onAmountMinorChanged: (value) =>
                            initialBalanceMinor = value,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: isFa ? 'افزودن حساب' : 'Add account',
                        onPressed: submit,
                        width: double.infinity,
                        variant: AppButtonVariant.primary,
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

  IconData _iconFor(AccountType type) {
    return switch (type) {
      AccountType.bankCard => Icons.credit_card_rounded,
      AccountType.cashWallet => Icons.account_balance_wallet_rounded,
      AccountType.savings => Icons.savings_rounded,
      AccountType.credit => Icons.credit_score_rounded,
      AccountType.investment => Icons.trending_up_rounded,
      AccountType.crypto => Icons.currency_bitcoin_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final colors = context.customColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.accounts),
            actions: [
              IconButton(
                tooltip: _showArchived
                    ? (isFa ? 'پنهان کردن بایگانی‌شده‌ها' : 'Hide archived')
                    : (isFa ? 'نمایش بایگانی‌شده‌ها' : 'Show archived'),
                icon: Icon(
                  _showArchived
                      ? Icons.inventory_rounded
                      : Icons.inventory_2_outlined,
                ),
                onPressed: () => setState(() => _showArchived = !_showArchived),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddAccountSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(isFa ? 'حساب جدید' : 'New account'),
          ),
          body: BlocConsumer<AccountsBloc, AccountsState>(
            listener: (context, state) {
              if (state is AccountsFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: AppColors.expenseLight,
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state is AccountsLoading) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      const AppSkeleton(height: 76),
                      const SizedBox(height: AppSpacing.md),
                      const AppSkeleton(height: 76),
                      const SizedBox(height: AppSpacing.sm),
                      const AppSkeleton(height: 76),
                    ],
                  ),
                );
              }

              if (state is AccountsLoaded) {
                final accounts = state.accounts;
                if (accounts.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: isFa ? 'هنوز حسابی ندارید' : 'No accounts yet',
                    description: isFa
                        ? 'برای مدیریت پول خود، اولین حساب را اضافه کنید.'
                        : 'Add your first account to start managing your money.',
                    actionLabel: isFa ? 'افزودن حساب' : 'Add account',
                    onAction: () => _showAddAccountSheet(context),
                  );
                }

                final active = accounts.where((a) => !a.isArchived).toList();
                final archived = accounts.where((a) => a.isArchived).toList();
                final visible = _showArchived
                    ? [...active, ...archived]
                    : active;

                if (visible.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: isFa
                        ? 'همه حساب‌ها بایگانی شده‌اند'
                        : 'All accounts are archived',
                    description: isFa
                        ? 'برای مشاهده حساب‌های بایگانی‌شده، از آیکن بالای صفحه استفاده کنید.'
                        : 'Use the icon above to show your archived accounts.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    96,
                  ),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final account = visible[index];
                    final subtitleParts = <String>[
                      isFa ? account.type.titleFa : account.type.titleEn,
                      if (account.bankName != null &&
                          account.bankName!.isNotEmpty)
                        account.bankName!,
                      if (account.cardNumberLastFour != null &&
                          account.cardNumberLastFour!.isNotEmpty)
                        '•••• ${account.cardNumberLastFour}',
                    ];

                    return AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.1),
                              borderRadius: AppSpacing.borderRadiusMd,
                            ),
                            child: Icon(
                              _iconFor(account.type),
                              size: 22,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        account.name,
                                        style: AppTypography.titleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (account.isArchived) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: AppSpacing.xxs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.warning.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius:
                                              AppSpacing.borderRadiusSm,
                                        ),
                                        child: Text(
                                          isFa ? 'بایگانی' : 'Archived',
                                          style: AppTypography.labelMedium
                                              .copyWith(color: colors.warning),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitleParts.join(' • '),
                                  style: AppTypography.labelMedium.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppMoneyText(
                            money: account.currentBalance,
                            style: AppTypography.moneyTile,
                            usePersianDigits: true,
                          ),
                          PopupMenuButton<String>(
                            tooltip: isFa ? 'بیشتر' : 'More',
                            onSelected: (value) {
                              if (value == 'archive') {
                                context.read<AccountsBloc>().add(
                                  AccountArchiveToggled(
                                    account.id,
                                    !account.isArchived,
                                  ),
                                );
                              } else if (value == 'delete') {
                                _confirmDelete(account);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'archive',
                                child: Row(
                                  children: [
                                    Icon(
                                      account.isArchived
                                          ? Icons.unarchive_rounded
                                          : Icons.inventory_2_outlined,
                                      size: 20,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      isFa
                                          ? (account.isArchived
                                                ? 'خروج از بایگانی'
                                                : 'بایگانی')
                                          : (account.isArchived
                                                ? 'Unarchive'
                                                : 'Archive'),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: AppColors.expenseLight,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      l10n.delete,
                                      style: const TextStyle(
                                        color: AppColors.expenseLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
