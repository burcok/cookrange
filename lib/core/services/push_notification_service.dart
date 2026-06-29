import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../utils/app_routes.dart';

/// Background message handler — MUST be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('PushNotificationService: background message: ${message.messageId}');
}

/// Sets up Firebase Cloud Messaging for push notifications.
/// Stores the FCM token in Firestore so the Cloud Functions can target the user.
///
/// Tap routing:
///   - [setNavigatorKey] must be called once (from SplashScreen) before any
///     notification tap can be routed.
///   - [drainPendingNavigation] must be called after the app has navigated to
///     /main so the navigator stack is ready for the cold-start case.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  GlobalKey<NavigatorState>? _navigatorKey;
  RemoteMessage? _pendingInitialMessage;

  /// Guards one-time timezone-database initialization (required before any
  /// [FlutterLocalNotificationsPlugin.zonedSchedule] call).
  bool _tzInitialized = false;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'cookrange_default',
    'Cookrange Notifications',
    description: 'General app notifications',
    importance: Importance.high,
  );

  /// Provide the app's navigator key so tap events can trigger navigation.
  /// Call this once during app initialization (alongside DeepLinkService.init).
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Call once during app initialization.
  Future<void> initialize() async {
    // Load the timezone database + resolve the device's local zone so exact,
    // clock-anchored reminders (zonedSchedule) fire at the right local time.
    await _configureLocalTimeZone();

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Permission is requested via PermissionService.requestNotifications() after
    // a branded rationale primer — NOT here during silent app startup.

    // Set up local notifications (for foreground display)
    const androidInit =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Create the Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background (opened from background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Cold-start: app was terminated, user tapped notification → store for drain
    _pendingInitialMessage = await FirebaseMessaging.instance
        .getInitialMessage()
        .timeout(const Duration(seconds: 5), onTimeout: () => null);

    // Store token and listen for refresh
    await _saveToken();
    _fcm.onTokenRefresh.listen(_saveTokenString);
  }

  /// Call this after the app has navigated to /main so the navigator stack is
  /// ready. Routes any notification tap that arrived during a cold start.
  void drainPendingNavigation() {
    if (_pendingInitialMessage == null) return;
    final msg = _pendingInitialMessage!;
    _pendingInitialMessage = null;
    // Small delay lets the main screen finish its first build before we push
    // an additional route on top.
    Future.delayed(const Duration(milliseconds: 800), () {
      _navigateFromData(msg.data);
    });
  }

  /// Request FCM notification permission. Called by [PermissionService] after
  /// the branded rationale primer has been shown to the user.
  Future<void> requestPermission() async {
    final settings = await _fcm.requestPermission();
    debugPrint(
        'PushNotificationService: permission status: ${settings.authorizationStatus}');
    await _saveToken();
  }

  // Contiguous id block reserved for the daily water reminders. Several
  // reminders are scheduled across the user's waking window; this block lets us
  // cancel/reschedule the whole set atomically. (Legacy single reminder used the
  // base id 7001, so [cancelWaterReminder] also clears it.)
  static const int _waterReminderIdBase = 7001;
  static const int _waterReminderMaxCount = 12; // ids 7001..7012

  /// Loads the IANA timezone database and pins `tz.local` to the device's zone.
  /// Idempotent; safe to call repeatedly. Falls back to UTC on any failure so
  /// scheduling still works (times are then interpreted in UTC).
  Future<void> _configureLocalTimeZone() async {
    if (_tzInitialized) return;
    try {
      tzdata.initializeTimeZones();
    } catch (e) {
      debugPrint('PushNotificationService: initializeTimeZones failed: $e');
    }
    var timeZoneName = 'UTC';
    try {
      timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (e) {
      debugPrint(
          'PushNotificationService: getLocalTimezone failed, using UTC: $e');
    }
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint(
          'PushNotificationService: unknown zone "$timeZoneName", using UTC: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }
    _tzInitialized = true;
    debugPrint('PushNotificationService: tz local = ${tz.local.name}');
  }

  /// Schedules several daily hydration reminders at precise local clock times,
  /// evenly spread across the user's waking window ([wakeTime]–[sleepTime], each
  /// "HH:mm"). Each reminder repeats daily ([DateTimeComponents.time]).
  ///
  /// Uses inexact alarms ([AndroidScheduleMode.inexactAllowWhileIdle]) so it does
  /// NOT require the Android 13+ exact-alarm permission — minute-level precision
  /// is unnecessary for a hydration nudge and inexact batching saves battery.
  /// Any previously scheduled reminders (incl. the legacy single one) are
  /// cancelled first so re-scheduling is idempotent.
  Future<void> scheduleDailyWaterReminder({
    required String title,
    required String body,
    String wakeTime = '08:00',
    String sleepTime = '23:00',
    int? count,
  }) async {
    try {
      await _configureLocalTimeZone();
      await cancelWaterReminder();

      final times = spreadReminderTimes(wakeTime, sleepTime, count);
      if (times.isEmpty) return;

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
        ),
        iOS: const DarwinNotificationDetails(),
      );

      for (var i = 0; i < times.length; i++) {
        await _localNotifications.zonedSchedule(
          _waterReminderIdBase + i,
          title,
          body,
          _nextInstanceOfTime(times[i].$1, times[i].$2),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
      debugPrint(
          'scheduleDailyWaterReminder: ${times.length} reminders ($wakeTime–$sleepTime)');
    } catch (e) {
      debugPrint('scheduleDailyWaterReminder failed: $e');
    }
  }

  /// Cancels every daily hydration reminder in the reserved id block (and the
  /// legacy single reminder). Called when the user disables/edits it in settings.
  Future<void> cancelWaterReminder() async {
    try {
      for (var i = 0; i < _waterReminderMaxCount; i++) {
        await _localNotifications.cancel(_waterReminderIdBase + i);
      }
    } catch (e) {
      debugPrint('cancelWaterReminder failed: $e');
    }
  }

  /// The next future [tz.TZDateTime] matching [hour]:[minute] in the local zone.
  /// If today's slot has already passed, rolls to tomorrow.
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Distributes reminder times evenly across the waking window. Returns a list
  /// of (hour, minute) pairs. Handles windows that cross midnight (e.g. a night
  /// shift: wake 22:00, sleep 06:00). The last reminder lands one segment before
  /// [sleep] so the user is never pinged at bedtime. Duplicates are dropped.
  ///
  /// Pure + deterministic (no plugin/Firebase/tz access) so it is unit-tested
  /// directly — see test/water_reminder_schedule_test.dart.
  @visibleForTesting
  static List<(int, int)> spreadReminderTimes(
      String wake, String sleep, int? count) {
    final wakeMin = _parseMinutes(wake) ?? 8 * 60;
    var sleepMin = _parseMinutes(sleep) ?? 23 * 60;
    if (sleepMin <= wakeMin) sleepMin += 24 * 60; // window crosses midnight
    final window = sleepMin - wakeMin;
    if (window <= 0) return [(wakeMin ~/ 60, wakeMin % 60)];

    // ~one reminder every 2.5h, clamped to a sane range.
    final n =
        (count ?? (window / 150).round()).clamp(2, _waterReminderMaxCount);

    final seen = <int>{};
    final result = <(int, int)>[];
    for (var i = 0; i < n; i++) {
      final m = (wakeMin + (window * i ~/ n)) % (24 * 60);
      if (seen.add(m)) result.add((m ~/ 60, m % 60));
    }
    return result;
  }

  /// Parses an "HH:mm" string to minutes-since-midnight, or null if malformed.
  static int? _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('PushNotificationService: tap from background: ${message.data}');
    _navigateFromData(message.data);
  }

  /// Routes the user to the appropriate screen based on notification type.
  ///
  /// chat  → /chat_list (user sees the conversation with new message at top)
  /// other → /main      (home screen; notification feed accessible from there)
  void _navigateFromData(Map<String, dynamic> data) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      debugPrint(
          'PushNotificationService: navigator not ready, dropping tap routing');
      return;
    }

    final type = data['type'] as String? ?? '';

    if (type == 'chat') {
      nav.pushNamed(AppRoutes.chatList);
    } else {
      nav.pushNamedAndRemoveUntil(AppRoutes.main, (r) => false);
    }

    debugPrint('PushNotificationService: routed notification type=$type');
  }

  Future<void> _saveToken() async {
    try {
      final token = await _fcm
          .getToken()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (token != null) await _saveTokenString(token);
    } catch (e) {
      debugPrint('PushNotificationService: error getting token: $e');
    }
  }

  Future<void> _saveTokenString(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // Upsert (merge) — the FCM token can be saved on app init / token refresh
      // before the user doc exists (sign-up race), so update() would throw
      // [cloud_firestore/not-found]. merge is safe whether or not it exists.
      await _db.collection('users').doc(uid).set({
        'fcm_token': token,
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PushNotificationService: error saving token: $e');
    }
  }

  /// Call on sign-out to clear the stored token.
  Future<void> clearToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _fcm.deleteToken();
      await _db.collection('users').doc(uid).update({
        'fcm_token': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('PushNotificationService: error clearing token: $e');
    }
  }
}
