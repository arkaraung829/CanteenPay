import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/child_card.dart';

/// Parent dashboard home screen.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _hasLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      _hasLoaded = true;
      final auth = context.read<AuthProvider>();
      final childrenProvider = context.read<ChildrenProvider>();
      if (auth.isAuthenticated && childrenProvider.children.isEmpty) {
        childrenProvider.loadChildren(auth.user!.id);
      }
    }
  }

  String _greeting() {
    final auth = context.read<AuthProvider>();
    final name = auth.user?.fullName ?? 'Parent';
    final firstName = name.split(' ').first;
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning, $firstName';
    if (hour < 17) return 'Good afternoon, $firstName';
    return 'Good evening, $firstName';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final childrenProvider = context.watch<ChildrenProvider>();
    final notifProvider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('CanteenPay'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/parent/notifications'),
              ),
              if (notifProvider.unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${notifProvider.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: childrenProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  childrenProvider.loadChildren(auth.user?.id ?? ''),
              child: ListView(
                children: [
                  const SizedBox(height: 20),

                  // Error state
                  if (childrenProvider.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          childrenProvider.error!,
                          style: const TextStyle(
                            color: AppTheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                  // Greeting
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _greeting(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Total balance card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BalanceCard(
                      wallet: WalletModel(
                        id: 'total',
                        studentId: 'all',
                        balance: childrenProvider.totalBalance,
                        currency: 'MMK',
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Children header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Children',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push('/parent/link-child'),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Link Child'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Children list
                  if (childrenProvider.children.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No children linked yet.\nTap "Link Child" to get started.',
                          style: TextStyle(color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ...childrenProvider.children.map((child) {
                      final wallet =
                          childrenProvider.walletForChild(child.id);
                      final lastTx =
                          childrenProvider.getLastTransaction(child.id);
                      return ChildCard(
                        child: child,
                        wallet: wallet,
                        lastTransaction: lastTx,
                        onTap: () =>
                            context.push('/parent/child/${child.id}'),
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
