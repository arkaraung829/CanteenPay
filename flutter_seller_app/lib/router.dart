import 'package:go_router/go_router.dart';

import 'screens/scan_screen.dart';
import 'screens/payment_confirm_screen.dart';
import 'screens/payment_success_screen.dart';
import 'screens/sales_history_screen.dart';
import 'screens/profile_screen.dart';

/// GoRouter configuration for the seller app.
final GoRouter appRouter = GoRouter(
  initialLocation: '/scan',
  routes: [
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: '/payment-confirm',
      builder: (context, state) => const PaymentConfirmScreen(),
    ),
    GoRoute(
      path: '/payment-success',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return PaymentSuccessScreen(
          studentName: extra?['studentName'] ?? '',
          amountCharged: extra?['amountCharged'] ?? 0,
          newBalance: extra?['newBalance'] ?? 0,
          referenceId: extra?['referenceId'] ?? '',
        );
      },
    ),
    GoRoute(
      path: '/sales',
      builder: (context, state) => const SalesHistoryScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
