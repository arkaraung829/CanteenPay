/// Notification Storage Service
///
/// Stores received push notifications locally on device using SharedPreferences.
/// Provides read/unread tracking and auto-pruning to keep at most 100 items.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// NotificationItem model
// ---------------------------------------------------------------------------

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final bool isRead;

  /// Notification type derived from FCM data payload
  /// (purchase, deposit, low_balance, announcement, system).
  final String? type;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.data,
    required this.timestamp,
    this.isRead = false,
    this.type,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      id: id,
      title: title,
      body: body,
      data: data,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      type: type,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'type': type,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      body: (json['body'] as String?) ?? '',
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      timestamp: DateTime.tryParse((json['timestamp'] as String?) ?? '') ??
          DateTime.now(),
      isRead: (json['isRead'] as bool?) ?? false,
      type: json['type'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Storage service (all static)
// ---------------------------------------------------------------------------

class NotificationStorageService {
  static const String _storageKey = 'canteen_notifications';
  static const int _maxNotifications = 100;

  /// Save a new notification from an FCM push.
  /// Deduplicates by matching title + body within the last 30 seconds.
  static Future<void> saveNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_storageKey) ?? [];

      // Dedup: skip if same transaction_id already stored (prevents double-save)
      final txnId = data?['transaction_id']?.toString();
      if (txnId != null && stored.isNotEmpty) {
        try {
          for (final item in stored.take(5)) {
            final existing = Map<String, dynamic>.from(jsonDecode(item) as Map);
            final existingData = existing['data'] as Map<String, dynamic>?;
            if (existingData?['transaction_id']?.toString() == txnId) {
              return; // duplicate transaction
            }
          }
        } catch (_) {}
      }

      final type = data?['type']?.toString();

      final item = NotificationItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        data: data,
        timestamp: DateTime.now(),
        type: type,
      );

      stored.insert(0, jsonEncode(item.toJson()));

      // Auto-prune oldest
      if (stored.length > _maxNotifications) {
        stored.removeRange(_maxNotifications, stored.length);
      }

      await prefs.setStringList(_storageKey, stored);
    } catch (_) {
      // Never crash the app for storage errors.
    }
  }

  /// Return stored notifications, newest first. Optionally limited.
  static Future<List<NotificationItem>> getNotifications({int? limit}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_storageKey) ?? [];

      final items = stored.map((s) {
        try {
          return NotificationItem.fromJson(
              Map<String, dynamic>.from(jsonDecode(s) as Map));
        } catch (_) {
          return null;
        }
      }).whereType<NotificationItem>().toList();

      if (limit != null && items.length > limit) {
        return items.sublist(0, limit);
      }
      return items;
    } catch (_) {
      return [];
    }
  }

  /// Count of unread notifications.
  static Future<int> getUnreadCount() async {
    final items = await getNotifications();
    return items.where((n) => !n.isRead).length;
  }

  /// Mark a specific notification as read.
  static Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_storageKey) ?? [];
      final updated = stored.map((s) {
        try {
          final json = jsonDecode(s) as Map<String, dynamic>;
          if (json['id'] == id) {
            json['isRead'] = true;
          }
          return jsonEncode(json);
        } catch (_) {
          return s;
        }
      }).toList();
      await prefs.setStringList(_storageKey, updated);
    } catch (_) {}
  }

  /// Mark all notifications as read.
  static Future<void> markAllAsRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_storageKey) ?? [];
      final updated = stored.map((s) {
        try {
          final json = jsonDecode(s) as Map<String, dynamic>;
          json['isRead'] = true;
          return jsonEncode(json);
        } catch (_) {
          return s;
        }
      }).toList();
      await prefs.setStringList(_storageKey, updated);
    } catch (_) {}
  }

  /// Delete all stored notifications.
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
  }
}
