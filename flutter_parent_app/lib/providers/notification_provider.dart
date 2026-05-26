import 'package:flutter/foundation.dart';

/// A single notification entry.
class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String type; // purchase, deposit, low_balance
  final DateTime createdAt;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });
}

/// Manages in-app notifications for the parent.
class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Load demo notifications.
  void loadNotifications() {
    final now = DateTime.now();
    _notifications = [
      NotificationItem(
        id: 'notif-1',
        title: 'Purchase Alert',
        body: 'Aung Kyaw Zin purchased Fried Rice for 1,500 MMK',
        type: 'purchase',
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      NotificationItem(
        id: 'notif-2',
        title: 'Purchase Alert',
        body: 'Aye Aye Khine purchased Milk Tea for 1,000 MMK',
        type: 'purchase',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      NotificationItem(
        id: 'notif-3',
        title: 'Deposit Confirmed',
        body: '10,000 MMK deposited to Aung Kyaw Zin\'s account',
        type: 'deposit',
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
      NotificationItem(
        id: 'notif-4',
        title: 'Low Balance Warning',
        body: 'Aye Aye Khine\'s balance is below 3,000 MMK',
        type: 'low_balance',
        createdAt: now.subtract(const Duration(days: 1, hours: 5)),
        isRead: true,
      ),
      NotificationItem(
        id: 'notif-5',
        title: 'Purchase Alert',
        body: 'Aung Kyaw Zin purchased Noodle Soup for 2,000 MMK',
        type: 'purchase',
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        isRead: true,
      ),
      NotificationItem(
        id: 'notif-6',
        title: 'Deposit Confirmed',
        body: '5,000 MMK deposited to Aye Aye Khine\'s account',
        type: 'deposit',
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];
    notifyListeners();
  }

  /// Mark a single notification as read.
  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  /// Mark all notifications as read.
  void markAllAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }
}
