import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:canteen_common/canteen_common.dart';

// Auth screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/role_select_screen.dart';

// Shared screens
import 'screens/shared/edit_profile_screen.dart';
import 'screens/auth/onboarding_screen.dart';

// Student screens
import 'screens/student/home_screen.dart' as student;
import 'screens/student/transaction_history_screen.dart' as student_history;
import 'screens/student/profile_screen.dart' as student_profile;

// Parent screens
import 'screens/parent/home_screen.dart' as parent;
import 'screens/parent/child_detail_screen.dart';
import 'screens/parent/transaction_history_screen.dart' as parent_history;
import 'screens/parent/link_child_screen.dart';
import 'screens/parent/spending_alerts_screen.dart';
import 'screens/parent/notifications_screen.dart';
import 'screens/parent/chat_screen.dart';
import 'screens/parent/messages_screen.dart';
import 'screens/parent/profile_screen.dart' as parent_profile;

// Seller screens
import 'screens/seller/scan_screen.dart';
import 'screens/seller/pin_verify_screen.dart';
import 'screens/seller/payment_confirm_screen.dart';
import 'screens/seller/payment_success_screen.dart';
import 'screens/seller/sales_history_screen.dart';
import 'screens/seller/analytics_screen.dart';
import 'screens/seller/profile_screen.dart' as seller_profile;
import 'screens/teacher/home_screen.dart' as teacher;
import 'screens/teacher/scan_screen.dart' as teacher_scan;
import 'screens/teacher/profile_screen.dart' as teacher_profile;
import 'screens/teacher/attendance_screen.dart' as teacher_attendance;

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _studentShellKey =
    GlobalKey<NavigatorState>(debugLabel: 'studentShell');
final GlobalKey<NavigatorState> _parentShellKey =
    GlobalKey<NavigatorState>(debugLabel: 'parentShell');
final GlobalKey<NavigatorState> _sellerShellKey =
    GlobalKey<NavigatorState>(debugLabel: 'sellerShell');

/// Returns the home path for a given user role.
String _homePathForRole(String? role) {
  switch (role) {
    case 'student':
      return '/student';
    case 'parent':
      return '/parent';
    case 'seller':
    case 'admin':
    case 'counter_staff':
      return '/seller';
    case 'teacher':
      return '/teacher';
    default:
      return '/login';
  }
}

