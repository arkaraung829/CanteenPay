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
  @override
  void initState() {
    super.initState();
    // Load data on first build
    final childrenProvider = context.read<ChildrenProvider>();
    if (childrenProvider.children.isEmpty) {
      childrenProvider.loadChildren();
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning, Parent';
    if (hour < 17) return 'Good afternoon, Parent';
    return 'Good evening, Parent';
  }

  @override
  Widget build(BuildContext context) {
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
              onRefresh: () => childrenProvider.loadChildren(),
              child: ListView(
                children: [
                  const SizedBox(height: 20),
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
