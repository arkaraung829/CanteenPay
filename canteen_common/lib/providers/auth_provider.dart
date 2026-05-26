/// Auth Provider
///
/// Role-based authentication provider using Supabase Auth.
/// Manages authentication state and provides methods for login, logout,
/// profile loading, and role checking.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'safe_change_notifier.dart';

class AuthProvider extends ChangeNotifier with SafeChangeNotifierMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  // State
  Session? _session;
  UserModel? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;
  StreamSubscription<AuthState>? _authStateSubscription;

  // Getters
  Session? get session => _session;
  UserModel? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Clears the current error state.
  void clearError() {
    _error = null;
    safeNotifyListeners();
  }

  // Role checking getters
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isParent => _user?.isParent ?? false;
  bool get isSeller => _user?.isSeller ?? false;
  bool get isStudent => _user?.isStudent ?? false;
  bool get isCounterStaff => _user?.isCounterStaff ?? false;

  AuthProvider() {
    _initializeAuth();
  }

  /// Initialize auth state and listen for changes
  void _initializeAuth() {
    _checkSession();

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (_disposed) return;

      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed) {
        _session = session;
        _isAuthenticated = true;
        _error = null;
        _loadUserProfile();
        safeNotifyListeners();
      } else if (event == AuthChangeEvent.signedOut) {
        _session = null;
        _user = null;
        _isAuthenticated = false;
        safeNotifyListeners();
      } else if (event == AuthChangeEvent.userUpdated) {
        _loadUserProfile();
        safeNotifyListeners();
      }
    });
  }

  /// Check current session on startup
  Future<void> _checkSession() async {
    try {
      _isLoading = true;
      safeNotifyListeners();

      final session = _supabase.auth.currentSession;
      if (session != null) {
        _session = session;
        _isAuthenticated = true;
        await _loadUserProfile();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('AuthProvider: Failed to check session: $e');
    } finally {
      _isLoading = false;
      safeNotifyListeners();
    }
  }

  /// Reload user profile (call after profile update)
  Future<void> reloadProfile() async {
    await _loadUserProfile();
  }

  /// Load user profile from the profiles table
  Future<void> _loadUserProfile() async {
    try {
      final userId = _session?.user.id;
      if (userId == null) return;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        _user = UserModel.fromJson(response);
      } else {
        // Create a basic user from auth data
        _user = UserModel(
          id: userId,
          email: _session?.user.email,
          phone: _session?.user.phone,
        );
      }
      safeNotifyListeners();
    } catch (e) {
      debugPrint('AuthProvider: Failed to load user profile: $e');
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      safeNotifyListeners();

      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      safeNotifyListeners();
    }
  }

  /// Sign up with email, password, full name, and role
  Future<bool> signUp(
    String email,
    String password,
    String fullName,
    String role,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      safeNotifyListeners();

      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
        },
      );
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      safeNotifyListeners();
    }
  }

  /// Send OTP to phone number
  Future<bool> signInWithPhone(String phone) async {
    try {
      _isLoading = true;
      _error = null;
      safeNotifyListeners();

      await _supabase.auth.signInWithOtp(phone: phone);
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      safeNotifyListeners();
    }
  }

  /// Verify OTP code
  Future<bool> verifyOtp(String phone, String token, {String? fullName, String? role}) async {
    try {
      _isLoading = true;
      _error = null;
      safeNotifyListeners();

      await _supabase.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );

      // Update profile with name and role (trigger may have set defaults)
      if (fullName != null || role != null) {
        try {
          final userId = _supabase.auth.currentUser?.id;
          if (userId != null) {
            // Update profiles table directly
            final updates = <String, dynamic>{};
            if (fullName != null && fullName.isNotEmpty) updates['full_name'] = fullName;
            if (role != null && role.isNotEmpty) updates['role'] = role;
            if (updates.isNotEmpty) {
              await _supabase.from('profiles').update(updates).eq('id', userId);
            }
            // Also update auth metadata
            await _supabase.auth.updateUser(
              UserAttributes(data: {
                if (fullName != null) 'full_name': fullName,
                if (role != null) 'role': role,
              }),
            );
          }
        } catch (_) {}
      }

      // Reload profile to get correct role
      await _loadUserProfile();

      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      safeNotifyListeners();
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _isLoading = true;
      safeNotifyListeners();

      await _supabase.auth.signOut();
    } catch (e) {
      _error = e.toString();
      debugPrint('AuthProvider: Failed to sign out: $e');
    } finally {
      _isLoading = false;
      safeNotifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authStateSubscription?.cancel();
    super.dispose();
  }
}
