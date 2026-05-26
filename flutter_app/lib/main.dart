import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:canteen_common/canteen_common.dart';

import 'providers/scanner_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/children_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/student_provider.dart';
import 'router.dart';
import 'widgets/session_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase (try-catch — app works without Firebase config)
  try {
    await Firebase.initializeApp();
    debugPrint('CanteenPay: Firebase initialized successfully');
  } catch (e) {
    debugPrint('CanteenPay: Firebase initialization skipped: $e');
  }

  // 2. Initialize Crashlytics and set FlutterError.onError
  final crashReporting = CrashReportingService();
  try {
    await crashReporting.initialize();
    FlutterError.onError = crashReporting.flutterErrorHandler;
  } catch (e) {
    debugPrint('CanteenPay: Crashlytics initialization skipped: $e');
  }

  // 3. Initialize Supabase
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    debugPrint('CanteenPay: Supabase initialized successfully');
  } catch (e) {
    debugPrint('CanteenPay: Supabase initialization failed: $e');
  }

  // 4. Initialize Security Service (jailbreak detection)
  final securityService = SecurityService();
  try {
    await securityService.initialize();
  } catch (e) {
    debugPrint('CanteenPay: Security service initialization skipped: $e');
  }

  // 5. Initialize Analytics Service
  final analyticsService = AnalyticsService();
  try {
    await analyticsService.initialize();
  } catch (e) {
    debugPrint('CanteenPay: Analytics initialization skipped: $e');
  }

  // 6. Wire up LoggingService to forward errors to Crashlytics in release mode
  LoggingService().onErrorLogged = (message, {error, stackTrace}) {
    crashReporting.recordError(
      error ?? message,
      stackTrace: stackTrace,
      reason: message,
    );
  };

  // 7. Set up PlatformDispatcher.onError for async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    crashReporting.recordError(error, stackTrace: stack, fatal: true);
    return true;
  };

  // 8. Limit image cache
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

  // 9. Run app inside error zone to catch all uncaught errors
  runZonedGuarded(
    () {
      runApp(const CanteenPayApp());
    },
    (error, stackTrace) {
      crashReporting.recordError(error, stackTrace: stackTrace, reason: 'Uncaught zone error');
    },
  );
}

class CanteenPayApp extends StatelessWidget {
  const CanteenPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth provider (from canteen_common) - must be first
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Seller providers
        ChangeNotifierProvider(create: (_) => ScannerProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        // Parent providers
        ChangeNotifierProvider(create: (_) => ChildrenProvider()),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider()..loadNotifications(),
        ),
        // Student provider
        ChangeNotifierProvider(create: (_) => StudentProvider()),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.watch<AuthProvider>();
          final router = createRouter(authProvider);
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
