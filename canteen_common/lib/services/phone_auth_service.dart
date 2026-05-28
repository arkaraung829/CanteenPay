/// Phone Authentication Service using Firebase
///
/// Handles phone number verification with OTP via Firebase Auth.
/// CanteenPay uses Firebase only for OTP delivery/verification,
/// then bridges to Supabase for session management.
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Supported country for phone authentication
class PhoneCountry {
  final String name;
  final String code;
  final String dialCode;
  final String flag;
  final String placeholder;
  final int minLength;
  final int maxLength;

  const PhoneCountry({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
    required this.placeholder,
    required this.minLength,
    required this.maxLength,
  });
}

class PhoneAuthService {
  static final PhoneAuthService _instance = PhoneAuthService._internal();
  factory PhoneAuthService() => _instance;
  PhoneAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;
  bool _isVerifying = false;

  bool get isVerifying => _isVerifying;
  String? get verificationId => _verificationId;

  /// Supported countries
  static const List<PhoneCountry> supportedCountries = [
    PhoneCountry(
      name: 'Myanmar',
      code: 'MM',
      dialCode: '+95',
      flag: '\u{1F1F2}\u{1F1F2}',
      placeholder: '09xxxxxxxxx',
      minLength: 7,
      maxLength: 11,
    ),
    PhoneCountry(
      name: 'Canada',
      code: 'CA',
      dialCode: '+1',
      flag: '\u{1F1E8}\u{1F1E6}',
      placeholder: '(xxx) xxx-xxxx',
      minLength: 10,
      maxLength: 10,
    ),
  ];

  /// Get default country (Myanmar)
  static PhoneCountry get defaultCountry => supportedCountries.first;

  /// Format phone number to international format
  String formatPhone(String phone, PhoneCountry country) {
    // Remove everything except digits and +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Already has + with country code
    if (cleaned.startsWith('+') && cleaned.length >= 10) {
      return cleaned;
    }

    // Strip + for reprocessing
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    if (country.code == 'MM') {
      // Myanmar: 959xxx, 09xxx, 9xxx
      if (cleaned.startsWith('959') && cleaned.length >= 11) return '+$cleaned';
      if (cleaned.startsWith('09')) return '+959${cleaned.substring(2)}';
      if (cleaned.startsWith('9') && cleaned.length >= 7) return '+959${cleaned.substring(1)}';
      return '+959$cleaned';
    }

    if (country.code == 'CA') {
      // Canada: 1xxx, xxx (10 digits)
      if (cleaned.startsWith('1') && cleaned.length == 11) return '+$cleaned';
      if (cleaned.length == 10) return '+1$cleaned';
      return '+1$cleaned';
    }

    // Generic: prepend dial code
    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
    return '${country.dialCode}$cleaned';
  }

  /// Legacy method kept for compatibility
  String formatPhoneForDisplay(String phone, PhoneCountry country) {
    return formatPhone(phone, country);
  }

  /// Validate phone number format
  bool isValidPhone(String phone, PhoneCountry country) {
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (country.code == 'MM') {
      // Strip country code
      if (digits.startsWith('959')) digits = digits.substring(2);
      if (digits.startsWith('09')) digits = digits.substring(1);
    } else if (country.code == 'CA') {
      // Strip country code
      if (digits.startsWith('1') && digits.length == 11) digits = digits.substring(1);
    } else {
      if (digits.startsWith('0')) digits = digits.substring(1);
    }

    if (digits.isEmpty) return false;

    return digits.length >= country.minLength &&
        digits.length <= country.maxLength;
  }

