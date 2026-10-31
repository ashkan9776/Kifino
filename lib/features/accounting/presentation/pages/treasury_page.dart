import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_currency.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_transaction_tile.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/presentation/bloc/accounts_bloc.dart';
import '../../../transactions/presentation/bloc/transaction_bloc.dart';

/// خزانه — light treasury view over the liquid accounts (bank cards +
/// cash wallets) with a recent cash-flow hint.
class TreasuryPage extends StatelessWidget {
  const TreasuryPage({super.key});

  /// Liquid accounts only: bank cards and cash wallets, excluding archived.
  static List<AccountEntity> _liquidAccounts(List<AccountEntity> accounts) =>
      accounts
          .where(
            (a) =>
                !a.isArchived &&
                (a.type == AccountType.bankCard ||
                    a.type == AccountType.cashWallet),
          )
          .toList();

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      appBar: AppBar(title: const Text('خزانه'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<AccountsBloc>().add(const WatchAccountsStarted());
          context.read<TransactionBloc>().add(const WatchTransactionsStarted());
        },
        child: BlocBuilder<AccountsBloc, AccountsState>(
          builder: (context, state) {
            if (state is AccountsInitial || state is AccountsLoading) {
              return const _TreasurySkeleton();
            }

            if (state is AccountsFailure) {
              return AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'خطا در خواندن حساب‌ها',
                description: state.message,
              );
            }

            final accounts = state is AccountsLoaded
                ? _liquidAccounts(state.accounts)
                : const <AccountEntity>[];

            if (accounts.isEmpty) {
              return AppEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'حساب نقدی یا بانکی ثبت نشده',
                description: 'از بخش حساب‌ها یک کارت بانکی یا کیف پول نقدی اضافه کنید تا خزانه فعال شود.',
              );
            }

            // Liquid total speaks the base currency: Iranian balances are
            // normalized (Toman↔Rial ×10); foreign-currency accounts are
            // listed but excluded from the sum (same rule as AccountsBloc).
            final currency = AppCurrency.base;
            int liquidMinor = 0;
            for (final acc in accounts) {
              if (acc.currentBalance.isCompatibleWith(currency)) {
                liquidMinor += acc.currentBalance
                    .normalizeTo(currency)
                    .minorUnits;
              }
            }

            final accountIds = accounts.map((a) => a.id).toSet();

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildSummaryCard(
                  colors,
                  accounts.length,
                  liquidMinor,
                  currency,
                ),
                const SizedBox(height: 20),
                Text('حساب‌های نقدی و بانکی', style: AppTypography.titleMedium),
                const SizedBox(height: 10),
                ...accounts.map(
                  (acc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildAccountRow(context, colors, acc),
                  ),
                ),
                const SizedBox(height: 12),
                _buildRecentFlows(context, colors, accountIds),
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // HEADER SUMMARY
  // ----------------------------------------------------
  Widget _buildSummaryCard(
    KifinoColorsExtension colors,
    int accountCount,
    int liquidMinor,
    Currency currency,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.income, colors.income.withValues(alpha: 0.8)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.income.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'موجودی نقد و بانک',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppMoneyText(
            money: Money.fromMinor(liquidMinor, currency),
            style: AppTypography.moneyHeadline.copyWith(color: Colors.white),
            usePersianDigits: true,
          ),
          const SizedBox(height: 6),
          Text(
            '${TextNormalizer.toPersianDigits(accountCount.toString())} حساب نقدی / بانکی فعال',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // ACCOUNT ROW
  // ----------------------------------------------------
  Widget _buildAccountRow(
    BuildContext context,
    KifinoColorsExtension colors,
    AccountEntity account,
  ) {
    final icon = switch (account.type) {
      AccountType.bankCard => Icons.credit_card_rounded,
      _ => Icons.payments_rounded,
    };

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _accountSubtitle(account),
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppMoneyText(
                money: account.currentBalance,
                style: AppTypography.moneyTile.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: const Text('چک‌ها'),
                onPressed: () => context.push(
                  '/accounting/treasury/reconcile',
                  extra: account.id,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _accountSubtitle(AccountEntity account) {
    final parts = <String>[
      if (account.bankName != null && account.bankName!.isNotEmpty)
        account.bankName!,
      if (account.cardNumberLastFour != null &&
          account.cardNumberLastFour!.isNotEmpty)
        '**** ${account.cardNumberLastFour!}',
    ];
    if (parts.isEmpty) return account.type.titleFa;
    return parts.join(' • ');
  }

  // ----------------------------------------------------
  // RECENT CASH-FLOW HINT
  // ----------------------------------------------------
  Widget _buildRecentFlows(
    BuildContext context,
    KifinoColorsExtension colors,
    Set<String> accountIds,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('آخرین گردش‌ها', style: AppTypography.titleMedium),
        const SizedBox(height: 4),
        BlocBuilder<TransactionBloc, TransactionState>(
          builder: (context, state) {
            if (state is! TransactionLoaded) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final recent =
                state.transactions
                    .where(
                      (t) =>
                          accountIds.contains(t.accountId) ||
                          (t.destinationAccountId != null &&
                              accountIds.contains(t.destinationAccountId)),
                    )
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
            final top5 = recent.take(5).toList();

            if (top5.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'گردشی برای این حساب‌ها ثبت نشده است.',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              );
            }

            return Column(
              children: top5
                  .map((t) => AppTransactionTile(transaction: t))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _TreasurySkeleton extends StatelessWidget {
  const _TreasurySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: const [
        AppSkeleton(
          height: 140,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        SizedBox(height: 20),
        AppSkeleton(
          height: 88,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        SizedBox(height: 10),
        AppSkeleton(
          height: 88,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        SizedBox(height: 10),
        AppSkeleton(
          height: 88,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ],
    );
  }
}
