/// Secure Storage Service
///
/// Uses iOS Keychain and Android Keystore for encrypted credential storage.
/// Replaces SharedPreferences for sensitive data like auth tokens.
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService._();
  static final SecureStorageService _instance = SecureStorageService._();
  static SecureStorageService get instance => _instance;

  static const _keyAuthToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyUserData = 'user_data';
  static const _keyPinHash = 'pin_hash';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ---------------------------------------------------------------------------
  // Auth tokens
  // ---------------------------------------------------------------------------

  Future<void> storeAuthToken(String token) async {
    try {
      await _storage.write(key: _keyAuthToken, value: token);
    } catch (e) {
      debugPrint('SecureStorage: failed to store auth token: $e');
    }
  }

  Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: _keyAuthToken);
    } catch (e) {
      debugPrint('SecureStorage: failed to read auth token: $e');
      return null;
    }
  }

  Future<void> deleteAuthToken() async {
    try {
      await _storage.delete(key: _keyAuthToken);
    } catch (e) {
      debugPrint('SecureStorage: failed to delete auth token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Refresh tokens
  // ---------------------------------------------------------------------------

  Future<void> storeRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
    } catch (e) {
      debugPrint('SecureStorage: failed to store refresh token: $e');
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      debugPrint('SecureStorage: failed to read refresh token: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // User data (JSON string)
  // ---------------------------------------------------------------------------

  Future<void> storeUserData(String jsonData) async {
    try {
      await _storage.write(key: _keyUserData, value: jsonData);
    } catch (e) {
      debugPrint('SecureStorage: failed to store user data: $e');
    }
  }

  Future<String?> getUserData() async {
    try {
      return await _storage.read(key: _keyUserData);
    } catch (e) {
      debugPrint('SecureStorage: failed to read user data: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // PIN hash storage
  // ---------------------------------------------------------------------------

  Future<void> storePinHash(String hash) async {
    try {
      await _storage.write(key: _keyPinHash, value: hash);
    } catch (e) {
      debugPrint('SecureStorage: failed to store pin hash: $e');
    }
  }

  Future<String?> getPinHash() async {
    try {
      return await _storage.read(key: _keyPinHash);
    } catch (e) {
      debugPrint('SecureStorage: failed to read pin hash: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Generic key-value
  // ---------------------------------------------------------------------------

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStorage: failed to write $key: $e');
    }
  }

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('SecureStorage: failed to read $key: $e');
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureStorage: failed to delete $key: $e');
    }
  }

  /// Clear all secure storage (use on sign-out)
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('SecureStorage: failed to clear all: $e');
    }
  }
}
