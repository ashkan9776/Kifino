import '../../../../core/utils/app_logger.dart';

import 'package:drift/drift.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../entities/app_notification_entity.dart';

/// Local reminder service: due-date reminders for installments, checks
/// and debts. Persisted in the audit table AND scheduled in the OS so they
/// fire at the right time even if the app is closed.
class NotificationService {
  final AppDatabase db;
  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _tzInitialized = false;

  NotificationService({
    required this.db,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    try {
      // Some hosts never answer the plugin channel (e.g. widget tests) — a
      // hard timeout keeps startup from hanging forever.
      await _localNotifications
          .initialize(settings: initSettings)
          .timeout(const Duration(seconds: 3));
      await _requestAndroidPermission();
      _initTimezone();
    } catch (_) {
      // Graceful fallback on non-supported platforms or test environments
    }
  }

  /// Android 13+ requires the runtime POST_NOTIFICATIONS grant — the manifest
  /// permission alone is not enough.
  Future<void> requestPermissions() async {
    try {
      await _requestAndroidPermission();
    } catch (e, st) {
      AppLogger.warning(
        'Notification permission request failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _requestAndroidPermission() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  /// Resolves an IANA location matching the device offset. Primary market is
  /// Iran (Asia/Tehran, +03:30) — hard-coded first; otherwise scan the
  /// bundled tz database for an offset match; never invent a rate... er, zone.
  void _initTimezone() {
    if (_tzInitialized) return;
    tzdata.initializeTimeZones();
    final target = DateTime.now().timeZoneOffset;
    String? best;
    const preferred = ['Asia/Tehran', 'Asia/Dubai', 'Europe/Istanbul', 'UTC'];
    for (final name in preferred) {
      if (tz.timeZoneDatabase.locations.containsKey(name) &&
          tz.TZDateTime.now(tz.getLocation(name)).timeZoneOffset == target) {
        best = name;
        break;
      }
    }
    best ??= () {
      for (final name in tz.timeZoneDatabase.locations.keys) {
        try {
          if (tz.TZDateTime.now(tz.getLocation(name)).timeZoneOffset ==
              target) {
            return name;
          }
        } catch (_) {}
      }
      return 'UTC';
    }();
    tz.setLocalLocation(tz.getLocation(best));
    _tzInitialized = true;
  }

  /// Deterministic OS-notification id derived from the stable entity id so
  /// reschedules replace and deletes can cancel precisely.
  static int numericIdFor(String entityId) {
    var h = 0;
    for (final code in entityId.codeUnits) {
      h = (h * 31 + code) & 0x7fffffff;
    }
    return h == 0 ? 1 : h;
  }

  /// Schedules a due-date reminder at [scheduledFor]. Past dates are stored
  /// (audit trail) but not scheduled in the OS.
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? referenceId,
    required DateTime scheduledFor,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();

    if (referenceId != null && scheduledFor.isAfter(now)) {
      await (db.delete(db.notificationsTable)..where(
            (t) =>
                t.referenceId.equals(referenceId) &
                t.isRead.equals(false) &
                t.scheduledFor.isBiggerThanValue(now.millisecondsSinceEpoch),
          ))
          .go();
    }

    // 1. Persist in database (audit + in-app notification center)
    await db
        .into(db.notificationsTable)
        .insertOnConflictUpdate(
          NotificationsTableCompanion.insert(
            id: id,
            title: title,
            body: body,
            type: type.code,
            referenceId: Value(referenceId),
            scheduledFor: scheduledFor.millisecondsSinceEpoch,
            createdAt: now.millisecondsSinceEpoch,
          ),
        );

    if (!scheduledFor.isAfter(now)) return;

    // 2. Schedule in the OS at the actual due date/time
    _initTimeZonesSafely();
    final androidDetails = AndroidNotificationDetails(
      'kifino_reminders',
      'یادآورهای مالی کیفینو',
      channelDescription: 'هشدارهای سررسید اقساط، چک‌ها و مطالبات',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final osNotificationId = numericIdFor(referenceId ?? id);

    try {
      await _localNotifications.zonedSchedule(
        id: osNotificationId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledFor, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Scheduling can fail on exotic platforms — the in-app notification
      // record above still exists.
    }
  }

  /// Cancels a previously scheduled OS reminder (e.g. after deletion) and clears
  /// pending unread audit rows linked to [entityId].
  Future<void> cancelScheduled(String entityId) async {
    try {
      await (db.delete(db.notificationsTable)..where(
            (t) => t.referenceId.equals(entityId) & t.isRead.equals(false),
          ))
          .go();
      _initTimeZonesSafely();
      await _localNotifications.cancel(id: numericIdFor(entityId));
    } catch (e, st) {
      AppLogger.warning(
        'Cancelling scheduled notification failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _initTimeZonesSafely() {
    try {
      _initTimezone();
    } catch (e, st) {
      AppLogger.warning(
        'Time zone initialisation failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Stream<List<AppNotificationEntity>> watchNotifications() {
    final query = db.select(db.notificationsTable)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);

    return query.watch().map((rows) {
      return rows.map((r) {
        return AppNotificationEntity(
          id: r.id,
          title: r.title,
          body: r.body,
          type: NotificationType.fromCode(r.type),
          referenceId: r.referenceId,
          scheduledFor: DateTime.fromMillisecondsSinceEpoch(r.scheduledFor),
          isRead: r.isRead,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAt),
        );
      }).toList();
    });
  }

  Future<void> markAsRead(String id) async {
    await (db.update(db.notificationsTable)..where((t) => t.id.equals(id)))
        .write(const NotificationsTableCompanion(isRead: Value(true)));
  }

  /// Removes one notification row and cancels its OS reminder if pending.
  Future<void> deleteNotification(String id) async {
    final row = await (db.select(
      db.notificationsTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    await (db.delete(
      db.notificationsTable,
    )..where((t) => t.id.equals(id))).go();
    try {
      await _localNotifications.cancel(
        id: numericIdFor(row?.referenceId ?? id),
      );
    } catch (e, st) {
      AppLogger.warning(
        'Cancelling OS notification failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> markAllAsRead() async {
    await db
        .update(db.notificationsTable)
        .write(const NotificationsTableCompanion(isRead: Value(true)));
  }
}
