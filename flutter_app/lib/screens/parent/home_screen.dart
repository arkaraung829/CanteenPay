import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/child_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_fade_in.dart';

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = context.read<AuthProvider>();
        final childrenProvider = context.read<ChildrenProvider>();
        if (auth.isAuthenticated && childrenProvider.children.isEmpty) {
          childrenProvider.loadChildren(auth.user!.id);
        }
      });
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

  /// Build children list, grouped by school if children are in different schools.
  List<Widget> _buildChildrenList(ChildrenProvider childrenProvider) {
    final children = childrenProvider.children;
    final schoolNames = children
        .map((c) => c.schoolName ?? '')
        .toSet();
    final hasMultipleSchools = schoolNames.length > 1;

    if (!hasMultipleSchools) {
      // All same school (or no school info) - flat list
      return children.map((child) {
        final wallet = childrenProvider.walletForChild(child.id);
        final lastTx = childrenProvider.getLastTransaction(child.id);
        return ChildCard(
          child: child,
          wallet: wallet,
          lastTransaction: lastTx,
          onTap: () => context.push('/parent/child/${child.id}'),
        );
      }).toList();
    }

    // Group by school
    final grouped = <String, List<StudentModel>>{};
    for (final child in children) {
      final school = child.schoolName ?? 'Unknown School';
      grouped.putIfAbsent(school, () => []).add(child);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 4,
          ),
          child: Row(
            children: [
              Icon(
                Icons.school_outlined,
                size: 16,
                color: AppTheme.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                entry.key,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      );
      for (final child in entry.value) {
        final wallet = childrenProvider.walletForChild(child.id);
        final lastTx = childrenProvider.getLastTransaction(child.id);
        widgets.add(
          ChildCard(
            child: child,
            wallet: wallet,
            lastTransaction: lastTx,
            onTap: () => context.push('/parent/child/${child.id}'),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildLoadingSkeleton() {
    return ListView(
      children: [
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ShimmerLoading(width: 200, height: 24, borderRadius: 6),
        ),
        const SizedBox(height: 16),
        ShimmerLoading.balance(),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ShimmerLoading(width: 120, height: 20, borderRadius: 4),
        ),
        const SizedBox(height: 12),
        ShimmerLoading.card(height: 120),
        const SizedBox(height: 4),
        ShimmerLoading.card(height: 120),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final childrenProvider = context.watch<ChildrenProvider>();
    final notifProvider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paynow MM'),
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
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () =>
                  childrenProvider.loadChildren(auth.user?.id ?? ''),
              child: AnimatedFadeIn(
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
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: AppTheme.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  childrenProvider.error!,
                                  style: const TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
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
                            onPressed: () =>
                                context.push('/parent/link-child'),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Link Child'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Children list
                    if (childrenProvider.children.isEmpty)
                      EmptyStateWidget.noChildren(
                        onLinkChild: () =>
                            context.push('/parent/link-child'),
                      )
                    else
                      ..._buildChildrenList(childrenProvider),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
