/// Transaction Tile Widget
///
/// A ListTile for displaying a single transaction in a history list.
/// Shows a directional icon, formatted amount, description, and time.
import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/transaction_model.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDebit = transaction.isDebit;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor:
            (isDebit ? AppTheme.error : AppTheme.success).withValues(alpha: 0.1),
        child: Icon(
          isDebit ? Icons.arrow_downward : Icons.arrow_upward,
          color: isDebit ? AppTheme.error : AppTheme.success,
          size: 20,
        ),
      ),
      title: Text(
        transaction.description ?? transaction.type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _timeAgo(transaction.createdAt),
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Text(
        transaction.formattedAmount,
        style: TextStyle(
          color: isDebit ? AppTheme.error : AppTheme.success,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Simple time ago formatter
  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return transaction.formattedDate;
  }
}
