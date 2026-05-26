/// Rate Limiter
///
/// In-memory sliding-window rate limiter to throttle API requests per endpoint.
class RateLimiter {
  RateLimiter._();
  static final RateLimiter _instance = RateLimiter._();
  factory RateLimiter() => _instance;

  /// Default limits.
  static const int defaultMaxRequests = 30;
  static const int defaultWindowMs = 60 * 1000; // 60 seconds

  /// Timestamps of recent requests, keyed by endpoint / action name.
  final Map<String, List<DateTime>> _requests = {};

  /// Returns `true` if the caller may proceed, `false` if rate-limited.
  ///
  /// Each call that returns `true` is recorded as a request.
  bool canProceed(
    String key, {
    int maxRequests = defaultMaxRequests,
    int windowMs = defaultWindowMs,
  }) {
    _cleanup(key, windowMs);

    final timestamps = _requests[key] ?? [];
    if (timestamps.length >= maxRequests) {
      return false;
    }

    _requests.putIfAbsent(key, () => []).add(DateTime.now());
    return true;
  }

  /// How many requests remain in the current window for [key].
  int remainingRequests(
    String key, {
    int maxRequests = defaultMaxRequests,
    int windowMs = defaultWindowMs,
  }) {
    _cleanup(key, windowMs);
    final count = _requests[key]?.length ?? 0;
    return (maxRequests - count).clamp(0, maxRequests);
  }

  /// Remove all tracked state.
  void reset() => _requests.clear();

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
