/// Notification Service
///
/// Production-grade FCM push notification handling with local notification
/// display, token lifecycle management, and tap-to-navigate support.
/// Follows singleton pattern. All methods wrapped in try-catch so the app
/// never crashes if Firebase is not configured.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'device_id_service.dart';
import 'notification_storage_service.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();

  /// Singleton accessor.
  static NotificationService get instance => _instance;

  // ---------------------------------------------------------------------------
  // Fields
  // ---------------------------------------------------------------------------

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _firebaseMessaging;

  /// Lazy access to FirebaseMessaging — returns null if Firebase not configured.
  FirebaseMessaging? get _messaging {
    if (_firebaseMessaging != null) return _firebaseMessaging;
    try {
      _firebaseMessaging = FirebaseMessaging.instance;
      return _firebaseMessaging;
    } catch (_) {
      return null;
    }
  }

  String? _fcmToken;
  bool _initialized = false;

  /// Lock to prevent concurrent token refreshes.
  Completer<void>? _fcmRefreshLock;

  /// Callback the host app sets so notification taps can trigger navigation.
  Function(Map<String, dynamic>)? onNotificationTapped;

  // Stream controllers
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream emitted whenever a new notification arrives (for badge updates).
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  // Subscriptions for cleanup
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  StreamSubscription<String>? _onTokenRefreshSubscription;

  String? get fcmToken => _fcmToken;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 1. Request notification permissions
      await _requestPermissions();

      // 2. Create Android notification channel
      if (Platform.isAndroid) {
        await _createAndroidNotificationChannel();
      }

      // 3. Initialize local notifications plugin
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );

      // 4. Disable iOS automatic foreground presentation
      // We show local notifications manually to avoid duplicates
      await _messaging?.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      // 5. Get FCM token and send to backend
      await _setupFCMToken();

      // 6. Listen for foreground messages
      _onMessageSubscription?.cancel();
      _onMessageSubscription =
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 7. Listen for background tap (app was in background)
      _onMessageOpenedAppSubscription?.cancel();
      _onMessageOpenedAppSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint(
              'NotificationService: onMessageOpenedApp - ${message.notification?.title}');
        }
        if (message.notification != null) {
          NotificationStorageService.saveNotification(
            title: message.notification!.title ?? 'Notification',
            body: message.notification!.body ?? '',
            data: message.data,
          );
        }
        _handleNotificationTap(message.data);
      });

      // 8. Check for terminated-state tap (cold start)
      final initialMessage = await _messaging?.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          debugPrint(
              'NotificationService: getInitialMessage - ${initialMessage.notification?.title}');
        }
        if (initialMessage.notification != null) {
          await NotificationStorageService.saveNotification(
            title: initialMessage.notification!.title ?? 'Notification',
            body: initialMessage.notification!.body ?? '',
            data: initialMessage.data,
          );
          _notificationController.add({'type': 'new_notification'});
        }
        _handleNotificationTap(initialMessage.data);
      }

      // 9. Listen for token rotation
      _onTokenRefreshSubscription?.cancel();
      _onTokenRefreshSubscription =
          _messaging?.onTokenRefresh.listen((String newToken) {
        if (kDebugMode) {
          debugPrint('NotificationService: token refreshed');
        }
        _fcmToken = newToken;
        _sendTokenToBackend(newToken);
      });

      _initialized = true;
      if (kDebugMode) {
        debugPrint('NotificationService: initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: initialization failed: $e');
      }
      // Don't rethrow — app must not crash if Firebase isn't configured.
    }
  }

  // ---------------------------------------------------------------------------
  // Permission request
  // ---------------------------------------------------------------------------

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isIOS) {
        await _messaging
            ?.requestPermission(
              alert: true,
              announcement: false,
              badge: true,
              carPlay: false,
              criticalAlert: false,
              provisional: true,
              sound: true,
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => const NotificationSettings(
                authorizationStatus: AuthorizationStatus.notDetermined,
                alert: AppleNotificationSetting.notSupported,
                badge: AppleNotificationSetting.notSupported,
                sound: AppleNotificationSetting.notSupported,
                carPlay: AppleNotificationSetting.notSupported,
                lockScreen: AppleNotificationSetting.notSupported,
                notificationCenter: AppleNotificationSetting.notSupported,
                showPreviews: AppleShowPreviewSetting.notSupported,
                criticalAlert: AppleNotificationSetting.notSupported,
                announcement: AppleNotificationSetting.notSupported,
                timeSensitive: AppleNotificationSetting.notSupported,
                providesAppNotificationSettings:
                    AppleNotificationSetting.notSupported,
              ),
            );
      } else if (Platform.isAndroid) {
        await _messaging?.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: permission request error: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Android notification channel
  // ---------------------------------------------------------------------------

  Future<void> _createAndroidNotificationChannel() async {
    try {
      const channel = AndroidNotificationChannel(
        'paynow_mm',
        'Paynow MM',
        description: 'Notifications from Paynow MM',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'NotificationService: error creating Android channel: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // FCM token management
  // ---------------------------------------------------------------------------

  Future<void> _setupFCMToken() async {
    try {
      _fcmToken = await _messaging?.getToken().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              if (kDebugMode) {
                debugPrint('NotificationService: getToken timeout');
              }
              return null;
            },
          );

      if (_fcmToken != null) {
        _sendTokenToBackend(_fcmToken!);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: error getting FCM token: $e');
      }
    }
  }

  /// Manually refresh and re-send the FCM token.
  /// Uses a Completer lock to prevent concurrent refresh attempts.
  Future<void> refreshToken() async {
    if (_fcmRefreshLock != null) {
      if (kDebugMode) {
        debugPrint(
            'NotificationService: token refresh already in progress, waiting...');
      }
      await _fcmRefreshLock!.future;
      return;
    }

    _fcmRefreshLock = Completer<void>();
    try {
      final token = await _messaging?.getToken();
      if (token != null) {
        final changed = token != _fcmToken;
        _fcmToken = token;

        if (changed) {
          await _sendTokenToBackend(token);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: error refreshing token: $e');
      }
    } finally {
      _fcmRefreshLock!.complete();
      _fcmRefreshLock = null;
    }
  }

  /// Send the FCM token to the Supabase profiles table.
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) {
          debugPrint(
              'NotificationService: no authenticated user, skipping token save');
        }
        return;
      }

      await supabase.from('profiles').update({
        'fcm_token': token,
      }).eq('id', userId);

      if (kDebugMode) {
        debugPrint('NotificationService: FCM token saved to profiles');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: failed to save FCM token: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Foreground message handling
  // ---------------------------------------------------------------------------

  void _handleForegroundMessage(RemoteMessage message) {
    try {
      if (kDebugMode) {
        debugPrint(
            'NotificationService: foreground message - ${message.notification?.title}');
      }

      if (message.notification != null) {
        // Store in local history
        NotificationStorageService.saveNotification(
          title: message.notification!.title ?? 'Notification',
          body: message.notification!.body ?? '',
          data: message.data,
        );

        // Notify listeners (badge count update)
        _notificationController.add({
          'type': 'new_notification',
          'title': message.notification!.title,
          'body': message.notification!.body,
        });

        // Show local notification on both Android and iOS
        // iOS setForegroundNotificationPresentationOptions may not always work
        showLocalNotification(
          id: message.hashCode,
          title: message.notification!.title ?? 'Paynow MM',
          body: message.notification!.body ?? '',
          payload: jsonEncode(message.data),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'NotificationService: error handling foreground message: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Notification tap handling
  // ---------------------------------------------------------------------------

  /// Pending tap data — stored when onNotificationTapped is not yet set (cold start)
  Map<String, dynamic>? _pendingTapData;

  /// Get and clear pending tap data (called from main.dart after setting onNotificationTapped)
  Map<String, dynamic>? consumePendingTap() {
    final data = _pendingTapData;
    _pendingTapData = null;
    return data;
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      if (kDebugMode) {
        debugPrint('NotificationService: notification tapped, data: $data');
      }
      if (onNotificationTapped != null) {
        onNotificationTapped!.call(data);
      } else {
        // Store for later — callback not set yet (cold start)
        _pendingTapData = data;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: error handling tap: $e');
      }
    }
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _handleNotificationTap(data);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'NotificationService: error parsing local notification payload: $e');
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Show local notification
  // ---------------------------------------------------------------------------

  /// Display a local notification banner.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'paynow_mm',
        'Paynow MM',
        channelDescription: 'Notifications from Paynow MM',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(id, title, body, details,
          payload: payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: error showing notification: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Badge management
  // ---------------------------------------------------------------------------

  /// Clear the app icon badge (iOS) and cancel all displayed notifications.
  Future<void> clearBadge() async {
    try {
      // Cancel all displayed local notifications
      await _localNotifications.cancelAll();

      // Reset iOS badge count to 0
      if (Platform.isIOS) {
        final iosPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        await iosPlugin?.requestPermissions(badge: true);
        // Show and immediately cancel a notification with badge 0 to reset
        await _localNotifications.show(
          999999,
          null,
          null,
          const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: false,
              presentBadge: true,
              presentSound: false,
              badgeNumber: 0,
            ),
          ),
        );
        await _localNotifications.cancel(999999);
      }

      if (kDebugMode) {
        debugPrint('NotificationService: badge cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: error clearing badge: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Token cleanup (sign-out)
  // ---------------------------------------------------------------------------

  /// Clear the FCM token from backend on sign out.
  /// NOTE: We do NOT delete the device token or clear from profile.
  /// The same device token will be re-saved to the next user who signs in.
  /// This prevents the parent losing notifications when seller signs in on same device.
  Future<void> clearToken() async {
    try {
      _fcmToken = null;

      if (kDebugMode) {
        debugPrint('NotificationService: token cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationService: error clearing token: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  /// Cancel stream subscriptions. Safe for singleton — does not close the
  /// broadcast stream controller.
  Future<void> dispose() async {
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    _onTokenRefreshSubscription?.cancel();
    _initialized = false;
  }
}
