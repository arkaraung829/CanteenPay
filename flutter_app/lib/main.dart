import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import 'providers/scanner_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/children_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/student_provider.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with real credentials
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    debugPrint('CanteenPay: Supabase initialized successfully');
  } catch (e) {
    debugPrint('CanteenPay: Supabase initialization failed: $e');
  }

  runApp(const CanteenPayApp());
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
          return MaterialApp.router(
            title: 'CanteenPay',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            routerConfig: router,
          );
        },
      ),
    );
  }
}
