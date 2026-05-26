/// Security Service
///
/// Centralized security checks for CanteenPay.
/// Checks device integrity (jailbreak/root detection) and logs security events.
/// Does not block app usage — logs warnings for compromised devices.
import 'package:flutter/foundation.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';
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
      // Don't block app if security check fails
      _isInitialized = true;
    }
  }

  /// Check if device is jailbroken/rooted
  Future<void> checkDeviceIntegrity() async {
    try {
      _isDeviceCompromised = await FlutterJailbreakDetection.jailbroken;

      if (_isDeviceCompromised) {
        _logger.warning(
            'Device integrity check FAILED — device appears to be jailbroken/rooted',
            tag: 'SECURITY');
        await logSecurityEvent(
            'device_compromised', 'Jailbroken/rooted device detected');
      } else {
        _logger.debug('Device integrity check passed', tag: 'SECURITY');
      }
    } catch (e) {
      // Some devices/emulators may not support jailbreak detection
      _logger.warning('Could not check device integrity: $e',
          tag: 'SECURITY');
      _isDeviceCompromised = false;
    }
  }

  /// Log a security event to analytics
  Future<void> logSecurityEvent(String event, String details) async {
    try {
      await _analytics.logEvent(
        name: 'security_event',
        parameters: {
          'event_type': event,
          'details': details,
        },
      );
      if (kDebugMode) {
        _logger.debug('Security event: $event — $details', tag: 'SECURITY');
      }
    } catch (e) {
      _logger.error('Failed to log security event',
          tag: 'SECURITY', error: e);
    }
  }
}
