/// Rate Limiter
///
/// In-memory sliding-window rate limiter with exponential backoff.
/// Prevents abuse of payment and auth endpoints.
import 'dart:math';

class RateLimiter {
  RateLimiter._();
  static final RateLimiter _instance = RateLimiter._();
  factory RateLimiter() => _instance;

  // ---------------------------------------------------------------------------
  // Preset limits for different endpoint types
  // ---------------------------------------------------------------------------

  /// General API: 60 requests per minute
  static const int generalMaxRequests = 60;
  static const int generalWindowMs = 60 * 1000;

  /// Auth endpoints: 10 requests per minute (brute-force protection)
  static const int authMaxRequests = 10;
  static const int authWindowMs = 60 * 1000;

  /// Payment/purchase: 5 requests per 10 seconds (prevent double-charge)
  static const int paymentMaxRequests = 5;
  static const int paymentWindowMs = 10 * 1000;

  /// QR scan: 15 requests per minute
  static const int scanMaxRequests = 15;
  static const int scanWindowMs = 60 * 1000;

  /// Timestamps of recent requests, keyed by endpoint / action name.
  final Map<String, List<DateTime>> _requests = {};

  /// Failure counts for backoff calculation
  final Map<String, int> _failures = {};

  /// Returns `true` if the caller may proceed, `false` if rate-limited.
  bool canProceed(
    String key, {
    int? maxRequests,
    int? windowMs,
  }) {
    final limit = maxRequests ?? _limitForKey(key);
    final window = windowMs ?? _windowForKey(key);

    _cleanup(key, window);

    final timestamps = _requests[key] ?? [];
    if (timestamps.length >= limit) {
      return false;
    }

    _requests.putIfAbsent(key, () => []).add(DateTime.now());
    return true;
  }

  /// How many requests remain in the current window for [key].
  int remainingRequests(String key) {
    final limit = _limitForKey(key);
    final window = _windowForKey(key);
    _cleanup(key, window);
    final count = _requests[key]?.length ?? 0;
    return (limit - count).clamp(0, limit);
  }

  /// Record a failure for backoff calculation
  void recordFailure(String key) {
    _failures[key] = (_failures[key] ?? 0) + 1;
  }

  /// Clear failure count (e.g., after successful request)
  void clearFailures(String key) {
    _failures.remove(key);
  }

  /// Calculate backoff delay in milliseconds using exponential backoff
  /// with jitter. baseDelay * 2^(failures-1) + random jitter
  int getBackoffMs(String key, {int baseDelayMs = 1000, int maxDelayMs = 30000}) {
    final failures = _failures[key] ?? 0;
    if (failures == 0) return 0;

    final delay = baseDelayMs * pow(2, min(failures - 1, 10));
    final jitter = Random().nextInt(500);
    return min(delay.toInt() + jitter, maxDelayMs);
  }

  /// Remove all tracked state.
  void reset() {
    _requests.clear();
    _failures.clear();
  }

  // ---------------------------------------------------------------------------
  // Auto-detect limits based on key prefix
  // ---------------------------------------------------------------------------

  int _limitForKey(String key) {
    if (key.startsWith('auth')) return authMaxRequests;
    if (key.startsWith('payment') || key.startsWith('purchase') || key.startsWith('deposit')) {
      return paymentMaxRequests;
    }
    if (key.startsWith('scan')) return scanMaxRequests;
    return generalMaxRequests;
  }

  int _windowForKey(String key) {
    if (key.startsWith('auth')) return authWindowMs;
    if (key.startsWith('payment') || key.startsWith('purchase') || key.startsWith('deposit')) {
      return paymentWindowMs;
    }
    if (key.startsWith('scan')) return scanWindowMs;
    return generalWindowMs;
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _cleanup(String key, int windowMs) {
    final timestamps = _requests[key];
    if (timestamps == null) return;

    final cutoff =
        DateTime.now().subtract(Duration(milliseconds: windowMs));
    timestamps.removeWhere((t) => t.isBefore(cutoff));

    if (timestamps.isEmpty) {
      _requests.remove(key);
    }
  }
}
