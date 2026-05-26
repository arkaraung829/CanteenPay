/// Crash Reporting Service
///
/// Centralized crash reporting using Firebase Crashlytics.
/// Provides methods to log errors, set user context, and record non-fatal errors.
/// All calls are wrapped in try-catch so the app works even without Firebase config.
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'logging_service.dart';

/// Service for crash reporting and error tracking
class CrashReportingService {
  static final CrashReportingService _instance =
      CrashReportingService._internal();
  factory CrashReportingService() => _instance;
  CrashReportingService._internal();

  final LoggingService _logger = LoggingService();
  bool _isInitialized = false;

  /// Initialize crash reporting
  ///
  /// Should be called early in app startup, after Firebase.initializeApp()
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Disable crash collection in debug mode to avoid noise
      if (kDebugMode) {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(false);
        _logger.debug('Crashlytics disabled in debug mode', tag: 'CRASH');
      } else {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(true);
        _logger.info('Crashlytics initialized for release mode', tag: 'CRASH');
      }

      _isInitialized = true;
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize Crashlytics',
          tag: 'CRASH', error: e, stackTrace: stackTrace);
    }
  }

  /// Set user identifier for crash reports
  ///
  /// Call this after user logs in to associate crashes with user context
  Future<void> setUserIdentifier(String userId) async {
    if (!_isInitialized) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      _logger.debug('Crashlytics user identifier set', tag: 'CRASH');
    } catch (e) {
      _logger.error('Failed to set Crashlytics user identifier',
          tag: 'CRASH', error: e);
    }
  }

  /// Clear user identifier (call on logout)
  Future<void> clearUserIdentifier() async {
    if (!_isInitialized) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
      _logger.debug('Crashlytics user identifier cleared', tag: 'CRASH');
    } catch (e) {
      _logger.error('Failed to clear Crashlytics user identifier',
          tag: 'CRASH', error: e);
    }
  }

  /// Set custom key-value pairs for crash context
  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_isInitialized) return;

    try {
      if (value is String) {
        await FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else if (value is int) {
        await FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else if (value is double) {
        await FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else if (value is bool) {
        await FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else {
        await FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
      }
    } catch (e) {
      _logger.error('Failed to set Crashlytics custom key',
          tag: 'CRASH', error: e);
    }
  }

  /// Log a message that will appear in crash reports
  void log(String message) {
    if (!_isInitialized) return;

    try {
      FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      // Silently fail - we don't want crash reporting to cause crashes
    }
  }

  /// Record a non-fatal error
  ///
  /// Use this for caught exceptions that don't crash the app
  Future<void> recordError(
    dynamic error, {
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
  }) async {
    if (!_isInitialized) return;

    // Don't send errors in debug mode
    if (kDebugMode) {
      _logger.debug('Would record error: $reason - $error', tag: 'CRASH');
      return;
    }

    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace ?? StackTrace.current,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      _logger.error('Failed to record Crashlytics error',
          tag: 'CRASH', error: e);
    }
  }

  /// Record a Flutter error (from FlutterError.onError)
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (!_isInitialized) return;

    // Don't send errors in debug mode
    if (kDebugMode) {
      _logger.debug(
          'Would record Flutter error: ${details.exceptionAsString()}',
          tag: 'CRASH');
      return;
    }

    try {
      await FirebaseCrashlytics.instance.recordFlutterError(details);
    } catch (e) {
      _logger.error('Failed to record Crashlytics Flutter error',
          tag: 'CRASH', error: e);
    }
  }

  /// Get the handler for FlutterError.onError
  ///
  /// Combines Crashlytics recording with default Flutter error handling
  void Function(FlutterErrorDetails) get flutterErrorHandler {
    return (FlutterErrorDetails details) {
      // Record to Crashlytics
      recordFlutterError(details);

      // Also present the error (default behavior)
      FlutterError.presentError(details);
    };
  }
}
