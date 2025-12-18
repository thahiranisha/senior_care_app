import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications wrapper.
///
/// - Android/iOS/macOS: supported.
/// - Web: no-op (keeps the app compiling/running on Flutter Web).
///
/// Singleton because scheduling/canceling relies on one plugin instance.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  /// Initialize notifications + timezone.
  Future<void> init() async {
    if (kIsWeb || _initialized) return;

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Colombo'));
    } catch (_) {
      // ignore
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Ask runtime permissions.
  Future<void> requestPermissions() async {
    if (kIsWeb) return;

    if (_isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }

    if (_isMacOS) {
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      await mac?.requestPermissions(alert: true, badge: true, sound: true);
      return;
    }

    if (_isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;

      // Best-effort: depends on plugin version
      try {
        await (android as dynamic).requestNotificationsPermission();
      } catch (_) {}

      try {
        await (android as dynamic).requestExactAlarmsPermission();
      } catch (_) {}
    }
  }

  NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'medication_reminders',
      'Medication Reminders',
      channelDescription: 'Medication reminders for seniors',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _plugin.show(id, title, body, _details(), payload: payload);
  }

  Future<void> scheduleOnce({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    String? payload,
  }) async {
    if (kIsWeb) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime firstOccurrence,
    String? payload,
  }) async {
    if (kIsWeb) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      firstOccurrence,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelMany(List<int> ids) async {
    if (kIsWeb) return;
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }
}
