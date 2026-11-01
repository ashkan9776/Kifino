import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/localization/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/installment_entity.dart';
import '../bloc/installment_bloc.dart';

/// Phase 3 rework — payment history of one installment (newest first).
/// Each row can be deleted to correct a wrong payment: money returns to the
/// linked account, the ledger row is reverted and the paid counter recomputes
/// (repository-side).
class InstallmentHistorySheet extends StatefulWidget {
  final InstallmentEntity installment;

  const InstallmentHistorySheet({super.key, required this.installment});

  /// Convenience opener; restores the plain loaded state after the sheet is
  /// dismissed by any route (swipe, back, close button).
  static Future<void> show(
    BuildContext context,
    InstallmentEntity installment,
  ) {
    final bloc = context.read<InstallmentBloc>();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InstallmentHistorySheet(installment: installment),
    ).whenComplete(() => bloc.add(const InstallmentHistoryClosed()));
  }

  @override
  State<InstallmentHistorySheet> createState() =>
      _InstallmentHistorySheetState();
}

class _InstallmentHistorySheetState extends State<InstallmentHistorySheet> {
  @override
  void initState() {
    super.initState();
    context.read<InstallmentBloc>().add(
      InstallmentHistoryRequested(widget.installment.id),
    );
  }

  Future<void> _confirmDelete(
    BuildContext sheetContext,
    String paymentId,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.isPersian ? 'حذف پرداخت' : 'Delete payment'),
        content: Text(
          l10n.isPersian
              ? 'حذف این پرداخت؟ پول به حساب برمی‌گردد و قسط مجدد سررسید می‌شود.'
              : 'Delete this payment? The money returns to the account and the installment becomes due again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              l10n.delete,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<InstallmentBloc>().add(
        InstallmentPaymentDeleted(
          paymentId,
          installmentId: widget.installment.id,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = context.l10n;
    final isFa = l10n.isPersian;
    final inst = widget.installment;

    return AppBottomSheet(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(
              title: isFa ? 'تاریخچه پرداخت‌ها' : 'Payment History',
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${inst.title} — ${TextNormalizer.auto('${inst.paidInstallmentsCount} از ${inst.numberOfInstallments}')} قسط',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: BlocBuilder<InstallmentBloc, InstallmentState>(
                builder: (context, state) {
                  if (state is InstallmentHistoryLoaded &&
                      state.installmentId == inst.id) {
                    final history = state.history;

                    if (history.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xl,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 40,
                              color: isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              isFa
                                  ? 'هنوز پرداختی ثبت نشده است'
                                  : 'No payments recorded yet',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppColors.darkSubtext
                                    : AppColors.lightSubtext,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: history.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final payment = history[index];
                        final money = Money.fromMinor(
                          payment.amountMinor,
                          inst.totalAmount.currency,
                        );

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (isDark
                                        ? AppColors.darkSurface
                                        : AppColors.lightSurfaceVariant)
                                    .withValues(alpha: 0.55),
                            borderRadius: AppSpacing.borderRadiusSm,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.income.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: AppColors.income,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${isFa ? 'قسط' : 'Installment'} ${TextNormalizer.auto('${payment.installmentIndex}')}',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    Text(
                                      AppDateFormatter.format(
                                        payment.paidAt,
                                        locale: l10n.localeName,
                                      ),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: isDark
                                                ? AppColors.darkSubtext
                                                : AppColors.lightSubtext,
                                          ),
                                    ),
                                    if (payment.notes != null &&
                                        payment.notes!.isNotEmpty)
                                      Text(
                                        payment.notes!,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: isDark
                                                  ? AppColors.darkSubtext
                                                  : AppColors.lightSubtext,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              AppMoneyText(
                                money: money,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.income,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                ),
                                color: AppColors.danger,
                                tooltip: l10n.isPersian
                                    ? 'حذف پرداخت'
                                    : 'Delete payment',
                                onPressed: () =>
                                    _confirmDelete(context, payment.id),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  if (state is InstallmentFailure) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xl,
                      ),
                      child: Text(
                        '${isFa ? 'خطا' : 'Error'}: ${state.message}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.danger,
                        ),
                      ),
                    );
                  }

                  // Loading — skeleton rows while the history is fetched.
                  return const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppSkeleton(
                        height: 56,
                        borderRadius: AppSpacing.borderRadiusSm,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      AppSkeleton(
                        height: 56,
                        borderRadius: AppSpacing.borderRadiusSm,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      AppSkeleton(
                        height: 56,
                        borderRadius: AppSpacing.borderRadiusSm,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
