import 'package:flutter/material.dart';

import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_kit.dart';

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
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_responsive_container.dart';
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

    showAppModalSheet(
      context: context,
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
          body: AppResponsiveContainer(
            maxWidth: 960,
            child: BlocConsumer<AccountsBloc, AccountsState>(
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

                  // Group by account type, in the enum's natural order.
                  final groups = <AccountType, List<AccountEntity>>{};
                  for (final type in AccountType.values) {
                    final ofType = visible.where((a) => a.type == type);
                    if (ofType.isNotEmpty) groups[type] = ofType.toList();
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      96,
                    ),
                    children: [
                      AppHeroCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFa ? 'موجودی کل حساب‌ها' : 'Total balance',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.onInkSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            AppMoneyText(
                              money: state.totalBalance,
                              style: AppTypography.moneyHeadline.copyWith(
                                color: AppColors.onInk,
                              ),
                              usePersianDigits: true,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              TextNormalizer.auto(
                                isFa
                                    ? '${active.length} حساب فعال${archived.isEmpty ? '' : ' · ${archived.length} بایگانی'}'
                                    : '${active.length} active',
                              ),
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onInkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final entry in groups.entries) ...[
                        const SizedBox(height: AppSpacing.lg),
                        AppListGroup(
                          title: isFa ? entry.key.titleFa : entry.key.titleEn,
                          children: [
                            for (final account in entry.value)
                              _AccountRow(
                                account: account,
                                isFa: isFa,
                                icon: _iconFor(account.type),
                                onArchive: () =>
                                    context.read<AccountsBloc>().add(
                                      AccountArchiveToggled(
                                        account.id,
                                        !account.isArchived,
                                      ),
                                    ),
                                onDelete: () => _confirmDelete(account),
                              ),
                          ],
                        ),
                      ],
                    ],
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final AccountEntity account;
  final bool isFa;
  final IconData icon;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  const _AccountRow({
    required this.account,
    required this.isFa,
    required this.icon,
    required this.onArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final details = [
      if (account.bankName != null && account.bankName!.isNotEmpty)
        account.bankName!,
      if (account.cardNumberLastFour != null &&
          account.cardNumberLastFour!.isNotEmpty)
        TextNormalizer.auto('•••• ${account.cardNumberLastFour}'),
      if (account.isArchived) isFa ? 'بایگانی‌شده' : 'Archived',
    ];
    return AppListRow(
      icon: icon,
      iconColor: account.isArchived
          ? colors.textTertiary
          : Theme.of(context).colorScheme.primary,
      title: account.name,
      subtitle: details.isEmpty ? null : details.join('  ·  '),
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppMoneyText(
            money: account.currentBalance,
            style: AppTypography.moneyTile.copyWith(
              color: account.currentBalance.isNegative
                  ? colors.expense
                  : colors.textPrimary,
            ),
            usePersianDigits: true,
          ),
          PopupMenuButton<String>(
            tooltip: isFa ? 'گزینه‌ها' : 'Options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) => v == 'archive' ? onArchive() : onDelete(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'archive',
                child: Text(
                  account.isArchived
                      ? (isFa ? 'خروج از بایگانی' : 'Unarchive')
                      : (isFa ? 'بایگانی' : 'Archive'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  isFa ? 'حذف' : 'Delete',
                  style: TextStyle(color: colors.expense),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
