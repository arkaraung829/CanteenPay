import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import 'providers/scanner_provider.dart';
import 'providers/sales_provider.dart';
import 'providers/children_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/student_provider.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // For prototype: skip actual Firebase/Supabase initialization.
  // In production, initialize here with real credentials.
  try {
    // TODO: Initialize Firebase
    // await Firebase.initializeApp();

    // TODO: Initialize Supabase
    // await Supabase.initialize(
    //   url: SupabaseConfig.supabaseUrl,
    //   anonKey: SupabaseConfig.supabaseAnonKey,
    // );
    debugPrint('CanteenPay unified app starting (prototype mode)');
  } catch (e) {
    debugPrint('Initialization skipped (prototype mode): $e');
  }

  runApp(const CanteenPayApp());
}

class CanteenPayApp extends StatelessWidget {
  const CanteenPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Seller providers
        ChangeNotifierProvider(create: (_) => ScannerProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        // Parent providers
        ChangeNotifierProvider(
          create: (_) => ChildrenProvider()..loadChildren(),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider()..loadNotifications(),
        ),
        // Student provider
        ChangeNotifierProvider(create: (_) => StudentProvider()),
      ],
      child: MaterialApp.router(
        title: 'CanteenPay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
