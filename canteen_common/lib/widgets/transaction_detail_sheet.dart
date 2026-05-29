/// Transaction Detail Bottom Sheet
///
/// Shows full receipt-style details when tapping a transaction.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../models/transaction_model.dart';

class TransactionDetailSheet extends StatelessWidget {
  final TransactionModel transaction;

  const TransactionDetailSheet({super.key, required this.transaction});

  static void show(BuildContext context, TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TransactionDetailSheet(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.isDebit;
    final color = isDebit ? AppTheme.error : AppTheme.success;
    final typeLabel = _typeLabel(transaction.type);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Amount
          Icon(
            isDebit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: color,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            transaction.formattedAmount,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              typeLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Details
          _detailRow('Date', transaction.formattedDate),
          if (transaction.description != null)
            _detailRow('Description', transaction.description!),
          if (transaction.sellerName != null)
            _detailRow('Seller', transaction.sellerName!),
          if (transaction.balanceBefore != null)
            _detailRow('Balance Before', '${_formatNum(transaction.balanceBefore!)} MMK'),
          if (transaction.balanceAfter != null)
            _detailRow('Balance After', '${_formatNum(transaction.balanceAfter!)} MMK'),
          if (transaction.referenceId != null)
            _detailRow('Reference', transaction.referenceId!, copyable: true),
          _detailRow('Transaction ID', transaction.id.length > 8
              ? '${transaction.id.substring(0, 8)}...'
              : transaction.id, copyable: true, fullValue: transaction.id),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool copyable = false, String? fullValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: copyable
                ? Builder(builder: (ctx) {
                    return GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: fullValue ?? value));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('$label copied'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              value,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.copy, size: 14, color: Colors.grey[400]),
                        ],
                      ),
                    );
                  })
                : Text(
                    value,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'purchase':
        return 'Purchase';
      case 'deposit':
        return 'Deposit';
      case 'refund':
        return 'Refund';
      case 'adjustment':
        return 'Adjustment';
      default:
        return type;
    }
  }

  String _formatNum(int n) {
    final str = n.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
