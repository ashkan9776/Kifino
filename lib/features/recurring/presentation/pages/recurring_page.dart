import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/design_system/tokens/colors.dart';
import '../../../../core/design_system/tokens/radii.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_money_text.dart';
import '../../../../core/widgets/app_responsive_container.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/recurring_rule_entity.dart';
import '../cubit/recurring_cubit.dart';
import 'recurring_editor_page.dart';

/// «تراکنش‌های تکراری» — rent, salary, subscriptions and bills that repeat.
class RecurringPage extends StatelessWidget {
  const RecurringPage({super.key});

  static const templates = [
    ('اجاره خانه', TransactionType.expense, Icons.home_work_outlined),
    ('حقوق', TransactionType.income, Icons.work_outline_rounded),
    ('اینترنت', TransactionType.expense, Icons.wifi_rounded),
    ('قبض موبایل', TransactionType.expense, Icons.phone_iphone_rounded),
    ('اشتراک', TransactionType.expense, Icons.subscriptions_outlined),
    ('پس‌انداز ماهانه', TransactionType.transfer, Icons.savings_outlined),
  ];

  static void openEditor(
    BuildContext context, [
    RecurringEditorArgs args = const RecurringEditorArgs(),
  ]) {
    context.push('/recurring/edit', extra: args);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecurringCubit, RecurringState>(
      listenWhen: (a, b) => b.message != null && a.message != b.message,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(state.message!)));
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: const Text('تراکنش‌های تکراری')),
          floatingActionButton: state.rules.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => openEditor(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('مورد جدید'),
                ),
          body: AppResponsiveContainer.feed(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      96,
                    ),
                    children: [
                      _SummaryCard(state: state),
                      const SizedBox(height: AppSpacing.lg),
                      if (state.rules.isEmpty)
                        const _Templates()
                      else ...[
                        if (state.active.isNotEmpty) ...[
                          AppSectionHeader(
                            title: TextNormalizer.auto(
                              'فعال (${state.active.length})',
                            ),
                          ),
                          _RuleList(rules: state.active),
                        ],
                        if (state.paused.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          const AppSectionHeader(title: 'متوقف یا پایان‌یافته'),
                          _RuleList(rules: state.paused),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        const _Templates(compact: true),
                      ],
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final RecurringState state;

  const _SummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final next = state.active.isEmpty ? null : state.active.first;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: isDark ? KifinoPalette.heroDark : KifinoPalette.heroLight,
        borderRadius: BorderRadius.circular(KifinoRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تعهدات ثابت ماهانه',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.onInkSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppMoneyText(
            money: state.monthlyCommitments,
            style: AppTypography.moneyHeadline.copyWith(color: AppColors.onInk),
            usePersianDigits: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'درآمد ثابت ماهانه',
                  child: AppMoneyText(
                    money: state.monthlyIncome,
                    style: AppTypography.moneySub.copyWith(
                      color: AppColors.incomeDark,
                    ),
                    usePersianDigits: true,
                  ),
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white12),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _HeroStat(
                  label: 'نوبت بعدی',
                  child: Text(
                    next == null
                        ? '—'
                        : '${next.title} · ${AppDateFormatter.formatDue(next.nextRunDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.onInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final Widget child;

  const _HeroStat({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onInkSecondary,
          ),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );
  }
}

class _RuleList extends StatelessWidget {
  final List<RecurringRuleEntity> rules;

  const _RuleList({required this.rules});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (final (i, rule) in rules.indexed) ...[
            if (i > 0) const Divider(indent: 70),
            RecurringRuleTile(rule: rule),
          ],
        ],
      ),
    );
  }
}

/// One rule: what, how often, when next, how much — with actions.
class RecurringRuleTile extends StatelessWidget {
  final RecurringRuleEntity rule;

