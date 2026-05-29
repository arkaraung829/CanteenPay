/// Offline Action Queue
///
/// Queues write-actions when the device is offline and replays them in order
/// once connectivity is restored. Actions that fail after [maxRetries] attempts
/// are moved to a dead-letter list for manual inspection.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'connectivity_service.dart';
import 'supabase_service.dart';

// ---------------------------------------------------------------------------
// Action model
// ---------------------------------------------------------------------------

class OfflineAction {
  final String type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  int retryCount;

  OfflineAction({
    required this.type,
    required this.payload,
    DateTime? timestamp,
    this.retryCount = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'type': type,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
      };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
        type: json['type'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        timestamp: DateTime.parse(json['timestamp'] as String),
        retryCount: (json['retryCount'] as int?) ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Action types
// ---------------------------------------------------------------------------

abstract class OfflineActionTypes {
  static const String purchase = 'purchase';
  static const String deposit = 'deposit';
}

// ---------------------------------------------------------------------------
// Queue service
// ---------------------------------------------------------------------------

class OfflineActionQueue {
  OfflineActionQueue._();
  static final OfflineActionQueue _instance = OfflineActionQueue._();
  factory OfflineActionQueue() => _instance;

  static const String _queueKey = 'canteen_offline_queue';
  static const String _deadLetterKey = 'canteen_offline_dead_letter';
  static const int maxRetries = 3;

  bool _processing = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Sensitive fields that must never be persisted to local storage.
  static const _sensitiveFields = {
    'token', 'access_token', 'refresh_token', 'password',
    'api_key', 'secret', 'authorization', 'session',
  };

  /// Add an action to the queue. Sanitizes sensitive data before persisting.
  Future<void> enqueue(OfflineAction action) async {
    // Sanitize payload before storing
    final sanitized = _sanitizePayload(action.payload);
    final safeAction = OfflineAction(
      type: action.type,
      payload: sanitized,
      timestamp: action.timestamp,
      retryCount: action.retryCount,
    );

    final queue = await _loadQueue();
    queue.add(safeAction);
    await _saveQueue(queue);
    if (kDebugMode) {
      debugPrint('OfflineActionQueue: enqueued ${action.type} '
          '(queue length: ${queue.length})');
    }
  }

  /// Remove sensitive fields from payload before persisting.
  Map<String, dynamic> _sanitizePayload(Map<String, dynamic> payload) {
    final clean = <String, dynamic>{};
    for (final entry in payload.entries) {
      if (_sensitiveFields.contains(entry.key.toLowerCase())) continue;
      if (entry.value is Map<String, dynamic>) {
        clean[entry.key] = _sanitizePayload(entry.value as Map<String, dynamic>);
      } else if (entry.value is List) {
        clean[entry.key] = (entry.value as List).map((item) {
          if (item is Map<String, dynamic>) return _sanitizePayload(item);
          return item;
        }).toList();
      } else {
        clean[entry.key] = entry.value;
      }
    }
    return clean;
  }

  /// Number of actions waiting to be replayed.
  Future<int> getPendingCount() async {
    final queue = await _loadQueue();
    return queue.length;
  }

  /// Actions that exceeded [maxRetries] and were moved to dead-letter.
  Future<List<OfflineAction>> getFailedActions() async {
    return _loadList(_deadLetterKey);
  }

  /// Clear the dead-letter queue.
  Future<void> clearFailedActions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deadLetterKey);
  }

  /// Called when connectivity is restored. Replays queued actions in order.
  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;

    try {
      final queue = await _loadQueue();
      if (queue.isEmpty) return;

      if (kDebugMode) {
        debugPrint(
            'OfflineActionQueue: processing ${queue.length} queued actions');
      }

      final remaining = <OfflineAction>[];
      final deadLetter = await _loadList(_deadLetterKey);

      for (final action in queue) {
        try {
          await _executeAction(action);
          if (kDebugMode) {
            debugPrint('OfflineActionQueue: replayed ${action.type}');
          }
        } catch (e) {
          action.retryCount++;
          if (action.retryCount >= maxRetries) {
            if (kDebugMode) {
              debugPrint(
                  'OfflineActionQueue: ${action.type} exceeded max retries, '
                  'moving to dead-letter');
            }
            deadLetter.add(action);
          } else {
            remaining.add(action);
            // Exponential backoff: 5s, 10s, 15s
            final delay = Duration(seconds: 5 * action.retryCount);
            if (kDebugMode) {
              debugPrint('OfflineActionQueue: retry ${action.retryCount} '
                  'for ${action.type}, waiting ${delay.inSeconds}s');
            }
            await Future.delayed(delay);
          }
        }
      }

      await _saveQueue(remaining);
      await _saveList(_deadLetterKey, deadLetter);
    } finally {
      _processing = false;
    }
  }

  /// Hook into [ConnectivityService] -- call this on connectivity changes.
  void onConnectivityChanged(bool isOnline) {
    if (isOnline) {
      processQueue();
    }
  }

  // ---------------------------------------------------------------------------
  // Action execution
  // ---------------------------------------------------------------------------

  Future<void> _executeAction(OfflineAction action) async {
    final svc = SupabaseService.instance;

    switch (action.type) {
      case OfflineActionTypes.purchase:
        await svc.processPurchase(
          qrData: action.payload['qr_data'] as String,
          amount: action.payload['amount'] as int,
          sellerProfileId: action.payload['seller_profile_id'] as String,
          description: action.payload['description'] as String?,
        );
        break;

      case OfflineActionTypes.deposit:
        await svc.processDeposit(
          studentId: action.payload['student_id'] as String,
          amount: action.payload['amount'] as int,
          staffProfileId: action.payload['staff_profile_id'] as String,
          reference: action.payload['reference'] as String?,
          note: action.payload['note'] as String?,
        );
        break;

      default:
        throw UnsupportedError(
            'Unknown offline action type: ${action.type}');
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  Future<List<OfflineAction>> _loadQueue() => _loadList(_queueKey);

  Future<void> _saveQueue(List<OfflineAction> queue) =>
      _saveList(_queueKey, queue);

  Future<List<OfflineAction>> _loadList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => OfflineAction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OfflineActionQueue: failed to parse $key: $e');
      }
      return [];
    }
  }

  Future<void> _saveList(String key, List<OfflineAction> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(list.map((a) => a.toJson()).toList());
    await prefs.setString(key, jsonString);
  }
}
