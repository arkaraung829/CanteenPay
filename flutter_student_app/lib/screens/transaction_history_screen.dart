import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../providers/student_provider.dart';

/// Transaction history screen.
///
/// Shows a summary (balance + today's spending) and a list of
/// transactions grouped by date.
class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentProvider>(
      builder: (context, provider, _) {
        final wallet = provider.wallet;
        final transactions = provider.recentTransactions;
        final grouped = _groupByDate(transactions);

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(title: const Text('Transaction History')),
          body: RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // -- Summary card --
                _SummaryCard(
                  balance: wallet?.formattedBalance ?? '0 MMK',
                  spentToday: CurrencyFormatter.formatMMK(provider.totalSpentToday),
                ),
                const SizedBox(height: 16),

                // -- Grouped transactions --
                if (transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text(
                        'No transactions yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  ...grouped.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: entry.value
                                .map((t) => TransactionTile(transaction: t))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Group transactions by date label.
  Map<String, List<TransactionModel>> _groupByDate(
    List<TransactionModel> transactions,
  ) {
    final map = <String, List<TransactionModel>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final t in transactions) {
      final date = t.createdAt;
      String label;
      if (date == null) {
        label = 'Unknown';
      } else {
        final d = DateTime(date.year, date.month, date.day);
        if (d == today) {
          label = 'Today';
        } else if (d == yesterday) {
          label = 'Yesterday';
        } else {
          label = DateFormat('dd MMM yyyy').format(date);
        }
      }
      map.putIfAbsent(label, () => []).add(t);
    }
    return map;
  }
}

class _SummaryCard extends StatelessWidget {
  final String balance;
  final String spentToday;

  const _SummaryCard({
    required this.balance,
    required this.spentToday,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Balance',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    balance,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey[300],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Spent Today',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spentToday,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
