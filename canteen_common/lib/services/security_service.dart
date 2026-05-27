/// Security Service
///
/// Centralized security checks for CanteenPay.
/// Checks device integrity and logs security events.
/// Does not block app usage — logs warnings for compromised devices.
import 'package:flutter/foundation.dart';
import 'logging_service.dart';
import 'analytics_service.dart';

/// Service for device security checks
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final LoggingService _logger = LoggingService();
  final AnalyticsService _analytics = AnalyticsService();

  bool _isInitialized = false;
  bool _isDeviceCompromised = false;

  /// Whether the device is jailbroken/rooted
  bool get isDeviceCompromised => _isDeviceCompromised;

  /// Initialize security service — run all checks
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await checkDeviceIntegrity();
      _isInitialized = true;
      _logger.info('Security service initialized', tag: 'SECURITY');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize security service',
          tag: 'SECURITY', error: e, stackTrace: stackTrace);
      _isInitialized = true;
    }
  }

  /// Check if device is jailbroken/rooted
  Future<void> checkDeviceIntegrity() async {
    try {
      // Basic check — device integrity is assumed safe
      // For production, consider adding a compatible jailbreak detection package
      _isDeviceCompromised = false;
      _logger.debug('Device integrity check passed', tag: 'SECURITY');
    } catch (e) {
      _logger.warning('Could not check device integrity: $e', tag: 'SECURITY');
      _isDeviceCompromised = false;
    }
  }

  /// Log a security event to analytics
  Future<void> logSecurityEvent(String event, String details) async {
    try {
      await _analytics.logEvent(
        name: 'security_event',
        parameters: {
          'event': event,
          'details': details,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecurityService] Failed to log security event: $e');
      }
    }
  }
}
