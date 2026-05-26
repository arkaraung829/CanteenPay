import 'package:flutter/material.dart';
import 'package:canteen_common/canteen_common.dart';

/// Card widget showing a child's summary on the home screen.
class ChildCard extends StatelessWidget {
  final StudentModel child;
  final WalletModel? wallet;
  final TransactionModel? lastTransaction;
  final VoidCallback? onTap;

  const ChildCard({
    super.key,
    required this.child,
    this.wallet,
    this.lastTransaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final balance = wallet?.balance ?? 0;
    final isLow = wallet?.isLowBalance ?? false;
    final initial = child.displayName.isNotEmpty ? child.displayName[0] : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name & class
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      child.gradeAndClass,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (lastTransaction != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last: ${lastTransaction!.description ?? lastTransaction!.type}',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Balance
              Text(
                CurrencyFormatter.formatMMK(balance),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isLow ? AppTheme.error : AppTheme.success,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
