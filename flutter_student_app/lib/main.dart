import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import 'providers/student_provider.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Prototype: skip Firebase/Supabase init (would go here in production)
  try {
    // await Supabase.initialize(url: ..., anonKey: ...);
    // await Firebase.initializeApp();
  } catch (_) {
    // Silently ignore -- running in demo mode
  }

  runApp(const CanteenStudentApp());
}

class CanteenStudentApp extends StatelessWidget {
  const CanteenStudentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StudentProvider()),
      ],
      child: MaterialApp.router(
        title: 'CanteenPay Student',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
