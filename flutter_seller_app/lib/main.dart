import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import 'providers/scanner_provider.dart';
import 'providers/sales_provider.dart';
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
    //   url: SellerSupabaseConfig.supabaseUrl,
    //   anonKey: SellerSupabaseConfig.supabaseAnonKey,
    // );
  } catch (e) {
    debugPrint('Initialization skipped (prototype mode): $e');
  }

  runApp(const CanteenSellerApp());
}

class CanteenSellerApp extends StatelessWidget {
  const CanteenSellerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScannerProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
      ],
      child: MaterialApp.router(
        title: 'CanteenPay Seller',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
