import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../utils/money.dart';
import '../../widgets/app_amount_field.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_money_text.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/app_transaction_tile.dart';
import '../../../features/transactions/domain/entities/transaction_entity.dart';
import '../components/financial/app_metric_card.dart';
import '../components/financial/app_status_badge.dart';
import '../tokens/colors.dart';

/// Living component catalog — internal design/developer reference at
/// `/design-system`. Documents every token and component in light & dark.
class DesignSystemShowcasePage extends StatelessWidget {
  const DesignSystemShowcasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _section(context, 'Colors — Brand Palette', _colorsSection),
          _section(context, 'Colors — Financial Semantics', _semanticSection),
          _section(context, 'Typography', _typographySection),
          _section(context, 'Buttons', _buttonsSection),
          _section(context, 'Inputs', _inputsSection),
          _section(context, 'Financial Components', _financialSection),
          _section(context, 'Status Badges', _badgesSection),
          _section(context, 'Feedback & States', _feedbackSection),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, WidgetBuilder builder) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: builder(context),
          ),
        ],
      ),
    );
  }

  // ── Sections ─────────────────────────────────────────────────────────────

  static Widget _colorsSection(BuildContext context) {
    final swatches = <(String, Color)>[
      ('Navy 950', KifinoPalette.navy950),
      ('Navy 900', KifinoPalette.navy900),
      ('Electric', KifinoPalette.blue600),
      ('Bright', KifinoPalette.blue500),
      ('Cyan', KifinoPalette.cyan500),
      ('Mint', KifinoPalette.mint400),
      ('Emerald', KifinoPalette.emerald500),
      ('Purple', KifinoPalette.purple400),
      ('Orange', KifinoPalette.orange400),
      ('Yellow', KifinoPalette.yellow400),
      ('Error', KifinoPalette.error),
      ('Warning', KifinoPalette.warning),
      ('Info', KifinoPalette.info),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (name, color) in swatches)
              Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(name, style: AppTypography.labelMedium),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: KifinoPalette.heroLight,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            'Brand Gradient — Navy → Electric → Cyan',
            style: AppTypography.labelLarge.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }

  static Widget _semanticSection(BuildContext context) {
    final rows = <(String, Color, IconData)>[
      ('درآمد / Income', AppColors.income, Icons.arrow_downward_rounded),
      ('هزینه / Expense', AppColors.expense, Icons.arrow_upward_rounded),
      ('انتقال / Transfer', AppColors.transferLight, Icons.swap_horiz_rounded),
      ('بدهی / Debt', AppColors.debtOrangeLight, Icons.handshake_rounded),
      ('طلب / Receivable', AppColors.receivableLight, Icons.schedule_rounded),
      ('دارایی / Asset', AppColors.assetLight, Icons.savings_rounded),
      ('موفق / Success', AppColors.warning, Icons.check_circle_rounded),
      ('اطلاع / Info', AppColors.info, Icons.info_outline_rounded),
    ];
    return Column(
      children: [
        for (final (label, color, icon) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(label, style: AppTypography.bodyMedium)),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _typographySection(BuildContext context) {
    final rows = <(String, TextStyle)>[
      ('Display 28/B', AppTypography.displayLarge),
      ('Display 23/B', AppTypography.displayMedium),
      ('Title 18/SB', AppTypography.titleLarge),
      ('Title 15/SB', AppTypography.titleMedium),
      ('Body 14/R', AppTypography.bodyLarge),
      ('Body 12.5/R', AppTypography.bodyMedium),
      ('Label 12/M', AppTypography.labelLarge),
      ('Money 25/B', AppTypography.moneyHeadline),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, style) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('کیفینو ۱۲۳ Kifino', style: style),
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _buttonsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(label: 'Primary — ثبت هزینه', onPressed: () {}),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Secondary',
          variant: AppButtonVariant.secondary,
          onPressed: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Outline',
          variant: AppButtonVariant.outline,
          onPressed: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Danger — حذف',
          variant: AppButtonVariant.danger,
          onPressed: () {},
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppButton(
          label: 'Loading — در حال ثبت…',
          isLoading: true,
          onPressed: null,
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppButton(label: 'Disabled', onPressed: null),
        // Disabled state: onPressed == null
      ],
    );
  }

  static Widget _inputsSection(BuildContext context) {
    return Column(
      children: [
        AppAmountField(
          currency: Currency.toman,
          autoFocus: false,
          onAmountMinorChanged: (_) {},
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Input — 52h / radius 14',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (_) {},
        ),
      ],
    );
  }

  static Widget _financialSection(BuildContext context) {
    final fixture = TransactionEntity(
      id: 'demo',
      accountId: 'demo',
      amount: Money.fromMinor(850000, Currency.toman),
      type: TransactionType.expense,
      date: DateTime.now(),
      description: 'رستوران',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppMetricCard(
                label: 'درآمد',
                value: Money.fromMinor(12500000, Currency.toman),
                icon: Icons.trending_up_rounded,
                color: AppColors.income,
                sign: MoneyDisplaySign.positiveNegative,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppMetricCard(
                label: 'هزینه',
                value: Money.fromMinor(4200000, Currency.toman),
                icon: Icons.trending_down_rounded,
                color: AppColors.expense,
                sign: MoneyDisplaySign.negativeOnly,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppMoneyText(
          money: Money.fromMinor(248500000, Currency.toman),
          style: AppTypography.moneyHeadline,
          animated: true,
        ),
        Text(
          'Compact: ${Money.fromMinor(248500000, Currency.toman).formatCompact()}',
          style: AppTypography.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTransactionTile(transaction: fixture),
      ],
    );
  }

  static Widget _badgesSection(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: const [
        AppStatusBadge(
          label: 'پرداخت شد',
          icon: Icons.check_rounded,
          tone: AppStatusTone.success,
        ),
        AppStatusBadge(
          label: 'در انتظار',
          icon: Icons.schedule_rounded,
          tone: AppStatusTone.warning,
        ),
        AppStatusBadge(
          label: 'معوق',
          icon: Icons.error_outline_rounded,
          tone: AppStatusTone.danger,
        ),
        AppStatusBadge(
          label: 'همگام شد',
          icon: Icons.cloud_done_rounded,
          tone: AppStatusTone.info,
        ),
        AppStatusBadge(
          label: 'پیش‌نویس',
          icon: Icons.edit_note_rounded,
          tone: AppStatusTone.neutral,
        ),
      ],
    );
  }

  static Widget _feedbackSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSkeleton(height: 40),
        const SizedBox(height: AppSpacing.md),
        const AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'حالت خالی',
          description: 'آیکن + عنوان + توضیح + دکمه‌ی اصلی',
        ),
      ],
    );
  }
}
