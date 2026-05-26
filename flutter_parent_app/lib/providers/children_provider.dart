import 'package:flutter/foundation.dart';
import 'package:canteen_common/canteen_common.dart';

/// Holds data about the parent's linked children and their wallets/transactions.
class ChildrenProvider extends ChangeNotifier {
  List<StudentModel> _children = [];
  final Map<String, WalletModel> _wallets = {};
  bool _isLoading = false;
  String? _error;

  List<StudentModel> get children => _children;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Sum of all children's balances.
  int get totalBalance =>
      _wallets.values.fold<int>(0, (sum, w) => sum + w.balance);

  /// Get the wallet for a specific child.
  WalletModel? walletForChild(String childId) => _wallets[childId];

  /// Load demo data. In production this would call Supabase.
  Future<void> loadChildren() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Simulate network delay
      await Future<void>.delayed(const Duration(milliseconds: 400));

      _children = [
        StudentModel(
          id: 'child-001',
          profileId: 'profile-001',
          schoolId: 'school-001',
          studentCode: 'STU-2025-001',
          fullName: 'Aung Kyaw Zin',
          grade: 'Grade 5',
          className: 'A',
          isActive: true,
          dailySpendingLimit: 5000,
          createdAt: DateTime(2025, 1, 15),
        ),
        StudentModel(
          id: 'child-002',
          profileId: 'profile-002',
          schoolId: 'school-001',
          studentCode: 'STU-2025-002',
          fullName: 'Aye Aye Khine',
          grade: 'Grade 3',
          className: 'B',
          isActive: true,
          dailySpendingLimit: 3000,
          createdAt: DateTime(2025, 1, 15),
        ),
      ];

      _wallets['child-001'] = WalletModel(
        id: 'wallet-001',
        studentId: 'child-001',
        balance: 15000,
        currency: 'MMK',
        updatedAt: DateTime.now(),
      );

      _wallets['child-002'] = WalletModel(
        id: 'wallet-002',
        studentId: 'child-002',
        balance: 8500,
        currency: 'MMK',
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get demo transactions for a child.
  List<TransactionModel> getChildTransactions(String childId) {
    final now = DateTime.now();
    if (childId == 'child-001') {
      return [
        TransactionModel(
          id: 'tx-001',
          walletId: 'wallet-001',
          type: 'purchase',
          amount: 1500,
          balanceBefore: 16500,
          balanceAfter: 15000,
          description: 'Fried Rice',
          sellerName: 'Canteen A',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
        TransactionModel(
          id: 'tx-002',
          walletId: 'wallet-001',
          type: 'purchase',
          amount: 500,
          balanceBefore: 17000,
          balanceAfter: 16500,
          description: 'Juice Box',
          sellerName: 'Canteen A',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        TransactionModel(
          id: 'tx-003',
          walletId: 'wallet-001',
          type: 'deposit',
          amount: 10000,
          balanceBefore: 7000,
          balanceAfter: 17000,
          description: 'Deposit by Parent',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        TransactionModel(
          id: 'tx-004',
          walletId: 'wallet-001',
          type: 'purchase',
          amount: 2000,
          balanceBefore: 9000,
          balanceAfter: 7000,
          description: 'Noodle Soup',
          sellerName: 'Canteen B',
          createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        ),
        TransactionModel(
          id: 'tx-005',
          walletId: 'wallet-001',
          type: 'purchase',
          amount: 1000,
          balanceBefore: 10000,
          balanceAfter: 9000,
          description: 'Snack Pack',
          sellerName: 'Canteen A',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];
    } else {
      return [
        TransactionModel(
          id: 'tx-101',
          walletId: 'wallet-002',
          type: 'purchase',
          amount: 1000,
          balanceBefore: 9500,
          balanceAfter: 8500,
          description: 'Milk Tea',
          sellerName: 'Canteen A',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        TransactionModel(
          id: 'tx-102',
          walletId: 'wallet-002',
          type: 'purchase',
          amount: 1500,
          balanceBefore: 11000,
          balanceAfter: 9500,
          description: 'Rice & Curry',
          sellerName: 'Canteen B',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        TransactionModel(
          id: 'tx-103',
          walletId: 'wallet-002',
          type: 'deposit',
          amount: 5000,
          balanceBefore: 6000,
          balanceAfter: 11000,
          description: 'Deposit by Parent',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];
    }
  }

  /// Get the last transaction for a child (for home screen cards).
  TransactionModel? getLastTransaction(String childId) {
    final txns = getChildTransactions(childId);
    return txns.isNotEmpty ? txns.first : null;
  }

  /// Weekly spending data for chart (Mon-Fri).
  List<double> getWeeklySpending(String childId) {
    if (childId == 'child-001') {
      return [3000, 2500, 2000, 1500, 2000];
    } else {
      return [1500, 1000, 2500, 1000, 1500];
    }
  }
}
