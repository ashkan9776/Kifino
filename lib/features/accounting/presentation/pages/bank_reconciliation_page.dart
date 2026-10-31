import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../core/design_system/components/financial/app_status_badge.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../accounts/domain/entities/account_entity.dart';
import '../../../accounts/presentation/bloc/accounts_bloc.dart';
import '../../../checks/domain/entities/check_entity.dart';
import '../../../checks/presentation/bloc/check_bloc.dart';

/// مغایرت‌گیری ساده بانک — checks parked on one account vs its book balance.
///
/// Status changes are dispatched through the app-level [CheckBloc] so the
/// automatic double-entry vouchers keep firing; this page never touches the
/// repository directly.
class BankReconciliationPage extends StatelessWidget {
  final String accountId;

  const BankReconciliationPage({super.key, required this.accountId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مغایرت‌گیری حساب'), centerTitle: true),
      body: BlocBuilder<AccountsBloc, AccountsState>(
        builder: (context, accountsState) {
          if (accountsState is AccountsInitial ||
              accountsState is AccountsLoading) {
            return const _ReconcileSkeleton();
          }

          AccountEntity? account;
          if (accountsState is AccountsLoaded) {
            for (final a in accountsState.accounts) {
              if (a.id == accountId) {
                account = a;
                break;
              }
            }
          }

          if (account == null) {
            return AppEmptyState(
              icon: Icons.account_balance_outlined,
              title: 'حساب یافت نشد',
              description: 'این حساب حذف یا بایگانی شده است.',
            );
          }

          return BlocBuilder<CheckBloc, CheckState>(
            builder: (context, checkState) {
              if (checkState is CheckInitial || checkState is CheckLoading) {
                return const _ReconcileSkeleton();
              }

              final checks = checkState is CheckLoaded
                  ? checkState.checks
                        .where((c) => c.accountId == accountId)
                        .toList()
                  : const <CheckEntity>[];

              final pending =
                  checks.where((c) => c.status == CheckStatus.pending).toList()
                    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
              final settled =
                  checks
                      .where(
                        (c) =>
                            c.status == CheckStatus.cleared ||
                            c.status == CheckStatus.transferred,
                      )
                      .toList()
                    ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
              final failed =
                  checks
                      .where(
                        (c) =>
                            c.status == CheckStatus.bounced ||
                            c.status == CheckStatus.cancelled,
                      )
                      .toList()
                    ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

              int pendingReceivedMinor = 0;
              int pendingIssuedMinor = 0;
              for (final c in pending) {
                if (c.type == CheckType.received) {
                  pendingReceivedMinor += c.amount.minorUnits;
                } else {
                  pendingIssuedMinor += c.amount.minorUnits;
                }
              }

              // Approximate real balance: book balance + pending received
              // (checks not yet cashed still add) − pending issued.
              final bookMinor = account!.currentBalance.minorUnits;
              final realMinor =
                  bookMinor + pendingReceivedMinor - pendingIssuedMinor;

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  _buildBalanceCard(
                    context,
                    account,
                    bookMinor,
                    realMinor,
                    pendingReceivedMinor,
                    pendingIssuedMinor,
                  ),
                  const SizedBox(height: 20),
                  _buildCheckGroup(
                    context,
                    title: 'چک‌های در جریان وصول',
                    icon: Icons.schedule_rounded,
                    tone: AppStatusTone.warning,
                    checks: pending,
                    showActions: true,
                  ),
                  const SizedBox(height: 16),
                  _buildCheckGroup(
                    context,
                    title: 'پاس / واگذار شده',
                    icon: Icons.check_circle_rounded,
                    tone: AppStatusTone.success,
                    checks: settled,
                    showActions: false,
                  ),
                  if (failed.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildCheckGroup(
                      context,
                      title: 'برگشتی / باطل‌شده',
                      icon: Icons.error_outline_rounded,
                      tone: AppStatusTone.danger,
                      checks: failed,
                      showActions: false,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'مغایرت‌گیری ساده — اسناد حسابداری چک‌ها خودکار صادر می‌شوند.',
                            style: AppTypography.bodySmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ----------------------------------------------------
  // BALANCE SUMMARY
  // ----------------------------------------------------
  Widget _buildBalanceCard(
    BuildContext context,
    AccountEntity account,
    int bookMinor,
    int realMinor,
    int pendingReceivedMinor,
    int pendingIssuedMinor,
  ) {
    final currency = account.currentBalance.currency;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  account.name,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('مانده دفاتر', style: AppTypography.bodySmall),
                  const SizedBox(height: 4),
                  AppMoneyText(money: Money.fromMinor(bookMinor, currency)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('مانده واقعی (تقریبی)', style: AppTypography.bodySmall),
                  const SizedBox(height: 4),
                  AppMoneyText(
                    money: Money.fromMinor(realMinor, currency),
                    style: AppTypography.moneyTile.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.arrow_downward_rounded,
                    size: 14,
                    color: Color(0xFF25C997),
                  ),
                  const SizedBox(width: 4),
                  Text('دریافتی در جریان:', style: AppTypography.bodySmall),
                  const SizedBox(width: 6),
                  AppMoneyText(
                    money: Money.fromMinor(pendingReceivedMinor, currency),
                    style: AppTypography.bodySmall,
                    includeSymbol: true,
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.arrow_upward_rounded,
                    size: 14,
                    color: Color(0xFFFF5C6C),
                  ),
                  const SizedBox(width: 4),
                  Text('صادره در جریان:', style: AppTypography.bodySmall),
                  const SizedBox(width: 6),
                  AppMoneyText(
                    money: Money.fromMinor(pendingIssuedMinor, currency),
                    style: AppTypography.bodySmall,
                    includeSymbol: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // CHECK GROUP
  // ----------------------------------------------------
  Widget _buildCheckGroup(
    BuildContext context, {
    required String title,
    required IconData icon,
    required AppStatusTone tone,
    required List<CheckEntity> checks,
    required bool showActions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(title, style: AppTypography.titleMedium),
            const SizedBox(width: 8),
            Text(
              '(${TextNormalizer.toPersianDigits(checks.length.toString())})',
              style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (checks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'موردی ثبت نشده است.',
              style: AppTypography.bodySmall.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          )
        else
          ...checks.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCheckRow(context, c, showActions, tone),
            ),
          ),
      ],
    );
  }

  Widget _buildCheckRow(
    BuildContext context,
    CheckEntity check,
    bool showActions,
    AppStatusTone tone,
  ) {
    final isReceived = check.type == CheckType.received;

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'چک ${TextNormalizer.auto(check.checkNumber)} — ${check.bankName}',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isReceived ? "از" : "به"} ${check.partyName} • سررسید: ${AppDateFormatter.formatShort(check.dueDate, locale: 'fa')}',
                      style: AppTypography.bodySmall.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppMoneyText(
                    money: check.amount,
                    style: AppTypography.moneyTile.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppStatusBadge(
                    label: check.status.titleFa,
                    icon: switch (check.status) {
                      CheckStatus.pending => Icons.schedule_rounded,
                      CheckStatus.cleared => Icons.check_rounded,
                      CheckStatus.bounced => Icons.close_rounded,
                      CheckStatus.cancelled => Icons.block_rounded,
                      CheckStatus.transferred => Icons.swap_horiz_rounded,
                    },
                    tone: tone,
                  ),
                ],
              ),
            ],
          ),
          if (showActions && check.status == CheckStatus.pending) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.read<CheckBloc>().add(
                    CheckStatusUpdated(
                      id: check.id,
                      status: CheckStatus.cleared,
                    ),
                  ),
                  child: const Text('پاس شد'),
                ),
                TextButton(
                  onPressed: () => context.read<CheckBloc>().add(
                    CheckStatusUpdated(
                      id: check.id,
                      status: CheckStatus.transferred,
                    ),
                  ),
                  child: const Text('واگذار شد'),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF5C6C),
                  ),
                  onPressed: () => context.read<CheckBloc>().add(
                    CheckStatusUpdated(
                      id: check.id,
                      status: CheckStatus.bounced,
                    ),
                  ),
                  child: const Text('برگشت'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReconcileSkeleton extends StatelessWidget {
  const _ReconcileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: const [
        AppSkeleton(
          height: 150,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        SizedBox(height: 16),
        AppSkeleton(
          height: 84,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        SizedBox(height: 10),
        AppSkeleton(
          height: 84,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ],
    );
  }
}