  const RecurringRuleTile({super.key, required this.rule});

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    final color = switch (rule.type) {
      TransactionType.income => colors.income,
      TransactionType.transfer => colors.transfer,
      _ => colors.expense,
    };
    final icon = switch (rule.type) {
      TransactionType.income => Icons.south_west_rounded,
      TransactionType.transfer => Icons.swap_horiz_rounded,
      _ => Icons.event_repeat_rounded,
    };
    final now = DateTime.now();
    final overdue = rule.isActive && !rule.isFinished && rule.isDue(now);
    final status = !rule.isActive
        ? 'متوقف'
        : rule.isFinished
        ? 'پایان‌یافته'
        : overdue
        ? (rule.autoPost ? 'در صف ثبت' : 'سررسید گذشته — منتظر تأیید')
        : AppDateFormatter.formatDue(rule.nextRunDate);

    return InkWell(
      onTap: () =>
          RecurringPage.openEditor(context, RecurringEditorArgs(rule: rule)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            AppIconBadge(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(
                      color: rule.isActive
                          ? colors.textPrimary
                          : colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${rule.scheduleLabelFa}  ·  $status',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: overdue && !rule.autoPost
                          ? colors.warning
                          : colors.textSecondary,
                    ),
                  ),
                  if (rule.lastError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        rule.lastError!,
                        maxLines: 2,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.expense,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AppMoneyText(
              money: rule.amount,
              style: AppTypography.moneyTile.copyWith(
                color: colors.textPrimary,
              ),
              usePersianDigits: true,
            ),
            _RuleMenu(rule: rule),
          ],
        ),
      ),
    );
  }
}

class _RuleMenu extends StatelessWidget {
  final RecurringRuleEntity rule;

  const _RuleMenu({required this.rule});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RecurringCubit>();
    final canPost = rule.isActive && !rule.isFinished;
    return PopupMenuButton<String>(
      tooltip: 'گزینه‌ها',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) async {
        switch (action) {
          case 'post':
            await cubit.postNow(rule.id);
          case 'skip':
            await cubit.skip(rule.id);
          case 'pause':
            await cubit.setActive(rule.id, false);
          case 'resume':
            await cubit.setActive(rule.id, true);
          case 'edit':
            if (context.mounted) {
              RecurringPage.openEditor(
                context,
                RecurringEditorArgs(rule: rule),
              );
            }
          case 'delete':
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('حذف تراکنش تکراری؟'),
                content: const Text(
                  'تراکنش‌هایی که قبلاً ثبت شده‌اند باقی می‌مانند؛ فقط نوبت‌های بعدی ساخته نمی‌شوند.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('انصراف'),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.customColors.expense,
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('حذف'),
                  ),
                ],
              ),
            );
            if (ok == true) await cubit.delete(rule.id);
        }
      },
      itemBuilder: (_) => [
        if (canPost)
          PopupMenuItem(
            value: 'post',
            child: Text(rule.autoPost ? 'ثبت همین حالا' : 'پرداخت شد — ثبت کن'),
          ),
        if (canPost)
          const PopupMenuItem(value: 'skip', child: Text('رد کردن این نوبت')),
        PopupMenuItem(
          value: rule.isActive ? 'pause' : 'resume',
          child: Text(rule.isActive ? 'توقف موقت' : 'ادامه'),
        ),
        const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
        const PopupMenuItem(value: 'delete', child: Text('حذف')),
      ],
    );
  }
}

class _Templates extends StatelessWidget {
  final bool compact;

  const _Templates({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.customColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Text(
            'پرداخت‌ها و درآمدهای تکراری را یک بار ثبت کنید',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'کیفینو هر نوبت را سر موعد ثبت می‌کند یا یادآوری می‌دهد، و در داشبورد نشان می‌دهد چه چیزی پیش روست.',
            style: AppTypography.bodyMedium.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ] else
          const AppSectionHeader(title: 'افزودن سریع'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final (title, type, icon) in RecurringPage.templates)
              ActionChip(
                avatar: Icon(icon, size: 18),
                label: Text(title),
                onPressed: () => RecurringPage.openEditor(
                  context,
                  RecurringEditorArgs(templateTitle: title, templateType: type),
                ),
              ),
            if (!compact)
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: const Text('مورد دلخواه'),
                onPressed: () => RecurringPage.openEditor(context),
              ),
          ],
        ),
      ],
    );
  }
}
