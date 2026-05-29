/// Phone Authentication Service using Firebase
///
/// Handles phone number verification with OTP via Firebase Auth.
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
  String? _lastError;
  bool _codeSent = false;
  bool _verificationInProgress = false;

  String? get verificationId => _verificationId;
  bool get codeSent => _codeSent;
  String? get lastError => _lastError;

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

  static PhoneCountry get defaultCountry => supportedCountries.first;

  /// Format phone number to international format
  String formatPhone(String phone, PhoneCountry country) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+') && cleaned.length >= 10) return cleaned;
    if (cleaned.startsWith('+')) cleaned = cleaned.substring(1);

    if (country.code == 'MM') {
      if (cleaned.startsWith('959') && cleaned.length >= 11) return '+$cleaned';
      if (cleaned.startsWith('09')) return '+959${cleaned.substring(2)}';
      if (cleaned.startsWith('9') && cleaned.length >= 7) return '+959${cleaned.substring(1)}';
      return '+959$cleaned';
    }

    if (country.code == 'CA') {
      if (cleaned.startsWith('1') && cleaned.length == 11) return '+$cleaned';
      if (cleaned.length == 10) return '+1$cleaned';
      return '+1$cleaned';
    }

    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
    return '${country.dialCode}$cleaned';
  }

  /// Validate phone number format
  bool isValidPhone(String phone, PhoneCountry country) {
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (country.code == 'MM') {
      if (digits.startsWith('959')) digits = digits.substring(2);
      if (digits.startsWith('09')) digits = digits.substring(1);
    } else if (country.code == 'CA') {
      if (digits.startsWith('1') && digits.length == 11) digits = digits.substring(1);
    } else {
      if (digits.startsWith('0')) digits = digits.substring(1);
    }

    if (digits.isEmpty) return false;
    return digits.length >= country.minLength && digits.length <= country.maxLength;
  }

  /// Send OTP — fire and forget, callbacks update state
  Future<void> sendOTP(String phoneNumber, {PhoneCountry? country}) async {
    final selectedCountry = country ?? defaultCountry;
    String formattedPhone = formatPhone(phoneNumber, selectedCountry);

    debugPrint('PhoneAuthService: sending OTP to $formattedPhone');

    if (!isValidPhone(phoneNumber, selectedCountry)) {
      _lastError = 'Invalid phone number format';
      return;
    }

    // Reset state
    _codeSent = false;
    _lastError = null;
    _verificationInProgress = true;

    // iOS: ensure APNS token is ready
    if (Platform.isIOS) {
      try {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission();
        final token = await messaging.getAPNSToken();
        debugPrint('PhoneAuthService: APNS token: ${token != null ? "YES" : "NULL"}');
        if (token == null) {
          await Future.delayed(const Duration(seconds: 2));
          final retry = await messaging.getAPNSToken();
          debugPrint('PhoneAuthService: APNS retry: ${retry != null ? "YES" : "NULL"}');
        }
      } catch (e) {
        debugPrint('PhoneAuthService: APNS error: $e');
      }
    }

    debugPrint('PhoneAuthService: calling verifyPhoneNumber...');

    // Don't await — callbacks will fire asynchronously (even after reCAPTCHA return)
    _auth.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      timeout: const Duration(seconds: 120),
      verificationCompleted: (PhoneAuthCredential credential) async {
        debugPrint('PhoneAuthService: auto-verified');
        _codeSent = true;
        _verificationInProgress = false;
        // Auto-sign in (Android)
        try {
          await _auth.signInWithCredential(credential);
        } catch (_) {}
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('PhoneAuthService: verification failed: ${e.code} ${e.message}');
        _lastError = _getErrorMessage(e);
        _verificationInProgress = false;
      },
      codeSent: (String verificationId, int? resendToken) {
        debugPrint('PhoneAuthService: code sent! verificationId=$verificationId');
        _verificationId = verificationId;
        _resendToken = resendToken;
        _codeSent = true;
        _verificationInProgress = false;
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('PhoneAuthService: auto-retrieval timeout');
        _verificationId = verificationId;
      },
      forceResendingToken: _resendToken,
    );
  }

  /// Verify OTP code
  Future<PhoneAuthResult> verifyOTP(String otp) async {
    if (_verificationId == null) {
      return PhoneAuthResult(
        success: false,
        error: 'Verification session expired. Please request a new code.',
      );
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        return PhoneAuthResult(success: true, user: userCredential.user, credential: credential);
      }
      return PhoneAuthResult(success: false, error: 'Verification failed.');
    } on FirebaseAuthException catch (e) {
      return PhoneAuthResult(success: false, error: _getErrorMessage(e));
    } catch (e) {
      return PhoneAuthResult(success: false, error: 'Verification failed. Please try again.');
    }
  }

  /// Reset state
  void reset() {
    _verificationId = null;
    _resendToken = null;
    _codeSent = false;
    _lastError = null;
    _verificationInProgress = false;
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number': return 'Invalid phone number format.';
      case 'too-many-requests': return 'Too many attempts. Please wait and try again.';
      case 'quota-exceeded': return 'SMS quota exceeded. Please try again later.';
      case 'invalid-verification-code': return 'Invalid code. Please check and try again.';
      case 'session-expired': return 'Session expired. Please request a new code.';
      case 'network-request-failed': return 'Network error. Please check your connection.';
      default: return e.message ?? 'Verification failed. Please try again.';
    }
  }
}

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
