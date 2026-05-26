/// Notification Service
///
/// Handles Firebase Cloud Messaging (FCM) notifications including
/// permission requests, token management, and message handling.
/// Uses singleton pattern.
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permissions
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('NotificationService: Permission granted');

      // Initialize local notifications
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await _localNotifications.initialize(initSettings);

      // Get and save FCM token
      await _sendTokenToBackend();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((_) => _sendTokenToBackend());

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      _isInitialized = true;
    } else {
      debugPrint('NotificationService: Permission denied');
    }
  }

  /// Refresh and re-send the FCM token
  Future<void> refreshToken() async {
    await _sendTokenToBackend();
  }

  /// Handle foreground messages by showing a local notification
  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      showLocalNotification(
        notification.title ?? '',
        notification.body ?? '',
      );
    }
  }

  /// Save the FCM token to the profiles table
  Future<void> _sendTokenToBackend() async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token}).eq('id', userId);

      debugPrint('NotificationService: FCM token saved');
    } catch (e) {
      debugPrint('NotificationService: Failed to save FCM token: $e');
    }
  }

  /// Show a local notification
  Future<void> showLocalNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'canteen_pay_default',
      'CanteenPay Notifications',
      channelDescription: 'Default notification channel for CanteenPay',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
