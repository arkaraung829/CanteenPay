import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

/// Tracks today's sales for the seller terminal using real Supabase data.
class SalesProvider extends ChangeNotifier {
  final List<TransactionModel> _todaySales = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  List<TransactionModel> get todaySales => List.unmodifiable(_todaySales);
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalAmount =>
      _todaySales.fold(0, (sum, tx) => sum + tx.amount);

  int get transactionCount => _todaySales.length;

  /// Load today's sales from Supabase for the given seller.
  Future<void> loadTodaySales(String sellerId) async {
    _isLoading = true;
    _error = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final response = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('performed_by', sellerId)
          .eq('type', 'purchase')
          .gte('created_at', todayStart.toIso8601String())
          .order('created_at', ascending: false);

      _todaySales.clear();
      _todaySales.addAll(
        (response as List)
            .map((json) => TransactionModel.fromJson(json))
            .toList(),
      );

      // Subscribe to realtime for new transactions
      _subscribeToRealtime(sellerId);
    } catch (e) {
      _error = 'Failed to load sales: $e';
      debugPrint('SalesProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to realtime inserts on transactions table.
  void _subscribeToRealtime(String sellerId) {
    _realtimeChannel?.unsubscribe();

    try {
      _realtimeChannel = Supabase.instance.client
          .channel('seller-sales-$sellerId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'transactions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'performed_by',
              value: sellerId,
            ),
            callback: (payload) {
              try {
                final newTx = TransactionModel.fromJson(payload.newRecord);
                // Only add if it's from today and not already in the list
                final now = DateTime.now();
                final isToday = newTx.createdAt != null &&
                    newTx.createdAt!.year == now.year &&
                    newTx.createdAt!.month == now.month &&
                    newTx.createdAt!.day == now.day;
                final alreadyExists = _todaySales.any((tx) => tx.id == newTx.id);
                if (isToday && !alreadyExists) {
                  _todaySales.insert(0, newTx);
                  notifyListeners();
                }
              } catch (e) {
                debugPrint('SalesProvider: realtime parse error: $e');
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('SalesProvider: realtime subscription failed: $e');
    }
  }

  /// Add a new sale to today's list (after successful RPC call).
  void addSale(TransactionModel transaction) {
    // Avoid duplicates from realtime
    if (!_todaySales.any((tx) => tx.id == transaction.id)) {
      _todaySales.insert(0, transaction);
      notifyListeners();
    }
  }

  /// Filter transactions by time period.
  List<TransactionModel> filterByPeriod(String period) {
    final now = DateTime.now();
    final noon = DateTime(now.year, now.month, now.day, 12);

    if (period == 'morning') {
      return _todaySales
          .where((tx) => tx.createdAt != null && tx.createdAt!.isBefore(noon))
          .toList();
    } else if (period == 'afternoon') {
      return _todaySales
          .where((tx) =>
              tx.createdAt != null &&
              (tx.createdAt!.isAfter(noon) ||
                  tx.createdAt!.isAtSameMomentAs(noon)))
          .toList();
    }
    return _todaySales;
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
