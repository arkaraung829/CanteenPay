/// Security Service
///
/// Centralized security checks for Paynow MM.
/// Detects compromised devices (jailbreak/root) and enforces security policies.
/// Financial apps should warn users on compromised devices.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'logging_service.dart';
import 'analytics_service.dart';

/// Threat level for the current device
enum SecurityThreatLevel {
  none,
  low, // Possible emulator or debug build
  high, // Jailbroken/rooted device
  development, // Debug mode — skip checks
}

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final LoggingService _logger = LoggingService();
  final AnalyticsService _analytics = AnalyticsService();

  bool _isInitialized = false;
  bool _isDeviceCompromised = false;
  SecurityThreatLevel _threatLevel = SecurityThreatLevel.none;
  DateTime? _lastCheck;

  /// Whether the device is jailbroken/rooted
  bool get isDeviceCompromised => _isDeviceCompromised;

  /// Current threat level
  SecurityThreatLevel get threatLevel => _threatLevel;

  /// Initialize security service — run all checks
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await checkDeviceIntegrity();
      _isInitialized = true;
      _logger.info('Security service initialized, threat: $_threatLevel',
          tag: 'SECURITY');
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize security service',
          tag: 'SECURITY', error: e, stackTrace: stackTrace);
      _isInitialized = true;
    }
  }

  /// Check if device is jailbroken/rooted
  /// Re-checks if last check was more than 30 minutes ago
  Future<void> checkDeviceIntegrity() async {
    // Skip in debug mode
    if (kDebugMode) {
      _threatLevel = SecurityThreatLevel.development;
      _isDeviceCompromised = false;
      return;
    }

    // Cache check for 30 minutes
    if (_lastCheck != null &&
        DateTime.now().difference(_lastCheck!).inMinutes < 30) {
      return;
    }

    try {
      bool compromised = false;

      if (Platform.isAndroid) {
        compromised = await _checkAndroidRoot();
      } else if (Platform.isIOS) {
        compromised = await _checkiOSJailbreak();
      }

      _isDeviceCompromised = compromised;
      _threatLevel =
          compromised ? SecurityThreatLevel.high : SecurityThreatLevel.none;
      _lastCheck = DateTime.now();

      if (compromised) {
        _logger.warning('Compromised device detected', tag: 'SECURITY');
        await logSecurityEvent(
            'compromised_device', Platform.operatingSystem);
      }
    } catch (e) {
      _logger.warning('Device integrity check error: $e', tag: 'SECURITY');
      _isDeviceCompromised = false;
      _threatLevel = SecurityThreatLevel.low;
      _lastCheck = DateTime.now();
    }
  }

  /// Check for common Android root indicators
  Future<bool> _checkAndroidRoot() async {
    try {
      // Check for common root management apps and su binary paths
      const suspiciousPaths = [
        '/system/app/Superuser.apk',
        '/system/xbin/su',
        '/system/bin/su',
        '/sbin/su',
        '/data/local/xbin/su',
        '/data/local/bin/su',
        '/system/sd/xbin/su',
        '/system/bin/failsafe/su',
        '/data/local/su',
      ];

      for (final path in suspiciousPaths) {
        if (await File(path).exists()) {
          return true;
        }
      }

      // Check for root management packages via shell
      try {
        final result = await Process.run('which', ['su']);
        if (result.exitCode == 0) return true;
      } catch (_) {}

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check for common iOS jailbreak indicators
  Future<bool> _checkiOSJailbreak() async {
    try {
      const suspiciousPaths = [
        '/Applications/Cydia.app',
        '/Applications/Sileo.app',
        '/Library/MobileSubstrate/MobileSubstrate.dylib',
        '/bin/bash',
        '/usr/sbin/sshd',
        '/etc/apt',
        '/private/var/lib/apt',
        '/usr/bin/ssh',
      ];

      for (final path in suspiciousPaths) {
        if (await File(path).exists()) {
          return true;
        }
      }

      // Check if app can write outside sandbox
      try {
        final file = File('/private/jailbreak_test');
        await file.writeAsString('test');
        await file.delete();
        return true; // Should not be able to write here
      } catch (_) {
        // Expected — device is not jailbroken
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Check if running on an emulator
  bool get isEmulator {
    if (kDebugMode) return false; // Don't warn in debug
    if (Platform.isAndroid) {
      // Basic heuristic — would need device_info_plus for full check
      return Platform.environment.containsKey('ANDROID_EMULATOR');
    }
    return false;
  }

  /// Verify HTTPS is being used for a URL
  bool isSecureUrl(String url) {
    return url.startsWith('https://');
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

  /// Get a user-friendly warning message for compromised devices
  String? get securityWarning {
    switch (_threatLevel) {
      case SecurityThreatLevel.high:
        return 'This device may be compromised. For your financial safety, '
            'we recommend using an unmodified device.';
      case SecurityThreatLevel.low:
        return 'We could not verify device security. Please be cautious.';
      case SecurityThreatLevel.none:
      case SecurityThreatLevel.development:
        return null;
    }
  }
}
