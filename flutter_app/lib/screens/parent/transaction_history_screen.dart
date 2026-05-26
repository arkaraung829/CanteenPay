import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/children_provider.dart';

/// Full transaction history for a specific child, grouped by date.
class TransactionHistoryScreen extends StatelessWidget {
  final String childId;

  const TransactionHistoryScreen({super.key, required this.childId});

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
    final transactions = provider.getChildTransactions(childId);

    // Group by date
    final grouped = <String, List<TransactionModel>>{};
    for (final tx in transactions) {
      final key = tx.createdAt != null
          ? DateFormat('dd MMM yyyy').format(tx.createdAt!)
          : 'Unknown';
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    // Today's total spent
    final now = DateTime.now();
    final todaySpent = transactions
        .where((tx) =>
            tx.isDebit &&
            tx.createdAt != null &&
            tx.createdAt!.year == now.year &&
            tx.createdAt!.month == now.month &&
            tx.createdAt!.day == now.day)
        .fold<int>(0, (sum, tx) => sum + tx.amount);

    return Scaffold(
      appBar: AppBar(
        title: Text('${child.displayName} - History'),
      ),
      body: Column(
        children: [
          // Today's summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppTheme.error.withValues(alpha: 0.1),
            child: Text(
              'Total spent today: ${CurrencyFormatter.formatMMK(todaySpent)}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: AppTheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Grouped list
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('No transactions yet.'))
                : ListView.builder(
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final date = grouped.keys.elementAt(index);
                      final txns = grouped[date]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                              date,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          ...txns.map(
                            (tx) => TransactionTile(transaction: tx),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
