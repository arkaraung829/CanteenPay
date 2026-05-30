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

    // Today's total spent
    final todaySpent = todayTxns
        .where((tx) => tx.isDebit)
        .fold<int>(0, (sum, tx) => sum + tx.amount);

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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),

            // -- Balance Card --
            if (wallet != null) BalanceCard(wallet: wallet),
            const SizedBox(height: 16),

            // -- Quick Stats Row --
            Row(
              children: [
                _QuickStat(
                  icon: Icons.today,
                  label: "Today's Spent",
                  value: CurrencyFormatter.formatMMK(todaySpent),
                  color: todaySpent > 0 ? AppTheme.error : AppTheme.textSecondary,
                ),
                const SizedBox(width: 12),
                _QuickStat(
                  icon: Icons.receipt_long,
                  label: 'Transactions',
                  value: '${todayTxns.length} today',
                  color: AppTheme.primary,
                ),
                if (child.dailySpendingLimit != null) ...[
                  const SizedBox(width: 12),
                  _QuickStat(
                    icon: Icons.tune,
                    label: 'Daily Limit',
                    value: CurrencyFormatter.formatMMK(child.dailySpendingLimit!),
                    color: Colors.orange,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // -- Student Info --
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.shadowSm,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    backgroundImage: child.photoUrl != null && child.photoUrl!.isNotEmpty
                        ? NetworkImage(child.photoUrl!) : null,
                    child: child.photoUrl == null || child.photoUrl!.isEmpty
                        ? Text(child.displayName[0],
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.displayName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(
                          '${child.gradeAndClass} · ${child.studentCode}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  if (child.schoolName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        child.schoolName!,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // -- Weekly Spending Chart --
            const Text(
              'Weekly Spending',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.shadowSm,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SpendingChart(weeklyData: weeklySpending),
              ),
            ),
            const SizedBox(height: 24),

            // -- Today's Activity --
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Activity (${todayTxns.length})",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (transactions.isNotEmpty)
                  TextButton(
                    onPressed: () => context.push('/parent/child/$childId/history'),
                    child: const Text('See All', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (todayTxns.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 32, color: AppTheme.textHint),
                      SizedBox(height: 8),
                      Text('No transactions today',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.shadowSm,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: todayTxns.map((tx) => TransactionTile(transaction: tx)).toList(),
                ),
              ),
            const SizedBox(height: 16),

            // -- Action Buttons --
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/parent/alerts'),
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Daily Limit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/parent/child/$childId/history'),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Full History'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
