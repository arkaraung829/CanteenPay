import 'package:flutter/foundation.dart';
import 'package:canteen_common/canteen_common.dart';

/// Tracks today's sales for the seller terminal.
class SalesProvider extends ChangeNotifier {
  final List<TransactionModel> _todaySales = [];

  List<TransactionModel> get todaySales => List.unmodifiable(_todaySales);

  int get totalAmount =>
      _todaySales.fold(0, (sum, tx) => sum + tx.amount);

  int get transactionCount => _todaySales.length;

  SalesProvider() {
    _loadDemoData();
  }

  /// Pre-populate with demo transactions for the prototype.
  void _loadDemoData() {
    final now = DateTime.now();
    final demoTransactions = [
      TransactionModel(
        id: 'tx-demo-001',
        walletId: 'wallet-001',
        type: 'purchase',
        amount: 1500,
        balanceBefore: 16500,
        balanceAfter: 15000,
        description: 'Lunch - Fried Rice',
        referenceId: 'REF-001',
        sellerId: 'seller-001',
        sellerName: 'Main Canteen',
        createdAt: now.subtract(const Duration(hours: 3, minutes: 20)),
      ),
      TransactionModel(
        id: 'tx-demo-002',
        walletId: 'wallet-002',
        type: 'purchase',
        amount: 1000,
        balanceBefore: 8000,
        balanceAfter: 7000,
        description: 'Snack - Samosa',
        referenceId: 'REF-002',
        sellerId: 'seller-001',
        sellerName: 'Main Canteen',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 45)),
      ),
      TransactionModel(
        id: 'tx-demo-003',
        walletId: 'wallet-003',
        type: 'purchase',
        amount: 2000,
        balanceBefore: 12000,
        balanceAfter: 10000,
        description: 'Lunch - Mohinga',
        referenceId: 'REF-003',
        sellerId: 'seller-001',
        sellerName: 'Main Canteen',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 10)),
      ),
      TransactionModel(
        id: 'tx-demo-004',
        walletId: 'wallet-004',
        type: 'purchase',
        amount: 500,
        balanceBefore: 5500,
        balanceAfter: 5000,
        description: 'Drink - Juice',
        referenceId: 'REF-004',
        sellerId: 'seller-001',
        sellerName: 'Main Canteen',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 30)),
      ),
      TransactionModel(
        id: 'tx-demo-005',
        walletId: 'wallet-005',
        type: 'purchase',
        amount: 3000,
        balanceBefore: 20000,
        balanceAfter: 17000,
        description: 'Lunch - Biryani Set',
        referenceId: 'REF-005',
        sellerId: 'seller-001',
        sellerName: 'Main Canteen',
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      TransactionModel(
        id: 'tx-demo-006',
        walletId: 'wallet-001',
        type: 'purchase',
        amount: 1000,
        balanceBefore: 15000,
        balanceAfter: 14000,
        description: 'Snack - Spring Roll',
        referenceId: 'REF-006',
        sellerId: 'seller-001',
        sellerName: 'Main Canteen',
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),
    ];

    _todaySales.addAll(demoTransactions);
  }

  /// Add a new sale to today's list.
  void addSale(TransactionModel transaction) {
    _todaySales.insert(0, transaction);
    notifyListeners();
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
}