  /// Send OTP to phone number via Firebase
  Future<PhoneAuthResult> sendOTP(String phoneNumber,
      {PhoneCountry? country}) async {
    try {
      _isVerifying = true;
      final selectedCountry = country ?? defaultCountry;
      String formattedPhone = formatPhone(phoneNumber, selectedCountry);

      debugPrint('PhoneAuthService: sending OTP to $formattedPhone');

      if (!isValidPhone(phoneNumber, selectedCountry)) {
        return PhoneAuthResult(
          success: false,
          error: 'Invalid phone number format for ${selectedCountry.name}',
        );
      }

      // iOS: Ensure APNS token is available before phone auth
      if (Platform.isIOS) {
        debugPrint('PhoneAuthService: requesting APNS token...');
        try {
          // Request notification permission first
          final messaging = FirebaseMessaging.instance;
          final settings = await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );
          debugPrint('PhoneAuthService: notification permission: ${settings.authorizationStatus}');

          // Get APNS token and set it on Firebase Auth
          String? apnsToken = await messaging.getAPNSToken();
          debugPrint('PhoneAuthService: APNS token: ${apnsToken != null ? "available" : "NULL"}');

          if (apnsToken == null) {
            await Future.delayed(const Duration(seconds: 3));
            apnsToken = await messaging.getAPNSToken();
            debugPrint('PhoneAuthService: APNS token retry: ${apnsToken != null ? "available" : "still NULL"}');
          }

          if (apnsToken == null) {
            _isVerifying = false;
            return PhoneAuthResult(
              success: false,
              error: 'Push notifications not available. Please enable notifications in Settings and try again.',
            );
          }

          // App verification enabled — uses silent push for real SMS delivery
          debugPrint('PhoneAuthService: calling verifyPhoneNumber...');
        } catch (e) {
          debugPrint('PhoneAuthService: APNS setup error: $e');
        }
      }

      final completer = Completer<PhoneAuthResult>();

      try {
        await _auth.verifyPhoneNumber(
          phoneNumber: formattedPhone,
          timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          if (!completer.isCompleted) {
            completer.complete(PhoneAuthResult(
              success: true,
              autoVerified: true,
              credential: credential,
            ));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          _isVerifying = false;
          if (!completer.isCompleted) {
            completer.complete(PhoneAuthResult(
              success: false,
              error: _getErrorMessage(e),
            ));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete(PhoneAuthResult(
              success: true,
              verificationId: verificationId,
            ));
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        forceResendingToken: _resendToken,
      );

      return await completer.future;
      } catch (e) {
        // Firebase Phone Auth crashed — likely APNS token not ready
        _isVerifying = false;
        debugPrint('PhoneAuthService: verifyPhoneNumber crashed: $e');
        if (!completer.isCompleted) {
          completer.complete(PhoneAuthResult(
            success: false,
            error: 'Phone verification failed. Please ensure notifications are enabled and try again.',
          ));
        }
        return await completer.future;
      }
    } catch (e) {
      _isVerifying = false;
      debugPrint('PhoneAuthService: sendOTP error: $e');
      return PhoneAuthResult(
        success: false,
        error: 'Failed to send OTP. Please try again.',
      );
    }
  }

  /// Verify OTP code via Firebase
  Future<PhoneAuthResult> verifyOTP(String otp) async {
    try {
      if (_verificationId == null) {
        return PhoneAuthResult(
          success: false,
          error: 'Verification session expired. Please request a new code.',
        );
      }

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      // Sign in with credential to verify the code
      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      _isVerifying = false;

      if (userCredential.user != null) {
        return PhoneAuthResult(
          success: true,
          user: userCredential.user,
          credential: credential,
        );
      } else {
        return PhoneAuthResult(
          success: false,
          error: 'Verification failed. Please try again.',
        );
      }
    } on FirebaseAuthException catch (e) {
      _isVerifying = false;
      return PhoneAuthResult(
        success: false,
        error: _getErrorMessage(e),
      );
    } catch (e) {
      _isVerifying = false;
      return PhoneAuthResult(
        success: false,
        error: 'Verification failed. Please try again.',
      );
    }
  }

  /// Resend OTP
  Future<PhoneAuthResult> resendOTP(String phoneNumber,
      {PhoneCountry? country}) async {
    _verificationId = null;
    return sendOTP(phoneNumber, country: country);
  }

  /// Get user-friendly error message
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please check and try again.';
      case 'session-expired':
        return 'Verification session expired. Please request a new code.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'Verification failed. Please try again.';
    }
  }

  /// Reset verification state
  void reset() {
    _verificationId = null;
    _resendToken = null;
    _isVerifying = false;
  }
}

/// Result class for phone auth operations
class PhoneAuthResult {
  final bool success;
  final String? error;
  final String? verificationId;
  final bool autoVerified;
  final User? user;
  final PhoneAuthCredential? credential;

  PhoneAuthResult({
    required this.success,
    this.error,
    this.verificationId,
    this.autoVerified = false,
    this.user,
    this.credential,
  });
}
