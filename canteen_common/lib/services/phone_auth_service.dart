/// Phone Authentication Service using Firebase
///
/// Handles phone number verification with OTP via Firebase Auth.
/// CanteenPay uses Firebase only for OTP delivery/verification,
/// then bridges to Supabase for session management.
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Supported countries — Myanmar only for CanteenPay
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
  ];

  /// Get default country (Myanmar)
  static PhoneCountry get defaultCountry => supportedCountries.first;

  /// Format phone number to international format
  String formatPhone(String phone, PhoneCountry country) {
    // Remove spaces, dashes, parentheses, and other characters
    String cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // If already has full country code with +
    if (cleaned.startsWith(country.dialCode)) {
      return cleaned;
    }

    // If starts with country code without +
    String dialCodeWithoutPlus = country.dialCode.substring(1);
    if (cleaned.startsWith(dialCodeWithoutPlus) &&
        cleaned.length > country.maxLength) {
      return '+$cleaned';
    }

    // Handle Myanmar-specific formatting (09 -> 9)
    if (country.code == 'MM') {
      if (cleaned.startsWith('09')) {
        cleaned = cleaned.substring(1); // Remove leading 0
      }
      if (cleaned.startsWith('9')) {
        return '+959${cleaned.substring(1)}';
      }
      return '+959$cleaned';
    }

    // Handle other countries - remove leading 0 if present
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    return '${country.dialCode}$cleaned';
  }

  /// Validate phone number format
  bool isValidPhone(String phone, PhoneCountry country) {
    // Strip everything except digits
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Remove country code prefix if present (e.g., 959 → 9)
    if (digits.startsWith('959')) {
      digits = digits.substring(2); // keep the 9
    }

    // Handle 09 prefix → 9
    if (digits.startsWith('09')) {
      digits = digits.substring(1);
    }

    // Must be digits only
    if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) {
      return false;
    }

    // Myanmar numbers: 9xxxxxxxx (8-10 digits after 9)
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

      if (!isValidPhone(phoneNumber, selectedCountry)) {
        return PhoneAuthResult(
          success: false,
          error: 'Invalid phone number format for ${selectedCountry.name}',
        );
      }

      final completer = Completer<PhoneAuthResult>();

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
      _isVerifying = false;
      if (kDebugMode) {
        debugPrint('PhoneAuthService: sendOTP error: $e');
      }
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
