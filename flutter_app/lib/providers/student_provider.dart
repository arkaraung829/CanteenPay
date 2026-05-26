import 'package:flutter/foundation.dart';
import 'package:canteen_common/canteen_common.dart';

/// Provider managing student data, wallet, and transactions.
///
/// In prototype mode, this uses demo data. Replace with Supabase
/// calls for production.
class StudentProvider extends ChangeNotifier {
  StudentModel? _currentStudent;
  WalletModel? _wallet;
  List<TransactionModel> _recentTransactions = [];
  bool _isLoading = false;
  String? _error;

  StudentModel? get currentStudent => _currentStudent;
  WalletModel? get wallet => _wallet;
  List<TransactionModel> get recentTransactions => _recentTransactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  StudentProvider() {
    _loadDemoData();
  }

  void _loadDemoData() {
    _currentStudent = StudentModel(
      id: 'stu-001',
      profileId: 'profile-001',
      schoolId: 'school-001',
      studentCode: 'STU-2024-001',
      qrData: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
      fullName: 'Aung Kyaw Zin',
      className: 'A',
      grade: '5',
      enrollmentYear: 2024,
      isActive: true,
      dailySpendingLimit: 5000,
      createdAt: DateTime(2024, 6, 1),
    );

    _wallet = WalletModel(
      id: 'wallet-001',
      studentId: 'stu-001',
      balance: 15000,
      currency: 'MMK',
      isFrozen: false,
      updatedAt: DateTime.now(),
    );

    final now = DateTime.now();

    _recentTransactions = [
      TransactionModel(
        id: 'txn-001',
        walletId: 'wallet-001',
        type: 'purchase',
        amount: 1500,
        balanceBefore: 16500,
        balanceAfter: 15000,
        description: 'Mohinga (rice noodle soup)',
        sellerName: 'Canteen A',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      TransactionModel(
        id: 'txn-002',
        walletId: 'wallet-001',
        type: 'purchase',
        amount: 500,
        balanceBefore: 17000,
        balanceAfter: 16500,
        description: 'Bottled water',
        sellerName: 'Canteen A',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      TransactionModel(
        id: 'txn-003',
        walletId: 'wallet-001',
        type: 'deposit',
        amount: 10000,
        balanceBefore: 7000,
        balanceAfter: 17000,
        description: 'Top-up by parent',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      TransactionModel(
        id: 'txn-004',
        walletId: 'wallet-001',
        type: 'purchase',
        amount: 2000,
        balanceBefore: 9000,
        balanceAfter: 7000,
        description: 'Fried rice with egg',
        sellerName: 'Canteen B',
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
      ),
      TransactionModel(
        id: 'txn-005',
        walletId: 'wallet-001',
        type: 'purchase',
        amount: 1000,
        balanceBefore: 10000,
        balanceAfter: 9000,
        description: 'Milk tea',
        sellerName: 'Canteen A',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      TransactionModel(
        id: 'txn-006',
        walletId: 'wallet-001',
        type: 'deposit',
        amount: 5000,
        balanceBefore: 5000,
        balanceAfter: 10000,
        description: 'Top-up by parent',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  /// Refresh student data (simulate network call).
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Simulate network delay
      await Future<void>.delayed(const Duration(milliseconds: 800));
      // In production, fetch from Supabase here
      _loadDemoData();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get total spent today.
  int get totalSpentToday {
    final today = DateTime.now();
    return _recentTransactions
        .where((t) =>
            t.isDebit &&
            t.createdAt != null &&
            t.createdAt!.year == today.year &&
            t.createdAt!.month == today.month &&
            t.createdAt!.day == today.day)
        .fold(0, (sum, t) => sum + t.amount);
  }
}
