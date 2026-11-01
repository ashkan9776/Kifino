import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/sync_operation_entity.dart';
import '../../domain/repositories/sync_repository.dart';
import '../bloc/sync_bloc.dart';
import '../bloc/sync_event.dart';
import '../bloc/sync_state.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  Future<List<SyncOperationEntity>>? _pendingPreview;

  @override
  void initState() {
    super.initState();
    _refreshPreview();
  }

  void _refreshPreview() {
    setState(() {
      _pendingPreview = sl<SyncRepository>()
          .getPendingOperations(limit: 100)
          .then((result) => result.dataOrNull ?? const <SyncOperationEntity>[]);
    });
  }

  Future<void> _confirmClearQueue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک‌کردن کل صف همگام‌سازی؟'),
        content: const Text(
          'همه‌ی عملیات در صف (از جمله مواردی که هنوز ارسال نشده‌اند) حذف می‌شوند. داده‌های ذخیره‌شده روی گوشی دست‌نخورده می‌مانند، اما تا وقتی دوباره ثبت شوند به سرور ابری نمی‌رسند.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('پاک کردن'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<SyncBloc>().add(const SyncClearQueueTriggered());
      _refreshPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtext = isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('همگام‌سازی ابری (به‌زودی)'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'همگام‌سازی مجدد',
                onPressed: () {
                  context.read<SyncBloc>().add(
                    const SyncTriggered(isManual: true),
                  );
                  _refreshPreview();
                },
              ),
            ],
          ),
          body: BlocConsumer<SyncBloc, SyncState>(
            listener: (context, state) {
              // Refresh the queue preview after any sync cycle settles.
              if (!state.isSyncing) _refreshPreview();
            },
            builder: (context, state) {
              final online = state.isOnline;

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // 1. Connection status hero
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _StatusDot(
                              color: state.isSyncing
                                  ? AppColors.transferLight
                                  : (online
                                        ? AppColors.income
                                        : AppColors.debtOrangeLight),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.isSyncing
                                        ? 'در حال همگام‌سازی…'
                                        : (online ? 'متصل' : 'آفلاین'),
                                    style: AppTypography.titleMedium.copyWith(
                                      color: state.isSyncing
                                          ? AppColors.transferLight
                                          : (online
                                                ? AppColors.income
                                                : AppColors.debtOrangeLight),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    state.isSyncing
                                        ? 'صف عملیات در حال ارسال است'
                                        : (online
                                              ? 'تغییرات جدید به‌صورت خودکار همگام می‌شوند'
                                              : 'تغییرات محفوظ است و با برقراری اینترنت خودکار ارسال می‌شود'),
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: subtext,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // 2. Stat tiles with prominent Persian numbers
                        Row(
                          children: [
                            Expanded(
                              child: _StatTile(
                                label: 'در انتظار ارسال',
                                value: state.pendingCount,
                                icon: Icons.outbox_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: _StatTile(
                                label: 'ناموفق',
                                value: state.failedCount,
                                icon: Icons.error_outline_rounded,
                                color: state.failedCount > 0
                                    ? AppColors.expense
                                    : AppColors.income,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Last successful sync with full Jalali date + time
                        if (state.lastSyncTime != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                size: 16,
                                color: subtext,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                TextNormalizer.auto(
                                  'آخرین همگام‌سازی: ${AppDateFormatter.formatShort(state.lastSyncTime!, locale: 'fa')} ساعت ${_formatClock(state.lastSyncTime!)}'
                                  '${state.lastSyncCount > 0 ? ' (${state.lastSyncCount} مورد)' : ''}',
                                ),
                                style: AppTypography.labelMedium.copyWith(
                                  color: subtext,
                                ),
                              ),
                            ],
                          ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'خطای آخرین اجرا: ${state.errorMessage}',
                            textAlign: TextAlign.center,
                            style: AppTypography.labelMedium.copyWith(
                              color: AppColors.expense,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        AppButton(
                          label: state.isSyncing
                              ? 'در حال ارسال…'
                              : 'همگام‌سازی اکنون',
                          icon: const Icon(Icons.cloud_sync_outlined, size: 20),
                          isLoading: state.isSyncing,
                          onPressed: state.isSyncing
                              ? null
                              : () {
                                  context.read<SyncBloc>().add(
                                    const SyncTriggered(isManual: true),
                                  );
                                },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          TextNormalizer.auto(
                            'همگام‌سازی خودکار: هنگام اتصال اینترنت و هر ${AppConstants.defaultSyncIntervalMinutes} دقیقه',
                          ),
                          textAlign: TextAlign.center,
                          style: AppTypography.labelMedium.copyWith(
                            color: subtext,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 3. Queue composition (what is waiting to be sent)
                  if (state.pendingCount > 0) ...[
                    Text('محتوای صف ارسال', style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    FutureBuilder<List<SyncOperationEntity>>(
                      future: _pendingPreview,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        final grouped = <String, int>{};
                        for (final op in snapshot.data!) {
                          grouped[op.syncEntityName] =
                              (grouped[op.syncEntityName] ?? 0) + 1;
                        }
                        if (grouped.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return AppCard(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              for (final entry in grouped.entries)
                                Chip(
                                  avatar: Icon(
                                    Icons.sync_rounded,
                                    size: 16,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  label: Text(
                                    TextNormalizer.auto(
                                      '${_entityLabelFa(entry.key)} × ${entry.value}',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // 4. Failed operations
                  if (state.failedOperations.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          TextNormalizer.auto(
                            'عملیات ناموفق (${state.failedOperations.length})',
                          ),
                          style: AppTypography.titleMedium,
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: const Text('تلاش مجدد همه'),
                          onPressed: state.isSyncing
                              ? null
                              : () {
                                  context.read<SyncBloc>().add(
                                    const SyncRetryFailedTriggered(),
                                  );
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...state.failedOperations.map((op) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.expense.withValues(
                                alpha: 0.15,
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.expense,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              '${_entityLabelFa(op.syncEntityName)} — ${_operationLabelFa(op.operation)}',
                              style: AppTypography.labelLarge,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                TextNormalizer.auto(
                                  'خطا: ${op.lastError ?? "نامشخص"} — تلاش شماره ${op.retryCount}',
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMedium.copyWith(
                                  color: subtext,
                                ),
                              ),
                            ),
                            isThreeLine: true,
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'پاک‌کردن کل صف',
                      variant: AppButtonVariant.outline,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                      onPressed: state.isSyncing ? null : _confirmClearQueue,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // 5. Offline-first explainer
                  AppCard(
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.lightSurfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'معماری اول-آفلاین (Offline-First)',
                                  style: AppTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'کیفینو کاملاً آفلاین و محلی روی گوشی شما کار می‌کند. زیرساخت همگام‌سازی ابری و دسترسی چنددستگاهی در حال توسعه است و به‌زودی در نسخه‌های آینده با راه‌اندازی سرور اختصاصی فعال خواهد شد. تا آن زمان هیچ داده‌ای به بیرون از دستگاه ارسال نمی‌شود.',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: subtext,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _formatClock(DateTime dt) {
    return TextNormalizer.auto(
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
    );
  }

  static String _entityLabelFa(String entityName) {
    switch (entityName) {
      case 'transactions':
        return 'تراکنش‌ها';
      case 'accounts':
        return 'حساب‌ها';
      case 'categories':
        return 'دسته‌ها';
      case 'budgets':
        return 'بودجه‌ها';
      case 'debts_receivables':
        return 'بدهی‌ها';
      case 'installments':
        return 'اقساط';
      case 'checks':
        return 'چک‌ها';
      case 'assets':
        return 'دارایی‌ها';
      case 'financial_goals':
        return 'اهداف مالی';
      case 'invoices':
        return 'فاکتورها';
      case 'products':
        return 'محصولات';
      case 'business_contacts':
        return 'مشتریان';
      default:
        return entityName;
    }
  }

  static String _operationLabelFa(SyncOperationType operation) {
    switch (operation) {
      case SyncOperationType.insert:
        return 'ثبت جدید';
      case SyncOperationType.update:
        return 'ویرایش';
      case SyncOperationType.delete:
        return 'حذف';
    }
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;

  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  TextNormalizer.auto('$value'),
                  style: AppTypography.displayMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontFeatures: AppTypography.tabularFigures,
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
