import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

part 'notification_service.g.dart';

/// The evening "log your day" reminder — the one local notification this app
/// schedules. A single fixed id because there is only ever one of it;
/// rescheduling means cancel-then-recreate, not a growing set of ids.
const _reminderNotificationId = 1;

/// Wraps `flutter_local_notifications` for the one thing this app needs: a
/// daily reminder at a user-chosen time. Deliberately not `firebase_messaging`
/// — that's for server-sent pushes, and a client-scheduled daily local alert
/// doesn't need a round trip through Firebase to fire.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_fixedOffsetZoneName()));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _initialized = true;
  }

  /// A fixed-UTC-offset zone matching the device's *current* offset —
  /// same simplification `core/utils/currency.dart`'s `currentUtcOffsetLabel`
  /// already makes, to avoid a platform-channel package just to resolve a
  /// real IANA zone name. Doesn't track DST; the reminder can drift an hour
  /// across a DST transition until the app is next opened, which is an
  /// acceptable trade for a personal-finance reminder.
  ///
  /// `Etc/GMT` zones invert the sign by POSIX convention: UTC+3 is
  /// `Etc/GMT-3`, not `Etc/GMT+3`.
  String _fixedOffsetZoneName() {
    final hours = DateTime.now().timeZoneOffset.inHours;
    if (hours == 0) return 'Etc/GMT';
    final sign = hours > 0 ? '-' : '+';
    return 'Etc/GMT$sign${hours.abs()}';
  }

  Future<bool> requestPermission() async {
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (granted ?? true) && (iosGranted ?? true);
  }

  Future<void> scheduleDaily({required int hour, required int minute}) async {
    await init();
    await _plugin.zonedSchedule(
      id: _reminderNotificationId,
      title: 'Log today',
      body: 'Add anything you spent today before it slips your mind.',
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_reminder',
          'Evening reminder',
          channelDescription: 'A daily nudge to log the day\'s spending.',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Repeats daily at the same wall-clock time — not "every 24 hours",
      // which would drift across a DST transition.
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel() async {
    await init();
    await _plugin.cancel(id: _reminderNotificationId);
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => NotificationService();
