import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

/// Provider managing student data, wallet, and transactions using real Supabase.
class StudentProvider extends ChangeNotifier {
  StudentModel? _currentStudent;
  WalletModel? _wallet;
  List<TransactionModel> _recentTransactions = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  StudentModel? get currentStudent => _currentStudent;
  WalletModel? get wallet => _wallet;
  List<TransactionModel> get recentTransactions => _recentTransactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load student data from Supabase for the current user's profile_id.
  Future<void> loadStudent(String profileId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Find the student record linked to this profile
      final response = await Supabase.instance.client
          .from('students')
          .select()
          .eq('profile_id', profileId)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        _currentStudent = StudentModel.fromJson(response);

        // Load wallet
        final wallet =
            await SupabaseService.instance.getWallet(_currentStudent!.id);
        _wallet = wallet;

        // Load transactions
        if (wallet != null) {
          _recentTransactions =
              await SupabaseService.instance.getTransactions(wallet.id);
        }

        // Subscribe to realtime wallet updates
        _subscribeToWalletUpdates();
      } else {
        _error = 'No student profile found for this account';
      }
    } catch (e) {
      _error = 'Failed to load student data: $e';
      debugPrint('StudentProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Subscribe to realtime wallet updates for live balance.
  void _subscribeToWalletUpdates() {
    _realtimeChannel?.unsubscribe();

    if (_wallet == null) return;

    try {
      _realtimeChannel = Supabase.instance.client
          .channel('student-wallet-${_wallet!.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'wallets',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: _wallet!.id,
            ),
            callback: (payload) {
              try {
                _wallet = WalletModel.fromJson(payload.newRecord);
                notifyListeners();
              } catch (e) {
                debugPrint('StudentProvider: realtime parse error: $e');
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('StudentProvider: realtime subscription failed: $e');
    }
  }

  /// Refresh student data from Supabase.
  Future<void> refresh() async {
    if (_currentStudent == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Refresh wallet
      final wallet =
          await SupabaseService.instance.getWallet(_currentStudent!.id);
      _wallet = wallet;

      // Refresh transactions
      if (wallet != null) {
        _recentTransactions =
            await SupabaseService.instance.getTransactions(wallet.id);
      }
    } catch (e) {
      _error = 'Failed to refresh: $e';
      debugPrint('StudentProvider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get total spent today (using local time for Myanmar UTC+6:30).
  int get totalSpentToday {
    final now = DateTime.now();
    return _recentTransactions
        .where((t) {
          if (!t.isDebit || t.createdAt == null) return false;
          final local = t.createdAt!.toLocal();
          return local.year == now.year &&
              local.month == now.month &&
              local.day == now.day;
        })
        .fold(0, (sum, t) => sum + t.amount);
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
