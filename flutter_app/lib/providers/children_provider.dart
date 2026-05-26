import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

/// Holds data about the parent's linked children and their wallets/transactions.
class ChildrenProvider extends ChangeNotifier {
  List<StudentModel> _children = [];
  final Map<String, WalletModel> _wallets = {};
  final Map<String, List<TransactionModel>> _transactions = {};
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  List<StudentModel> get children => _children;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Sum of all children's balances.
  int get totalBalance =>
      _wallets.values.fold<int>(0, (sum, w) => sum + w.balance);

  /// Get the wallet for a specific child.
  WalletModel? walletForChild(String childId) => _wallets[childId];

  /// Load real children data from Supabase via parent-student links.
  Future<void> loadChildren(String parentId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final links = await SupabaseService.instance.getStudentsForParent(parentId);

      _children = [];
      _wallets.clear();

      for (final link in links) {
        if (link.student != null) {
          _children.add(link.student!);
          if (link.wallet != null) {
            _wallets[link.student!.id] = link.wallet!;
          } else {
            // Fetch wallet separately if not eager-loaded
            try {
              final wallet =
                  await SupabaseService.instance.getWallet(link.student!.id);
              if (wallet != null) {
                _wallets[link.student!.id] = wallet;
              }
            } catch (e) {
              debugPrint('ChildrenProvider: failed to load wallet for ${link.student!.id}: $e');
            }
          }
        }
      }

      // Load recent transactions for each child
      for (final child in _children) {
        await _loadChildTransactions(child.id);
      }

      // Subscribe to realtime wallet updates
      _subscribeToWalletUpdates();
    } catch (e) {
      _error = 'Failed to load children: $e';
      debugPrint('ChildrenProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load transactions for a specific child.
  Future<void> _loadChildTransactions(String childId) async {
    try {
      final wallet = _wallets[childId];
      if (wallet == null) return;

      final txns = await SupabaseService.instance.getTransactions(
        wallet.id,
        limit: 20,
      );
      _transactions[childId] = txns;
    } catch (e) {
      debugPrint('ChildrenProvider: failed to load transactions for $childId: $e');
    }
  }

  /// Subscribe to realtime wallet balance updates.
  void _subscribeToWalletUpdates() {
    _realtimeChannel?.unsubscribe();

    if (_children.isEmpty) return;

    try {
      final studentIds = _children.map((c) => c.id).toList();
      _realtimeChannel = Supabase.instance.client
          .channel('parent-wallets')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'wallets',
            callback: (payload) {
              try {
                final updatedWallet = WalletModel.fromJson(payload.newRecord);
                if (studentIds.contains(updatedWallet.studentId)) {
                  _wallets[updatedWallet.studentId] = updatedWallet;
                  notifyListeners();
                }
              } catch (e) {
                debugPrint('ChildrenProvider: realtime parse error: $e');
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('ChildrenProvider: realtime subscription failed: $e');
    }
  }

  /// Get transactions for a child.
  List<TransactionModel> getChildTransactions(String childId) {
    return _transactions[childId] ?? [];
  }

  /// Refresh transactions for a specific child.
  Future<void> refreshChildTransactions(String childId) async {
    await _loadChildTransactions(childId);
    notifyListeners();
  }

  /// Get the last transaction for a child (for home screen cards).
  TransactionModel? getLastTransaction(String childId) {
    final txns = getChildTransactions(childId);
    return txns.isNotEmpty ? txns.first : null;
  }

  /// Weekly spending data for chart (Mon-Fri).
  /// Computes from real transactions.
  List<double> getWeeklySpending(String childId) {
    final txns = getChildTransactions(childId);
    final now = DateTime.now();
    // Find the most recent Monday
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);

    final dailySpending = List<double>.filled(5, 0);
    for (final tx in txns) {
      if (tx.createdAt == null || !tx.isDebit) continue;
      final diff = tx.createdAt!.difference(weekStart).inDays;
      if (diff >= 0 && diff < 5) {
        dailySpending[diff] += tx.amount.toDouble();
      }
    }
    return dailySpending;
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
