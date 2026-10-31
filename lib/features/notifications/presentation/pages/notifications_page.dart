import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../domain/entities/app_notification_entity.dart';
import '../../domain/services/notification_service.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

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
          final items = snapshot.data ?? [];

          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'هیچ اعلانی وجود ندارد',
              description: 'یادآورهای سررسید چک، اقساط، بدهی‌ها و هشدارهای بودجه در این بخش نمایش داده می‌شوند.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final notif = items[index];
              return AppCard(
                onTap: () {
                  if (!notif.isRead) {
                    notifService.markAsRead(notif.id);
                  }
                },
                backgroundColor: notif.isRead
                    ? (isDark ? AppColors.darkSurface : AppColors.lightSurface)
                    : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTypeIcon(notif.type),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  notif.title,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                                      ),
                                ),
                                if (!notif.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif.body,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDate(notif.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(NotificationType type) {
    final (icon, color) = switch (type) {
      NotificationType.checkDue => (Icons.fact_check_outlined, Colors.amber),
      NotificationType.installmentDue => (Icons.calendar_month_outlined, AppColors.expense),
      NotificationType.debtDue => (Icons.handshake_outlined, AppColors.primary),
      NotificationType.lowStock => (Icons.inventory_2_outlined, Colors.orange),
      NotificationType.budgetAlert => (Icons.warning_amber_rounded, AppColors.expense),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
