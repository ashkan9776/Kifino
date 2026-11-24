import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../checks/presentation/bloc/check_bloc.dart';
import '../../../debts/presentation/bloc/debt_bloc.dart';
import '../../../installments/presentation/bloc/installment_bloc.dart';
import '../../../recurring/presentation/cubit/recurring_cubit.dart';
import '../../domain/upcoming.dart';

/// «پیش رو»: bills, installments, checks and debts due in the next two
/// weeks, overdue first. Hidden when nothing is coming.
class UpcomingSection extends StatelessWidget {
  const UpcomingSection({super.key});

  static const _maxShown = 4;

  @override
  Widget build(BuildContext context) {
    final recurring = context.watch<RecurringCubit>().state.rules;
    final installments = switch (context.watch<InstallmentBloc>().state) {
      final InstallmentLoaded s => s.installments,
      _ => const [],
    };
    final checks = switch (context.watch<CheckBloc>().state) {
      final CheckLoaded s => s.checks,
      _ => const [],
    };
    final debts = switch (context.watch<DebtBloc>().state) {
      final DebtLoaded s => s.debts,
      _ => const [],
    };

    final items = buildUpcoming(
      now: DateTime.now(),
      recurring: recurring,
      installments: [...installments],
      checks: [...checks],
      debts: [...debts],
    );

    final isPersian = context.l10n.isPersian;
    if (items.isEmpty) {
      return recurring.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _RecurringPromo(isPersian: isPersian),
            )
          : const SizedBox.shrink();
    }

    final shown = items.take(_maxShown).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: isPersian ? 'پیش رو' : 'Coming up',
            actionLabel: isPersian ? 'تکراری‌ها' : 'Recurring',
            onAction: () => context.push('/recurring'),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (final (i, item) in shown.indexed) ...[
                  if (i > 0) const Divider(indent: 70),
                  _UpcomingTile(item: item),
                ],
                if (items.length > shown.length)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 2),
                    child: Text(
                      isPersian
                          ? TextNormalizer.auto(
                              '+ ${items.length - shown.length} مورد دیگر',
                            )
                          : '+ ${items.length - shown.length} more',
                      style: AppTypography.labelMedium.copyWith(
                        color: context.customColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final UpcomingItem item;

  const _UpcomingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final icon = switch (item.kind) {
      UpcomingKind.recurring => Icons.event_repeat_rounded,
      UpcomingKind.installment => Icons.calendar_month_outlined,
      UpcomingKind.check => Icons.fact_check_outlined,
      UpcomingKind.debt || UpcomingKind.receivable => Icons.handshake_outlined,
    };
    final color = item.overdue
        ? colors.expense
        : item.incoming
        ? colors.income
        : (isDark ? AppColors.debtOrangeDark : AppColors.debtOrangeLight);
    final when = item.overdue
        ? 'سررسید گذشته · ${AppDateFormatter.formatDue(item.date)}'
        : AppDateFormatter.formatDue(item.date);

    return InkWell(
      onTap: () => context.push(item.route),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            AppIconBadge(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    when,
                    style: AppTypography.bodySmall.copyWith(
                      color: item.overdue
                          ? colors.expense
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppMoneyText(
                  money: item.amount,
                  style: AppTypography.moneyTile.copyWith(
                    color: item.incoming ? colors.income : colors.textPrimary,
                  ),
                  usePersianDigits: true,
                ),
                if (item.needsConfirmation)
                  TextButton(
                    onPressed: () =>
                        context.read<RecurringCubit>().postNow(item.id),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('پرداخت شد'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown once, until the first recurring rule exists: explains the feature
/// in one line instead of an empty section.
class _RecurringPromo extends StatelessWidget {
  final bool isPersian;

  const _RecurringPromo({required this.isPersian});

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final primary = Theme.of(context).colorScheme.primary;
    return AppCard(
      onTap: () => context.push('/recurring'),
      child: Row(
        children: [
          AppIconBadge(icon: Icons.event_repeat_rounded, color: primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPersian
                      ? 'اجاره، حقوق و قبض‌ها را یک بار ثبت کن'
                      : 'Set up rent, salary and bills once',
                  style: AppTypography.titleSmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPersian
                      ? 'هر ماه خودکار ثبت یا یادآوری می‌شوند.'
                      : 'Kifino posts or reminds them every month.',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: primary),
        ],
      ),
    );
  }
}
