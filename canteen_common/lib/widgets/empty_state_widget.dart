/// Empty State Widget
///
/// Generic empty state display with icon, title, and optional subtitle.
/// Includes named constructors for common empty state scenarios.
import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  /// No transactions yet - receipt icon.
  factory EmptyStateWidget.noTransactions() {
    return const EmptyStateWidget(
      icon: Icons.receipt_long_outlined,
      title: 'No transactions yet',
      subtitle: 'Your transaction history will appear here',
    );
  }

  /// No children linked - people icon with action button.
  factory EmptyStateWidget.noChildren({VoidCallback? onLinkChild}) {
    return EmptyStateWidget(
      icon: Icons.people_outline,
      title: "Link your child's account",
      subtitle: 'Add your child to monitor their spending and balance',
      action: onLinkChild != null
          ? ElevatedButton.icon(
              onPressed: onLinkChild,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Link Child'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            )
          : null,
    );
  }

  /// No sales today - store icon.
  factory EmptyStateWidget.noSales() {
    return const EmptyStateWidget(
      icon: Icons.storefront_outlined,
      title: 'No sales today',
      subtitle: 'Ready to scan! Sales will appear here.',
    );
  }

  /// No notifications - bell icon.
  factory EmptyStateWidget.noNotifications() {
    return const EmptyStateWidget(
      icon: Icons.notifications_none_outlined,
      title: "You're all caught up",
      subtitle: 'New notifications will appear here',
    );
  }

  /// Network error with retry button.
  factory EmptyStateWidget.networkError({VoidCallback? onRetry}) {
    return EmptyStateWidget(
      icon: Icons.wifi_off_outlined,
      title: 'Connection lost',
      subtitle: 'Please check your internet connection and try again',
      action: onRetry != null
          ? OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
