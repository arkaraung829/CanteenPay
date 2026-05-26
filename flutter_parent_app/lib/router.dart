import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';
import 'screens/child_detail_screen.dart';
import 'screens/transaction_history_screen.dart';
import 'screens/link_child_screen.dart';
import 'screens/spending_alerts_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

/// App router with bottom navigation shell.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    // Bottom nav shell
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return _ScaffoldWithBottomNav(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/notifications',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: NotificationsScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
      ],
    ),
    // Full-screen routes (no bottom nav)
    GoRoute(
      path: '/child/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final childId = state.pathParameters['id']!;
        return ChildDetailScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/child/:id/history',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final childId = state.pathParameters['id']!;
        return TransactionHistoryScreen(childId: childId);
      },
    ),
    GoRoute(
      path: '/link-child',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LinkChildScreen(),
    ),
    GoRoute(
      path: '/spending-alerts',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SpendingAlertsScreen(),
    ),
  ],
);

/// Scaffold wrapper that provides bottom navigation.
class _ScaffoldWithBottomNav extends StatelessWidget {
  final Widget child;

  const _ScaffoldWithBottomNav({required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/notifications')) return 1;
    if (location.startsWith('/profile')) return 2;
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
              context.go('/home');
            case 1:
              context.go('/notifications');
            case 2:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Notifications',
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
