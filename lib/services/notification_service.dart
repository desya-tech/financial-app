import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const int _noonId = 1001;
  static const int _eveningId = 1002;

  Future<void> init() async {
    // Notifications are not supported on web
    if (kIsWeb) return;

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(initSettings);
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return false;
  }

  Future<void> scheduleDailyNotifications() async {
    if (kIsWeb) return;

    await _cancelAll();

    // Jakarta timezone (WIB = UTC+7)
    final jakarta = tz.getLocation('Asia/Jakarta');

    // Schedule 12:00 WIB
    await _scheduleDailyAt(
      id: _noonId,
      title: '🍽️ Pengingat Pengeluaran Siang',
      body: 'Sudah catat pengeluaran makan siangmu hari ini? Yuk update sekarang!',
      hour: 12,
      minute: 0,
      location: jakarta,
    );

    // Schedule 21:00 WIB
    await _scheduleDailyAt(
      id: _eveningId,
      title: '📊 Rekap Pengeluaran Malam',
      body: 'Sebelum tidur, catat semua pengeluaran hari ini agar catatanmu lengkap!',
      hour: 21,
      minute: 0,
      location: jakarta,
    );
  }

  Future<void> _scheduleDailyAt({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required tz.Location location,
  }) async {
    final now = tz.TZDateTime.now(location);
    var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);

    // If the time has already passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Pengingat Harian',
      channelDescription: 'Notifikasi pengingat untuk mencatat pengeluaran harian',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _cancelAll() async {
    await _plugin.cancel(_noonId);
    await _plugin.cancel(_eveningId);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  /// Send an immediate test notification to verify it works
  Future<void> sendTestNotification() async {
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Pengingat Harian',
      channelDescription: 'Notifikasi pengingat untuk mencatat pengeluaran harian',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _plugin.show(
      9999,
      '✅ Notifikasi Aktif!',
      'Notifikasi jam 12:00 & 21:00 sudah dijadwalkan setiap hari.',
      const NotificationDetails(android: androidDetails),
    );
  }
}
