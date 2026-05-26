/// Analytics Service
///
/// Centralized analytics tracking using Firebase Analytics.
/// Tracks user behavior, canteen purchases, deposits, QR scans, and more.
/// All calls are wrapped in try-catch so the app works even without Firebase config.
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'logging_service.dart';

/// Service for tracking user behavior and app analytics
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  final LoggingService _logger = LoggingService();
  bool _isInitialized = false;

  /// Lazy access to Firebase Analytics — returns null if Firebase not configured.
  FirebaseAnalytics? get _safeAnalytics {
    if (_analytics != null) return _analytics;
    try {
      _analytics = FirebaseAnalytics.instance;
      return _analytics;
    } catch (_) {
      return null;
    }
  }

  /// Get the analytics observer for navigation tracking (safe — no-ops if unavailable)
  FirebaseAnalyticsObserver? get observer {
    final a = _safeAnalytics;
    if (a == null) return null;
    return FirebaseAnalyticsObserver(analytics: a);
  }

  /// Initialize analytics service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Disable analytics collection in debug mode for clean data
      if (kDebugMode) {
        await _safeAnalytics?.setAnalyticsCollectionEnabled(false);
        _logger.debug('Analytics disabled in debug mode', tag: 'ANALYTICS');
      } else {
        await _safeAnalytics?.setAnalyticsCollectionEnabled(true);
        _logger.info('Analytics initialized for production', tag: 'ANALYTICS');
      }

      _isInitialized = true;
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize Analytics',
          tag: 'ANALYTICS', error: e, stackTrace: stackTrace);
    }
  }

  // ============================================================
  // USER IDENTIFICATION
  // ============================================================

  /// Set user ID for analytics (call after login)
  Future<void> setUserId(String userId) async {
    try {
      await _safeAnalytics?.setUserId(id: userId);
      _logger.debug('Analytics user ID set', tag: 'ANALYTICS');
    } catch (e) {
      _logger.error('Failed to set analytics user ID',
          tag: 'ANALYTICS', error: e);
    }
  }

  /// Clear user ID (call on logout)
  Future<void> clearUserId() async {
    try {
      await _safeAnalytics?.setUserId(id: null);
      _logger.debug('Analytics user ID cleared', tag: 'ANALYTICS');
    } catch (e) {
      _logger.error('Failed to clear analytics user ID',
          tag: 'ANALYTICS', error: e);
    }
  }

  /// Set user properties for segmentation
  Future<void> setUserProperties({String? role, String? schoolId}) async {
    try {
      if (role != null) {
        await _safeAnalytics?.setUserProperty(name: 'user_role', value: role);
      }
      if (schoolId != null) {
        await _safeAnalytics?.setUserProperty(name: 'school_id', value: schoolId);
      }
    } catch (e) {
      _logger.error('Failed to set user properties',
          tag: 'ANALYTICS', error: e);
    }
  }

  // ============================================================
  // SCREEN TRACKING
  // ============================================================

  /// Log screen view
  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    try {
      await _safeAnalytics?.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      if (kDebugMode) {
        _logger.debug('Screen view: $screenName', tag: 'ANALYTICS');
      }
    } catch (e) {
      _logger.error('Failed to log screen view', tag: 'ANALYTICS', error: e);
    }
  }

  // ============================================================
  // AUTH TRACKING
  // ============================================================

  /// Log login event
  Future<void> logLogin(String method) async {
    try {
      await _safeAnalytics?.logLogin(loginMethod: method);
    } catch (e) {
      _logger.error('Failed to log login', tag: 'ANALYTICS', error: e);
    }
  }

  /// Log sign up event
  Future<void> logSignUp(String method) async {
    try {
      await _safeAnalytics?.logSignUp(signUpMethod: method);
    } catch (e) {
      _logger.error('Failed to log sign up', tag: 'ANALYTICS', error: e);
    }
  }

  // ============================================================
  // CANTEEN-SPECIFIC EVENTS
  // ============================================================

  /// Log canteen purchase (seller charges student)
  Future<void> logPurchase({
    required double amount,
    required String studentName,
    required String sellerName,
  }) async {
    try {
      await _safeAnalytics?.logEvent(
        name: 'canteen_purchase',
        parameters: {
          'amount': amount,
          'student_name': studentName,
          'seller_name': sellerName,
        },
      );
      _logger.info(
          'Purchase logged: $amount from $studentName by $sellerName',
          tag: 'ANALYTICS');
    } catch (e) {
      _logger.error('Failed to log purchase', tag: 'ANALYTICS', error: e);
    }
  }

  /// Log balance deposit (parent deposits money)
  Future<void> logDeposit({
    required double amount,
    required String studentName,
  }) async {
    try {
      await _safeAnalytics?.logEvent(
        name: 'balance_deposit',
        parameters: {
          'amount': amount,
          'student_name': studentName,
        },
      );
    } catch (e) {
      _logger.error('Failed to log deposit', tag: 'ANALYTICS', error: e);
    }
  }

  /// Log QR code scanned by seller
  Future<void> logQrScan(String studentId) async {
    try {
      await _safeAnalytics?.logEvent(
        name: 'qr_scan',
        parameters: {
          'student_id': studentId,
        },
      );
    } catch (e) {
      _logger.error('Failed to log QR scan', tag: 'ANALYTICS', error: e);
    }
  }

  /// Log student checking their balance
  Future<void> logBalanceCheck(double balance) async {
    try {
      await _safeAnalytics?.logEvent(
        name: 'balance_check',
        parameters: {
          'balance': balance,
        },
      );
    } catch (e) {
      _logger.error('Failed to log balance check',
          tag: 'ANALYTICS', error: e);
    }
  }

  /// Log parent linking a child
  Future<void> logChildLinked(String studentId) async {
    try {
      await _safeAnalytics?.logEvent(
        name: 'child_linked',
        parameters: {
          'student_id': studentId,
        },
      );
    } catch (e) {
      _logger.error('Failed to log child linked',
          tag: 'ANALYTICS', error: e);
    }
  }

  // ============================================================
  // CUSTOM EVENTS
  // ============================================================

  /// Log custom event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _safeAnalytics?.logEvent(
        name: name,
        parameters: parameters,
      );
      if (kDebugMode) {
        _logger.debug('Custom event: $name', tag: 'ANALYTICS');
      }
    } catch (e) {
      _logger.error('Failed to log custom event: $name',
          tag: 'ANALYTICS', error: e);
    }
  }

  /// Log app open
  Future<void> logAppOpen() async {
    try {
      await _safeAnalytics?.logAppOpen();
    } catch (e) {
      _logger.error('Failed to log app open', tag: 'ANALYTICS', error: e);
    }
  }
}
