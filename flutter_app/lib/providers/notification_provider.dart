import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:canteen_common/canteen_common.dart';

/// Re-export NotificationItem from canteen_common so screens can import from
/// this provider file without needing a separate import.
export 'package:canteen_common/services/notification_storage_service.dart'
    show NotificationItem;

/// Manages in-app notification state for the UI (badge count, list, read status).
/// Backed by [NotificationStorageService] for persistence and
/// [NotificationService.notificationStream] for real-time updates.
class NotificationProvider extends ChangeNotifier {
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  /// Load notifications from local storage and start listening for new ones.
  Future<void> loadNotifications() async {
    try {
      _notifications = await NotificationStorageService.getNotifications();
      _unreadCount = await NotificationStorageService.getUnreadCount();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationProvider: error loading notifications: $e');
      }
    }

    // Subscribe to real-time notification events
    _streamSubscription?.cancel();
    _streamSubscription =
        NotificationService.instance.notificationStream.listen((_) {
      // Reload from storage when a new notification arrives
      _reload();
    });
  }

  Future<void> _reload() async {
    try {
      _notifications = await NotificationStorageService.getNotifications();
      _unreadCount = await NotificationStorageService.getUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String id) async {
    try {
      await NotificationStorageService.markAsRead(id);
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationProvider: error marking as read: $e');
      }
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    try {
      await NotificationStorageService.markAllAsRead();
      _notifications =
          _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationProvider: error marking all as read: $e');
      }
    }
  }

  /// Clear all stored notifications.
  Future<void> clearAll() async {
    try {
      await NotificationStorageService.clearAll();
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
