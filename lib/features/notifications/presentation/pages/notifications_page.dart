import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../../domain/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final notifService = sl<NotificationService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('اعلان‌ها و یادآورها'),
            actions: [
              IconButton(
                icon: const Icon(Icons.done_all_rounded),
                tooltip: 'خواندن همه',
                onPressed: () => notifService.markAllAsRead(),
              ),
            ],
          ),
          body: StreamBuilder<List<AppNotificationEntity>>(
            stream: notifService.watchNotifications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: const [
                    AppSkeleton(height: 80),
                    SizedBox(height: AppSpacing.sm),
                    AppSkeleton(height: 80),
                    SizedBox(height: AppSpacing.sm),
                    AppSkeleton(height: 80),
                  ],
                );
              }

              final all = snapshot.data ?? const <AppNotificationEntity>[];
              final unreadCount = all.where((n) => !n.isRead).length;
              final items = _unreadOnly
                  ? all.where((n) => !n.isRead).toList()
                  : all;

              if (items.isEmpty) {
                return _unreadOnly && all.isNotEmpty
                    ? _allReadState(isDark)
                    : const AppEmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'هیچ اعلانی وجود ندارد',
                        description: 'یادآورهای سررسید چک، اقساط، بدهی‌ها و هشدارهای بودجه در این بخش نمایش داده می‌شوند.',
                      );
              }

              final groups = _groupByAge(items);

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Unread counter / filter row
                  Row(
                    children: [
                      _CountChip(
                        label: TextNormalizer.auto('$unreadCount خوانده‌نشده'),
                        color: unreadCount > 0
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.darkSubtext
                                  : AppColors.lightSubtext),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _CountChip(
                        label: TextNormalizer.auto('$all.length کل'),
                        color: isDark
                            ? AppColors.darkSubtext
                            : AppColors.lightSubtext,
                      ),
                      const Spacer(),
                      if (all.isNotEmpty)
                        ActionChip(
                          label: Text(
                            _unreadOnly ? 'نمایش همه' : 'فقط خوانده‌نشده',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () =>
                              setState(() => _unreadOnly = !_unreadOnly),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  for (final group in groups.entries)
                    if (group.value.isNotEmpty) ...[
                      _SectionHeader(label: group.key),
                      const SizedBox(height: AppSpacing.sm),
                      ...group.value.map(
                        (notif) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Dismissible(
                            key: ValueKey(notif.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: AlignmentDirectional.centerEnd,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.expense,
                                borderRadius: AppSpacing.borderRadiusMd,
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) =>
                                notifService.deleteNotification(notif.id),
                            child: _NotificationCard(
                              notif: notif,
                              onTap: () {
                                if (!notif.isRead) {
                                  notifService.markAsRead(notif.id);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _allReadState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.incomeDark : AppColors.incomeLight)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.task_alt_rounded,
                size: 36,
                color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('همه خوانده شده ✓', style: AppTypography.titleMedium),
          ],
        ),
      ),
    );
  }

  /// Groups notifications into امروز / دیروز / قدیمی‌تر (order matters).
  Map<String, List<AppNotificationEntity>> _groupByAge(
    List<AppNotificationEntity> items,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<AppNotificationEntity>>{
      'امروز': [],
      'دیروز': [],
      'قدیمی‌تر': [],
    };

    for (final n in items) {
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      if (d == today) {
        groups['امروز']!.add(n);
      } else if (d == yesterday) {
        groups['دیروز']!.add(n);
      } else {
        groups['قدیمی‌تر']!.add(n);
      }
    }
    return groups;
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
      child: Text(
        label,
        style: AppTypography.labelLarge.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final Color color;

  const _CountChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppSpacing.borderRadiusPill,
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotificationEntity notif;
  final VoidCallback onTap;

  const _NotificationCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (icon, color) = _typeVisual(notif.type, isDark);

    return AppCard(
      onTap: onTap,
      backgroundColor: notif.isRead
          ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
          : (isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.lightSurfaceVariant),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: notif.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsetsDirectional.only(start: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    style: AppTypography.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.darkSubtext
                          : AppColors.lightSubtext,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    TextNormalizer.auto(
                      AppDateFormatter.formatRelative(
                        notif.createdAt,
                        locale: 'fa',
                      ),
                    ),
                    style: AppTypography.labelMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (IconData, Color) _typeVisual(NotificationType type, bool isDark) {
    switch (type) {
      case NotificationType.checkDue:
        return (
          Icons.fact_check_rounded,
          isDark ? AppColors.debtOrangeDark : AppColors.debtOrangeLight,
        );
      case NotificationType.installmentDue:
        return (
          Icons.calendar_month_rounded,
          isDark ? AppColors.expenseDark : AppColors.expenseLight,
        );
      case NotificationType.debtDue:
        return (
          Icons.handshake_rounded,
          isDark ? AppColors.transferDark : AppColors.transferLight,
        );
      case NotificationType.lowStock:
        return (Icons.inventory_2_rounded, AppColors.warning);
      case NotificationType.budgetAlert:
        return (
          Icons.warning_amber_rounded,
          isDark ? AppColors.expenseDark : AppColors.expenseLight,
        );
    }
  }
}
