import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:canteen_common/canteen_common.dart';

import 'providers/scanner_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/children_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/student_provider.dart';
import 'router.dart';
import 'screens/auth/onboarding_screen.dart';
import 'widgets/session_wrapper.dart';

// ---------------------------------------------------------------------------
// Top-level background message handler (MUST be top-level, not in a class)
// ---------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  if (message.notification != null) {
    await NotificationStorageService.saveNotification(
      title: message.notification!.title ?? 'Notification',
      body: message.notification!.body ?? '',
      data: message.data,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase (app works without Firebase config)
  bool firebaseAvailable = false;
  try {
    await Firebase.initializeApp();
    firebaseAvailable = true;
    debugPrint('CanteenPay: Firebase initialized');
  } catch (e) {
    debugPrint('CanteenPay: Firebase not configured — skipping ($e)');
  }

  // 2. Register FCM background handler
  if (firebaseAvailable) {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (_) {}
  }

  // 3. Initialize Crashlytics
  final crashReporting = CrashReportingService();
  if (firebaseAvailable) {
    try {
      await crashReporting.initialize();
      FlutterError.onError = crashReporting.flutterErrorHandler;
    } catch (_) {}
  }

  // 4. Initialize Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    debugPrint('CanteenPay: Supabase initialized');
  } catch (e) {
    debugPrint('CanteenPay: Supabase failed: $e');
  }

  // 5. Initialize Notifications (after Supabase)
  if (firebaseAvailable) {
    try {
      await NotificationService.instance.initialize();
    } catch (_) {}
  }

  // 6. Security checks
  try {
    await SecurityService().initialize();
  } catch (_) {}

  // 7. Analytics
  if (firebaseAvailable) {
    try {
      await AnalyticsService().initialize();
    } catch (_) {}
  }

  // 8. Wire logging to Crashlytics in release
  if (firebaseAvailable) {
    LoggingService().onErrorLogged = (message, {error, stackTrace}) {
      crashReporting.recordError(
        error ?? message,
        stackTrace: stackTrace,
        reason: message,
      );
    };
  }

  // 9. Catch async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    if (firebaseAvailable) {
      crashReporting.recordError(error, stackTrace: stack, fatal: true);
    }
    debugPrint('Uncaught error: $error');
    return true;
  };

  // 10. Limit image cache
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20;

  // 11. Check if onboarding was seen
  final showOnboarding = !await hasSeenOnboarding();

  // 12. Run app
  runApp(CanteenPayApp(showOnboarding: showOnboarding));
}

class CanteenPayApp extends StatefulWidget {
  final bool showOnboarding;
  const CanteenPayApp({super.key, this.showOnboarding = false});

  @override
  State<CanteenPayApp> createState() => _CanteenPayAppState();
}

class _CanteenPayAppState extends State<CanteenPayApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ScannerProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => ChildrenProvider()),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider()..loadNotifications(),
        ),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.watch<AuthProvider>();
          _router ??= createRouter(authProvider, initialOnboarding: widget.showOnboarding);
          final router = _router!;

          try {
            NotificationService.instance.onNotificationTapped = (data) {
              final type = data['type']?.toString();
              final studentId = data['student_id']?.toString();
              if ((type == 'purchase' || type == 'deposit') && studentId != null) {
                router.go('/parent/child/$studentId');
              } else if (type == 'low_balance') {
                router.go('/parent/alerts');
              } else {
                router.go('/parent/notifications');
              }
            };
          } catch (_) {
            // NotificationService unavailable (no Firebase)
          }

          return SessionWrapper(
            child: MaterialApp.router(
              title: 'CanteenPay',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          );
        },
      ),
    );
  }
}
