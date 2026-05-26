import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/sales_provider.dart';
import '../../services/haptic_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_fade_in.dart';

/// Displays today's sales history with summary and filtering.
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  String _selectedFilter = 'all';

  Future<void> _onRefresh() async {
    HapticService.medium();
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      await context.read<SalesProvider>().loadTodaySales(auth.user!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sales = context.watch<SalesProvider>();

    final filteredSales = _selectedFilter == 'all'
        ? sales.todaySales
        : sales.filterByPeriod(_selectedFilter);

    final filteredTotal =
        filteredSales.fold<int>(0, (sum, tx) => sum + tx.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Sales"),
      ),
      body: Column(
        children: [
          // Summary bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: AppTheme.primary.withValues(alpha: 0.05),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Sales',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.formatMMK(filteredTotal),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${filteredSales.length} transactions',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Filter chips
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Morning', 'morning'),
                const SizedBox(width: 8),
                _buildFilterChip('Afternoon', 'afternoon'),
              ],
            ),
          ),

          const Divider(height: 1),

          // Transactions list with pull-to-refresh
          Expanded(
            child: sales.isLoading && filteredSales.isEmpty
                ? ListView(
                    children: [
                      for (int i = 0; i < 5; i++) ShimmerLoading.listTile(),
                    ],
                  )
                : filteredSales.isEmpty
                    ? EmptyStateWidget.noSales()
                    : AnimatedFadeIn(
                        child: RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: _onRefresh,
                          child: ListView.separated(
                            itemCount: filteredSales.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              return TransactionTile(
                                transaction: filteredSales[index],
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          HapticService.selection();
          setState(() => _selectedFilter = value);
        }
      },
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
