import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/notification_provider.dart';

/// Notification list screen.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _iconForType(String type) {
    switch (type) {
      case 'purchase':
        return Icons.shopping_cart;
      case 'deposit':
        return Icons.account_balance_wallet;
      case 'low_balance':
        return Icons.warning_amber;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'purchase':
        return AppTheme.error;
      case 'deposit':
        return AppTheme.success;
      case 'low_balance':
        return AppTheme.secondary;
      default:
        return AppTheme.primary;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () => provider.markAllAsRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(child: Text('No notifications'))
          : ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final color = _colorForType(notif.type ?? 'system');
                return ListTile(
                  tileColor: notif.isRead
                      ? null
                      : AppTheme.primary.withValues(alpha: 0.04),
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Icon(
                      _iconForType(notif.type ?? 'system'),
                      color: color,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    notif.title,
                    style: TextStyle(
                      fontWeight:
                          notif.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(notif.body),
                  trailing: Text(
                    _timeAgo(notif.timestamp),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  onTap: () => provider.markAsRead(notif.id),
                );
              },
            ),
    );
  }
}
