/// Biometric Service
///
/// Face ID / Touch ID authentication for CanteenPay.
/// Used to protect sensitive actions like large transactions or settings changes.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'logging_service.dart';

/// Service for biometric authentication (Face ID / Touch ID)
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final LoggingService _logger = LoggingService();

  // Cache to avoid repeated checks
  bool? _canCheckBiometrics;
  List<BiometricType>? _availableBiometrics;

  /// Check if biometric auth is available on this device
  Future<bool> isAvailable() async {
    if (_canCheckBiometrics != null) return _canCheckBiometrics!;

    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      _canCheckBiometrics = canCheck && isSupported;
      return _canCheckBiometrics!;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('[BiometricService] Error checking biometrics: $e');
      }
      _canCheckBiometrics = false;
      return false;
    }
  }

  /// Trigger biometric authentication prompt
  ///
  /// [reason] is shown to the user (e.g., "Verify to complete purchase")
  /// Returns true if authentication was successful
  Future<bool> authenticate({String reason = 'Verify your identity'}) async {
    if (!await isAvailable()) {
      _logger.debug('Biometrics not available on this device',
          tag: 'BIOMETRIC');
      return false;
    }

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );

      if (kDebugMode) {
        debugPrint('[BiometricService] Authentication result: $authenticated');
      }

      return authenticated;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[BiometricService] Authentication error: ${e.code} - ${e.message}');
      }

      // Handle specific error codes
      switch (e.code) {
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return false;
        default:
          return false;
      }
    }
  }

  /// Get the type of biometric available: 'face', 'fingerprint', or 'none'
  Future<String> getBiometricType() async {
    if (!await isAvailable()) return 'none';

    try {
      _availableBiometrics ??= await _localAuth.getAvailableBiometrics();
      final biometrics = _availableBiometrics!;

      if (biometrics.contains(BiometricType.face)) return 'face';
      if (biometrics.contains(BiometricType.fingerprint)) return 'fingerprint';
      if (biometrics.contains(BiometricType.strong)) return 'fingerprint';
      if (biometrics.contains(BiometricType.weak)) return 'fingerprint';
      return 'none';
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[BiometricService] Error getting biometric type: $e');
      }
      return 'none';
    }
  }

  /// Clear cached values (useful after settings change)
  void clearCache() {
    _canCheckBiometrics = null;
    _availableBiometrics = null;
  }
}
