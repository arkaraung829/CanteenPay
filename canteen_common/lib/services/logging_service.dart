/// Logging Service
///
/// Centralized structured logging for CanteenPay.
/// In debug mode: prints to console.
/// In release mode: sends errors to Crashlytics.
///
/// Usage:
/// ```dart
/// final logger = LoggingService();
/// logger.i('AUTH', 'User logged in');
/// logger.e('API', 'Request failed', error: e);
/// ```
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Log levels in order of severity
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Centralized logging service with rate limiting
class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  /// Current minimum log level
  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Rate limiting: track recent log keys to prevent flooding
  final Queue<_LogEntry> _recentLogs = Queue<_LogEntry>();
  static const int _maxLogsPerMinute = 60;
  static const Duration _rateLimitWindow = Duration(minutes: 1);

  /// Optional callback to forward errors to Crashlytics in release mode
  /// Set this after CrashReportingService is initialized.
  void Function(String message, {dynamic error, StackTrace? stackTrace})?
      onErrorLogged;

  /// Set minimum log level
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Check rate limit — returns true if log should be suppressed
  bool _isRateLimited(String tag, String message) {
    final now = DateTime.now();

    // Remove entries outside the window
    while (_recentLogs.isNotEmpty &&
        now.difference(_recentLogs.first.timestamp) > _rateLimitWindow) {
      _recentLogs.removeFirst();
    }

    if (_recentLogs.length >= _maxLogsPerMinute) {
      return true;
    }

    _recentLogs.addLast(_LogEntry(tag: tag, message: message, timestamp: now));
    return false;
  }

  /// Core log method
  void log(LogLevel level, String tag, String message,
      {Object? error, StackTrace? stackTrace}) {
    if (level.index < _minLevel.index) return;
    if (_isRateLimited(tag, message)) return;

    final levelStr = _getLevelString(level);
    final timestamp =
        DateTime.now().toIso8601String().split('T')[1].split('.')[0];

    final buffer = StringBuffer('[$timestamp] [$levelStr] [$tag] $message');
    if (error != null) {
      buffer.write('\n  Error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n  Stack trace:\n$stackTrace');
    }

    if (kDebugMode) {
      debugPrint(buffer.toString());
    }

    // In release mode, forward errors to Crashlytics
    if (!kDebugMode && level == LogLevel.error && onErrorLogged != null) {
      onErrorLogged!(message, error: error, stackTrace: stackTrace);
    }
  }

  String _getLevelString(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  // ============================================================
  // SHORTCUT METHODS
  // ============================================================

  /// Debug log
  void d(String tag, String message) =>
      log(LogLevel.debug, tag, message);

  /// Info log
  void i(String tag, String message) =>
      log(LogLevel.info, tag, message);

  /// Warning log
  void w(String tag, String message) =>
      log(LogLevel.warning, tag, message);

  /// Error log
  void e(String tag, String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace);

  // ============================================================
  // LEGACY COMPAT — matches cuckoo's named-parameter style
  // ============================================================

  void debug(String message, {String? tag}) =>
      log(LogLevel.debug, tag ?? 'APP', message);

  void info(String message, {String? tag}) =>
      log(LogLevel.info, tag ?? 'APP', message);

  void warning(String message, {String? tag, Object? error}) =>
      log(LogLevel.warning, tag ?? 'APP', message, error: error);

  void error(String message,
          {String? tag, Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, tag ?? 'APP', message,
          error: error, stackTrace: stackTrace);
}

class _LogEntry {
  final String tag;
  final String message;
  final DateTime timestamp;

  _LogEntry({
    required this.tag,
    required this.message,
    required this.timestamp,
  });
}
