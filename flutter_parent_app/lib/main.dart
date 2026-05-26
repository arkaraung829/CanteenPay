import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import 'providers/children_provider.dart';
import 'providers/notification_provider.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Prototype: skip Firebase/Supabase init (would go here in production)
  try {
    // await Supabase.initialize(...)
    // await Firebase.initializeApp(...)
    debugPrint('CanteenPay Parent App starting (prototype mode)');
  } catch (e) {
    debugPrint('Init skipped in prototype: $e');
  }

  runApp(const CanteenPayParentApp());
}

class CanteenPayParentApp extends StatelessWidget {
  const CanteenPayParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ChildrenProvider()..loadChildren(),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider()..loadNotifications(),
        ),
      ],
      child: MaterialApp.router(
        title: 'CanteenPay Parent',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