/// Creates the GoRouter with auth-aware redirects.
GoRouter createRouter(AuthProvider authProvider, {bool initialOnboarding = false}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialOnboarding ? '/onboarding' : '/login',
    refreshListenable: authProvider,
    errorBuilder: (context, state) => const LoginScreen(),
    redirect: (context, state) {
      final isAuthenticated = authProvider.isAuthenticated;
      final isLoading = authProvider.isLoading;
      final user = authProvider.user;
      final path = state.uri.path;
      final isLoginRoute = path == '/login';
      final isRoleSelect = path == '/role-select';
      final isOnboarding = path == '/onboarding';

      // While auth is loading, stay on current page (don't flash)
      if (isLoading) return null;

      // Ignore Firebase auth callback URLs
      if (path.contains('__/auth/callback') || path.contains('firebaseapp.com')) {
        return '/login';
      }

      // Not logged in → go to login (but allow onboarding)
      if (!isAuthenticated && !isLoginRoute && !isRoleSelect && !isOnboarding) {
        return '/login';
      }

      // Logged in but profile not loaded yet → wait (don't redirect)
      if (isAuthenticated && user == null) return null;

      // Logged in with profile → redirect away from login to role home
      // But NOT during biometric check (user hasn't confirmed identity yet)
      if (isAuthenticated && user != null && isLoginRoute && !LoginScreen.biometricInProgress) {
        return _homePathForRole(user.role);
      }

      return null;
    },
    routes: [
      // ========== Auth Routes ==========
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/role-select',
        builder: (context, state) => const RoleSelectScreen(),
      ),

      // ========== Student Routes (ShellRoute with bottom nav) ==========
      ShellRoute(
        navigatorKey: _studentShellKey,
        builder: (context, state, child) => _StudentShell(child: child),
        routes: [
          GoRoute(
            path: '/student',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: student.HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/student/history',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: student_history.TransactionHistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/student/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: student_profile.ProfileScreen(),
            ),
          ),
        ],
      ),

      // ========== Parent Routes (ShellRoute with bottom nav) ==========
      ShellRoute(
        navigatorKey: _parentShellKey,
        builder: (context, state, child) => _ParentShell(child: child),
        routes: [
          GoRoute(
            path: '/parent',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: parent.HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/parent/notifications',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: '/parent/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: parent_profile.ProfileScreen(),
            ),
          ),
        ],
      ),
      // Parent full-screen routes (no bottom nav)
      GoRoute(
        path: '/parent/child/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final childId = state.pathParameters['id']!;
          return ChildDetailScreen(childId: childId);
        },
      ),
      GoRoute(
        path: '/parent/child/:id/history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final childId = state.pathParameters['id']!;
          return parent_history.TransactionHistoryScreen(childId: childId);
        },
      ),
      GoRoute(
        path: '/parent/link-child',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LinkChildScreen(),
      ),
      GoRoute(
        path: '/parent/alerts',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SpendingAlertsScreen(),
      ),
      GoRoute(
        path: '/parent/messages',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MessagesScreen(),
      ),
      GoRoute(
        path: '/parent/chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/parent/chat/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final conversationId = state.pathParameters['id']!;
          return ChatScreen(conversationId: conversationId);
        },
      ),

      // ========== Teacher Routes ==========
      ShellRoute(
        builder: (context, state, child) => _TeacherShell(child: child),
        routes: [
          GoRoute(
            path: '/teacher',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: teacher.TeacherHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/teacher/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: teacher_profile.TeacherProfileScreen(),
            ),
          ),
        ],
      ),
      // Teacher full-screen routes
      GoRoute(
        path: '/teacher/scan',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const teacher_scan.TeacherScanScreen(),
      ),
      GoRoute(
        path: '/teacher/attendance',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const teacher_attendance.AttendanceScreen(),
      ),
      GoRoute(
        path: '/teacher/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),

      // ========== Shared Routes ==========
      GoRoute(
        path: '/edit-profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),

      // ========== Seller Routes (ShellRoute with bottom nav) ==========
      ShellRoute(
        navigatorKey: _sellerShellKey,
        builder: (context, state, child) => _SellerShell(child: child),
        routes: [
          GoRoute(
            path: '/seller',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ScanScreen(),
            ),
          ),
          GoRoute(
            path: '/seller/sales',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SalesHistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/seller/analytics',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AnalyticsScreen(),
            ),
          ),
          GoRoute(
            path: '/seller/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: seller_profile.ProfileScreen(),
            ),
          ),
        ],
      ),
      // Seller full-screen routes (no bottom nav)
      GoRoute(
        path: '/seller/pin-verify',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PinVerifyScreen(amount: extra?['amount'] ?? 0);
        },
      ),
      GoRoute(
        path: '/seller/payment-confirm',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PaymentConfirmScreen(),
      ),
      GoRoute(
        path: '/seller/payment-success',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PaymentSuccessScreen(
            studentName: extra?['studentName'] ?? '',
            amountCharged: extra?['amountCharged'] ?? 0,
            referenceId: extra?['referenceId'] ?? '',
          );
        },
      ),
    ],
  );
}

// =============================================================================
// Shell Widgets (bottom navigation wrappers)
// =============================================================================

/// Student bottom navigation shell.
class _StudentShell extends StatelessWidget {
  final Widget child;
  const _StudentShell({required this.child});

  static const _tabs = ['/student', '/student/history', '/student/profile'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _tabs.indexWhere((t) => location == t);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final l10n = CanteenLocalizations.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.qr_code_2_outlined),
            selectedIcon: const Icon(Icons.qr_code_2),
            label: l10n?.qrCard ?? 'QR Card',
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long),
            label: l10n?.history ?? 'History',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n?.profile ?? 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Parent bottom navigation shell.
class _ParentShell extends StatelessWidget {
  final Widget child;
  const _ParentShell({required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/parent/notifications')) return 1;
    if (location.startsWith('/parent/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final l10n = CanteenLocalizations.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/parent');
            case 1:
              context.go('/parent/notifications');
            case 2:
              context.go('/parent/profile');
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n?.home ?? 'Home',
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: l10n?.notifications ?? 'Notifications',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person),
            label: l10n?.profile ?? 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Seller bottom navigation shell.
class _SellerShell extends StatelessWidget {
  final Widget child;
  const _SellerShell({required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/seller/sales')) return 1;
    if (location.startsWith('/seller/analytics')) return 2;
    if (location.startsWith('/seller/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    final l10n = CanteenLocalizations.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/seller');
            case 1:
              context.go('/seller/sales');
            case 2:
              context.go('/seller/analytics');
            case 3:
              context.go('/seller/profile');
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: const Icon(Icons.qr_code_scanner),
            label: l10n?.scanQr ?? 'Scan',
          ),
          NavigationDestination(
            icon: const Icon(Icons.list_alt_outlined),
            selectedIcon: const Icon(Icons.list_alt),
            label: l10n?.sales ?? 'Sales',
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart),
            label: l10n?.analyticsLabel ?? 'Analytics',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outlined),
            selectedIcon: const Icon(Icons.person),
            label: l10n?.profile ?? 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Teacher bottom navigation shell.
class _TeacherShell extends StatelessWidget {
  final Widget child;
  const _TeacherShell({required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/teacher/profile')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/teacher');
            case 1:
              context.go('/teacher/profile');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
