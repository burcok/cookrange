import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      await _db.collection('users').doc(uid).update({
        'fcm_token': token,
        'fcm_token_updated_at': FieldValue.serverTimestamp(),
      });
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
