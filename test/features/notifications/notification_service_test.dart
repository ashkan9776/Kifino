import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/features/notifications/domain/entities/app_notification_entity.dart';
import 'package:kifino/features/notifications/domain/services/notification_service.dart';

class FakeLocalNotificationsPlugin extends Fake implements FlutterLocalNotificationsPlugin {
  bool initialized = false;
  int zonedScheduleCallCount = 0;
  String? lastScheduledTitle;
  String? lastScheduledBody;
  final List<int> cancelledIds = [];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async {
    initialized = true;
    return true;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    zonedScheduleCallCount++;
    lastScheduledTitle = title;
    lastScheduledBody = body;
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelledIds.add(id);
  }
}

void main() {
  late AppDatabase db;
  late FakeLocalNotificationsPlugin fakeNotifications;
  late NotificationService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fakeNotifications = FakeLocalNotificationsPlugin();
    service = NotificationService(db: db, localNotifications: fakeNotifications);
  });

  tearDown(() async {
    await db.close();
  });

  group('NotificationService Tests', () {
    test('init initializes local notifications plugin', () async {
      await service.init();
      expect(fakeNotifications.initialized, isTrue);
    });

    test('scheduleNotification saves notification and shows system notification', () async {
      final scheduledDate = DateTime.now().add(const Duration(days: 3));

      await service.scheduleNotification(
        title: 'سررسید قسط وام',
        body: 'قسط شماره ۲ به مبلغ ۵,۰۰۰,۰۰۰ ریال',
        type: NotificationType.installmentDue,
        referenceId: 'inst-123',
        scheduledFor: scheduledDate,
      );

      // Future date → OS-level scheduled reminder (zonedSchedule)
      expect(fakeNotifications.zonedScheduleCallCount, equals(1));
      expect(fakeNotifications.lastScheduledTitle, equals('سررسید قسط وام'));
      expect(fakeNotifications.lastScheduledBody, equals('قسط شماره ۲ به مبلغ ۵,۰۰۰,۰۰۰ ریال'));

      // Check database persistence
      final notifications = await service.watchNotifications().first;
      expect(notifications.length, equals(1));
      final notif = notifications.first;
      expect(notif.title, equals('سررسید قسط وام'));
      expect(notif.type, equals(NotificationType.installmentDue));
      expect(notif.referenceId, equals('inst-123'));
      expect(notif.isRead, isFalse);
    });

    test('markAsRead updates notification state to read', () async {
      await service.scheduleNotification(
        title: 'یادآور چک',
        body: 'چک صیادی شماره ۹۸۷۶۵۴ فردا سررسید می‌شود',
        type: NotificationType.checkDue,
        scheduledFor: DateTime.now().add(const Duration(days: 1)),
      );

      final initialList = await service.watchNotifications().first;
      expect(initialList.first.isRead, isFalse);

      final notifId = initialList.first.id;
      await service.markAsRead(notifId);

      final updatedList = await service.watchNotifications().first;
      expect(updatedList.first.isRead, isTrue);
    });

    test('markAllAsRead updates all unread notifications to read', () async {
      await service.scheduleNotification(
        title: 'هشدار بودجه',
        body: '۸۵ درصد از بودجه خوراک مصرف شده است',
        type: NotificationType.budgetAlert,
        scheduledFor: DateTime.now(),
      );

      await service.scheduleNotification(
        title: 'طلب معوق',
        body: 'موعد دریافت طلب از آقای حسینی فرا رسیده است',
        type: NotificationType.debtDue,
        scheduledFor: DateTime.now(),
      );

      final initialList = await service.watchNotifications().first;
      expect(initialList.length, equals(2));
      expect(initialList.every((n) => !n.isRead), isTrue);

      await service.markAllAsRead();

      final updatedList = await service.watchNotifications().first;
      expect(updatedList.length, equals(2));
      expect(updatedList.every((n) => n.isRead), isTrue);
    });
  });
}
