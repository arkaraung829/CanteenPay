/// Offline Cache Service
///
/// Handles caching of data for offline access using SharedPreferences + JSON.
/// Supports TTL-based expiry and automatic eviction when cache exceeds size limit.
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  OfflineCacheService._();
  static final OfflineCacheService _instance = OfflineCacheService._();
  factory OfflineCacheService() => _instance;

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const String _cachePrefix = 'canteen_cache_';
  static const String _metaPrefix = 'canteen_cache_meta_';

  /// Maximum total cache size in bytes (~5 MB).
  static const int maxCacheSizeBytes = 5 * 1024 * 1024;

  // Default TTLs in minutes
  static const int ttlWalletMinutes = 5;
  static const int ttlTransactionsMinutes = 30;
  static const int ttlStudentsMinutes = 60;
  static const int ttlChildrenMinutes = 60;
  static const int ttlDefaultMinutes = 60;

  // Well-known cache keys
  static const String cacheKeyWallet = 'wallet';
  static const String cacheKeyTransactions = 'transactions';
  static const String cacheKeyStudents = 'students';
  static const String cacheKeyChildren = 'children';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Store [data] under [key] with an optional TTL (defaults to 60 min).
  Future<void> cacheData(
    String key,
    dynamic data, {
    int? ttlMinutes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final metaKey = '$_metaPrefix$key';

      final jsonString = jsonEncode(data);
      final now = DateTime.now().millisecondsSinceEpoch;
      final expiry = now +
          ((ttlMinutes ?? ttlDefaultMinutes) * 60 * 1000);

      await prefs.setString(cacheKey, jsonString);
      await prefs.setString(
        metaKey,
        jsonEncode({'expiry': expiry, 'created': now}),
      );

      // Check total size and evict if necessary.
      await _enforceMaxSize(prefs);

      if (kDebugMode) {
        debugPrint('OfflineCacheService: cached "$key" '
            '(${jsonString.length} bytes, TTL ${ttlMinutes ?? ttlDefaultMinutes}m)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OfflineCacheService: cacheData error: $e');
      }
      rethrow;
    }
  }

  /// Retrieve cached data for [key]. Returns `null` if missing or expired.
  Future<dynamic> getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cachePrefix$key';
      final metaKey = '$_metaPrefix$key';

      final jsonString = prefs.getString(cacheKey);
      final metaString = prefs.getString(metaKey);

      if (jsonString == null || metaString == null) return null;

      final meta = jsonDecode(metaString) as Map<String, dynamic>;
      final expiry = meta['expiry'] as int;

      if (DateTime.now().millisecondsSinceEpoch > expiry) {
        if (kDebugMode) {
          debugPrint('OfflineCacheService: cache expired for "$key"');
        }
        await invalidate(key);
        return null;
      }

      return jsonDecode(jsonString);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('OfflineCacheService: getCachedData error: $e');
      }
      return null;
    }
  }

  /// Returns `true` if the entry for [key] exists and is expired.
  Future<bool> isExpired(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final metaString = prefs.getString('$_metaPrefix$key');
    if (metaString == null) return true;

    final meta = jsonDecode(metaString) as Map<String, dynamic>;
    final expiry = meta['expiry'] as int;
    return DateTime.now().millisecondsSinceEpoch > expiry;
  }

  /// Remove a specific cache entry.
  Future<void> invalidate(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachePrefix$key');
    await prefs.remove('$_metaPrefix$key');
    if (kDebugMode) {
      debugPrint('OfflineCacheService: invalidated "$key"');
    }
  }

  /// Remove all cache entries managed by this service.
  Future<void> invalidateAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
        (k) => k.startsWith(_cachePrefix) || k.startsWith(_metaPrefix));
    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
    if (kDebugMode) {
      debugPrint('OfflineCacheService: invalidated all cache');
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Evict oldest entries until total size is under [maxCacheSizeBytes].
  Future<void> _enforceMaxSize(SharedPreferences prefs) async {
    final cacheKeys = prefs
        .getKeys()
        .where((k) => k.startsWith(_cachePrefix))
        .toList();

    // Calculate total size.
    int totalSize = 0;
    final entries = <_CacheEntry>[];
    for (final ck in cacheKeys) {
      final value = prefs.getString(ck);
      if (value == null) continue;
      final metaKey =
          '$_metaPrefix${ck.substring(_cachePrefix.length)}';
      final metaStr = prefs.getString(metaKey);
      int created = 0;
      if (metaStr != null) {
        final meta = jsonDecode(metaStr) as Map<String, dynamic>;
        created = (meta['created'] as int?) ?? 0;
      }
      totalSize += value.length;
      entries.add(_CacheEntry(ck, created, value.length));
    }

    if (totalSize <= maxCacheSizeBytes) return;

    // Sort oldest first and evict until under limit.
    entries.sort((a, b) => a.created.compareTo(b.created));
    for (final entry in entries) {
      if (totalSize <= maxCacheSizeBytes) break;
      final baseKey = entry.cacheKey.substring(_cachePrefix.length);
      await prefs.remove(entry.cacheKey);
      await prefs.remove('$_metaPrefix$baseKey');
      totalSize -= entry.size;
      if (kDebugMode) {
        debugPrint(
            'OfflineCacheService: evicted "$baseKey" (${entry.size} bytes)');
      }
    }
  }
}

class _CacheEntry {
  final String cacheKey;
  final int created;
  final int size;
  _CacheEntry(this.cacheKey, this.created, this.size);
}
