/// Transaction Tile Widget
///
/// A ListTile for displaying a single transaction in a history list.
/// Shows a directional icon, formatted amount, description, time,
/// and a colored left border accent.
import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/transaction_model.dart';
import 'transaction_detail_sheet.dart';

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
    final accentColor = isDebit ? AppTheme.error : AppTheme.success;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: accentColor,
            width: 3,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap ?? () => TransactionDetailSheet.show(context, transaction),
        leading: CircleAvatar(
          backgroundColor: accentColor.withValues(alpha: 0.1),
          child: Icon(
            isDebit ? Icons.arrow_downward : Icons.arrow_upward,
            color: accentColor,
            size: 20,
          ),
        ),
        title: Text(
          transaction.description ?? transaction.type,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Icon(
                Icons.access_time,
                size: 12,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Text(
                _timeAgo(transaction.createdAt),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
              if (transaction.sellerName != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.storefront,
                  size: 12,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    transaction.sellerName!,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              transaction.formattedAmount,
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            if (transaction.balanceAfter != null)
              Text(
                'Bal: ${transaction.balanceAfter}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Simple time ago formatter.
  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final diff = DateTime.now().difference(dateTime.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return transaction.formattedDate;
  }
}
