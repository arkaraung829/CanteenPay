import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';
import '../../widgets/spending_chart.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_fade_in.dart';

/// Detail view for a single child.
class ChildDetailScreen extends StatelessWidget {
  final String childId;

  const ChildDetailScreen({super.key, required this.childId});

  Widget _buildLoadingSkeleton() {
    return ListView(
      children: [
        const SizedBox(height: 16),
        ShimmerLoading.balance(),
        const SizedBox(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ShimmerLoading(width: 140, height: 20, borderRadius: 4),
        ),
        const SizedBox(height: 8),
        ShimmerLoading.card(height: 250),
        const SizedBox(height: 24),
        for (int i = 0; i < 3; i++) ShimmerLoading.listTile(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChildrenProvider>();
    final child = provider.children.firstWhere(
      (c) => c.id == childId,
      orElse: () => StudentModel(
        id: childId,
        profileId: '',
        schoolId: '',
        studentCode: '',
        fullName: 'Unknown',
      ),
    );
    final wallet = provider.walletForChild(childId);
    final transactions = provider.getChildTransactions(childId);
    final weeklySpending = provider.getWeeklySpending(childId);

    // Today's transactions only
    final now = DateTime.now();
    final todayTxns = transactions.where((tx) {
      if (tx.createdAt == null) return false;
      return tx.createdAt!.year == now.year &&
          tx.createdAt!.month == now.month &&
          tx.createdAt!.day == now.day;
    }).toList();

    if (provider.isLoading && wallet == null) {
      return Scaffold(
        appBar: AppBar(title: Text(child.displayName)),
        body: _buildLoadingSkeleton(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(child.displayName),
      ),
      body: AnimatedFadeIn(
        child: ListView(
          children: [
            const SizedBox(height: 16),
            // Balance card
            if (wallet != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BalanceCard(wallet: wallet),
              ),
            const SizedBox(height: 24),

            // Weekly spending chart
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Weekly Spending',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SpendingChart(weeklyData: weeklySpending),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Today's Activity
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Today's Activity (${todayTxns.length})",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            if (todayTxns.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'No transactions today.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ...todayTxns.map((tx) => TransactionTile(transaction: tx)),
            const SizedBox(height: 16),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/parent/alerts'),
                      icon: const Icon(Icons.tune),
                      label: const Text('Set Daily Limit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          context.push('/parent/child/$childId/history'),
                      icon: const Icon(Icons.history),
                      label: const Text('Full History'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
