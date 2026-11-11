import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_test/flutter_test.dart';
import 'package:kifino/core/database/app_database.dart';
import 'package:kifino/core/utils/money.dart';
import 'package:kifino/features/installments/data/repositories/installment_repository_impl.dart';
import 'package:kifino/features/installments/domain/entities/installment_entity.dart';
import 'package:kifino/features/installments/presentation/bloc/installment_bloc.dart';
import 'package:kifino/features/notifications/domain/entities/app_notification_entity.dart';
import 'package:kifino/features/notifications/domain/services/notification_service.dart';

class FakeLocalNotificationsPlugin extends Fake
    implements FlutterLocalNotificationsPlugin {
  bool initialized = false;
  int zonedScheduleCallCount = 0;
  int? lastScheduledId;
  String? lastScheduledTitle;
  String? lastScheduledBody;
  final List<int> cancelledIds = [];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
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
    lastScheduledId = id;
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
    service = NotificationService(
      db: db,
      localNotifications: fakeNotifications,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('NotificationService Tests', () {
    test('init initializes local notifications plugin', () async {
      await service.init();
      expect(fakeNotifications.initialized, isTrue);
    });

    test(
      'scheduleNotification saves notification and shows system notification',
      () async {
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
        expect(
          fakeNotifications.lastScheduledBody,
          equals('قسط شماره ۲ به مبلغ ۵,۰۰۰,۰۰۰ ریال'),
        );

        // Check database persistence
        final notifications = await service.watchNotifications().first;
        expect(notifications.length, equals(1));
        final notif = notifications.first;
        expect(notif.title, equals('سررسید قسط وام'));
        expect(notif.type, equals(NotificationType.installmentDue));
        expect(notif.referenceId, equals('inst-123'));
        expect(notif.isRead, isFalse);
      },
    );

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

    test('scheduleNotification uses numericIdFor(referenceId) and cancelScheduled cancels exact OS id & clears unread rows', () async {
      final scheduledDate = DateTime.now().add(const Duration(days: 5));
      await service.scheduleNotification(
        title: 'قسط مسکن',
        body: 'موعد قسط مسکن',
        type: NotificationType.installmentDue,
        referenceId: 'inst-ref-99',
        scheduledFor: scheduledDate,
      );

      final expectedOsId = NotificationService.numericIdFor('inst-ref-99');
      expect(fakeNotifications.lastScheduledId, equals(expectedOsId));

      await service.cancelScheduled('inst-ref-99');
      expect(fakeNotifications.cancelledIds, contains(expectedOsId));
      final remaining = await service.watchNotifications().first;
      expect(remaining.where((n) => n.referenceId == 'inst-ref-99'), isEmpty);
    });

    test('InstallmentBloc reschedules reminder on pay and cancels when completed or paid remaining', () async {
      final repo = InstallmentRepositoryImpl(db);
      final bloc = InstallmentBloc(repo, service);
      addTearDown(bloc.close);

      final now = DateTime.now();
      await db.into(db.accountsTable).insert(
            AccountsTableCompanion.insert(
              id: 'acc-n',
              name: 'بانک',
              type: 'bankCard',
              currency: 'TOMAN',
              createdAt: now.millisecondsSinceEpoch,
              updatedAt: now.millisecondsSinceEpoch,
            ),
          );

      final inst = InstallmentEntity(
        id: 'inst-noti',
        title: 'وام آزمایشی',
        accountId: 'acc-n',
        totalAmount: const Money(minorUnits: 300000, currency: Currency.toman),
        numberOfInstallments: 3,
        installmentAmount:
            const Money(minorUnits: 100000, currency: Currency.toman),
        startDate: now,
        nextDueDate: now.add(const Duration(days: 10)),
        createdAt: now,
        updatedAt: now,
      );
      bloc.add(InstallmentCreateSubmitted(inst));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(fakeNotifications.zonedScheduleCallCount, equals(1));

      // Pay 1st of 3 -> reschedules for updated nextDueDate (+30 days)
      bloc.add(const InstallmentPaySubmitted('inst-noti'));
      await Future.delayed(const Duration(milliseconds: 80));
      expect(fakeNotifications.zonedScheduleCallCount, equals(2));

      // Settle remaining -> cancels OS notification
      bloc.add(const InstallmentPayRemainingSubmitted('inst-noti'));
      await Future.delayed(const Duration(milliseconds: 80));
      expect(
        fakeNotifications.cancelledIds,
        contains(NotificationService.numericIdFor('inst-noti')),
      );
    });

    test('AndroidManifest declares RECEIVE_BOOT_COMPLETED and notification receivers', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
      expect(
        manifest,
        contains('com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver'),
      );
      expect(
        manifest,
        contains('com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver'),
      );
    });
  });
}
