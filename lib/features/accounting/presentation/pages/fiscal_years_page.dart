import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/design_system/components/financial/app_status_badge.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/fiscal_year_entity.dart';
import '../bloc/fiscal_year_cubit.dart';

/// Fiscal year management: status of every year, closing the active year with
/// its closing/next/opening voucher flow, and defining the next year.
class FiscalYearsPage extends StatelessWidget {
  const FiscalYearsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FiscalYearCubit>(
      create: (_) => sl<FiscalYearCubit>()..load(),
      child: const _FiscalYearsView(),
    );
  }
}

class _FiscalYearsView extends StatelessWidget {
  const _FiscalYearsView();

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;

    return Scaffold(
      appBar: AppBar(title: const Text('سال‌های مالی'), centerTitle: true),
      body: BlocConsumer<FiscalYearCubit, FiscalYearState>(
        listener: (context, state) {
          if (state is FiscalYearLoaded && state.message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message!),
                backgroundColor: state.messageIsError
                    ? colors.expense
                    : colors.income,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is FiscalYearLoading) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: List.generate(
                3,
                (index) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: AppSkeleton(height: 120),
                ),
              ),
            );
          }

          if (state is FiscalYearError) {
            return AppEmptyState(
              icon: Icons.error_outline,
              title: 'خطا در دریافت سال‌های مالی',
              description: state.message,
              actionLabel: 'تلاش مجدد',
              onAction: () => context.read<FiscalYearCubit>().load(),
            );
          }

          if (state is FiscalYearLoaded) {
            if (state.years.isEmpty) {
              return AppEmptyState(
                icon: Icons.calendar_month_outlined,
                title: 'سال مالی تعریف نشده است',
                description: 'برای شروع ثبت اسناد حسابداری، اولین سال مالی را با دکمه پایین صفحه تعریف کنید.',
                actionLabel: 'تعریف اولین سال مالی',
                onAction: () =>
                    context.read<FiscalYearCubit>().createNextYear(),
              );
            }

            final sorted = [...state.years]
              ..sort((a, b) => b.yearNumber.compareTo(a.yearNumber));
            final latestNumber = sorted.first.yearNumber;

            return RefreshIndicator(
              onRefresh: () async => context.read<FiscalYearCubit>().load(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: sorted.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final year = sorted[index];
                  return _YearCard(
                    year: year,
                    isLatest: year.yearNumber == latestNumber,
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _YearCard extends StatelessWidget {
  final FiscalYearEntity year;
  final bool isLatest;

  const _YearCard({required this.year, required this.isLatest});

  void _confirmClose(BuildContext context) {
    final cubit = context.read<FiscalYearCubit>();
    final colors = context.customColors;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('بستن سال مالی'),
        content: Text(
          'با بستن «${year.title}»:\n'
          '• سند اختتامیه ترازشده برای تسویه حساب‌های موقت صادر و تأیید می‌شود.\n'
          '• سال مالی بعد به‌همراه سند افتتاحیه آن ساخته و فعال می‌شود.\n'
          '• ثبت، ویرایش یا حذف سند در این دوره برای همیشه قفل می‌شود.',
          style: AppTypography.bodyMedium.copyWith(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colors.expense),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.closeYear(year.id);
            },
            child: const Text('بستن سال مالی'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final isBusy = context.select<FiscalYearCubit, bool>(
      (cubit) =>
          cubit.state is FiscalYearLoaded &&
          (cubit.state as FiscalYearLoaded).isBusy,
    );
    final startJ = JalaliDate.fromDateTime(year.startDate);
    final endJ = JalaliDate.fromDateTime(year.endDate);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (year.isClosed ? colors.textSecondary : colors.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  year.isClosed ? Icons.lock_outline : Icons.calendar_month,
                  color: year.isClosed ? colors.textSecondary : colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(year.title, style: AppTypography.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'سال شماره ${TextNormalizer.auto(year.yearNumber.toString())} • '
                      '${startJ.formatFull()} تا ${endJ.formatFull()}',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusBadge(
                label: year.isClosed ? 'بسته‌شده' : 'فعال',
                icon: year.isClosed ? Icons.lock : Icons.check_circle,
                tone: year.isClosed
                    ? AppStatusTone.neutral
                    : AppStatusTone.success,
              ),
            ],
          ),
          if (year.openingDocumentId != null ||
              year.closingDocumentId != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (year.openingDocumentId != null)
                  _VoucherBadge(label: 'سند افتتاحیه ✓', color: colors.info),
                if (year.closingDocumentId != null)
                  _VoucherBadge(label: 'سند اختتامیه ✓', color: colors.warning),
              ],
            ),
          ],
          if (!year.isClosed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (year.isActive) ...[
                  Expanded(
                    child: AppButton(
                      label: 'بستن سال مالی',
                      icon: const Icon(Icons.lock_outline, size: 18),
                      variant: AppButtonVariant.outline,
                      onPressed: isBusy ? null : () => _confirmClose(context),
                      isLoading: isBusy,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (isLatest) ...[
                  Expanded(
                    child: AppButton(
                      label: 'تعریف سال بعد',
                      icon: const Icon(Icons.add, size: 18),
                      variant: AppButtonVariant.secondary,
                      onPressed: isBusy
                          ? null
                          : () => context
                                .read<FiscalYearCubit>()
                                .createNextYear(),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VoucherBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _VoucherBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
