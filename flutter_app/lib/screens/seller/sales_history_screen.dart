import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../services/haptic_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/animated_fade_in.dart';

/// Displays sales history with date picker and filtering.
class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  String _selectedFilter = 'all';
  late DateTime _selectedDate;
  List<TransactionModel> _sales = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSalesForDate());
  }

  Future<void> _loadSalesForDate() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dayStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final response = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('performed_by', auth.user!.id)
          .eq('type', 'purchase')
          .gte('created_at', dayStart.toIso8601String())
          .lt('created_at', dayEnd.toIso8601String())
          .order('created_at', ascending: false);

      _sales = (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();
    } catch (e) {
      _error = 'Failed to load sales: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      HapticService.selection();
      setState(() => _selectedDate = picked);
      _loadSalesForDate();
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  List<TransactionModel> get _filteredSales {
    if (_selectedFilter == 'all') return _sales;
    final noon = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 12);
    if (_selectedFilter == 'morning') {
      return _sales
          .where((tx) => tx.createdAt != null && tx.createdAt!.isBefore(noon))
          .toList();
    } else if (_selectedFilter == 'afternoon') {
      return _sales
          .where((tx) =>
              tx.createdAt != null &&
              (tx.createdAt!.isAfter(noon) || tx.createdAt!.isAtSameMomentAs(noon)))
          .toList();
    }
    return _sales;
  }

  @override
  Widget build(BuildContext context) {
    final filteredSales = _filteredSales;
    final filteredTotal =
        filteredSales.fold<int>(0, (sum, tx) => sum + tx.amount);

    final dateLabel = _isToday
        ? 'Today'
        : DateFormat('dd MMM yyyy').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('Sales - $dateLabel'),
      ),
      body: Column(
        children: [
          // Date picker row
          InkWell(
            onTap: _pickDate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: AppTheme.primary.withValues(alpha: 0.03),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_drop_down,
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

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

          // Error display
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // Transactions list with pull-to-refresh
          Expanded(
            child: _isLoading && filteredSales.isEmpty
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
                          onRefresh: _loadSalesForDate,
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
