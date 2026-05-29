/// Auth Provider
///
/// Role-based authentication provider using Supabase Auth.
/// Manages authentication state and provides methods for login, logout,
/// profile loading, and role checking.
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/phone_auth_service.dart';
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
        // Fill in email/phone from auth session if not in profile
        final authUser = _session?.user;
        if (authUser != null) {
          if ((_user!.email == null || _user!.email!.isEmpty) && authUser.email != null) {
            _user = _user!.copyWith(email: authUser.email);
          }
          if ((_user!.phone == null || _user!.phone!.isEmpty) && authUser.phone != null) {
            _user = _user!.copyWith(phone: authUser.phone);
          }
        }
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

  /// Sign in with Google (native Google Sign-In → Supabase ID token)
  Future<bool> signInWithGoogle() async {
    try {
      _isLoading = true;
      _error = null;
      safeNotifyListeners();

      // Web client ID from Google Cloud Console (canteenpay-a64a1 project)
      const webClientId = '1083173550425-oh4nuk1o8p9hbqicmksa0d5jonl6i5ch.apps.googleusercontent.com';

      final googleSignIn = GoogleSignIn(serverClientId: webClientId);

      // Sign out previous session
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        safeNotifyListeners();
        return false; // User cancelled
      }

      debugPrint('AuthProvider: Google account: ${googleUser.email}');

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        _error = 'Failed to get Google authentication token';
        return false;
      }

      // Sign into Supabase with Google ID token
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.session != null) {
        _session = response.session;
        _isAuthenticated = true;
        debugPrint('AuthProvider: Google sign-in successful, loading profile...');

        // Update profile with Google info
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          try {
            await _supabase.from('profiles').update({
              'full_name': googleUser.displayName ?? googleUser.email,
            }).eq('id', userId);
          } catch (_) {}
        }

        await _loadUserProfile();
        debugPrint('AuthProvider: Profile loaded: ${_user?.role} ${_user?.fullName}');

        // Auto-link by email
        final email = googleUser.email;
        if (email.isNotEmpty) {
          await _autoLinkParentByEmail(email);
          await _loadUserProfile();
        }

        return true;
      } else {
        _error = 'Sign-in failed. Please try again.';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('AuthProvider: Google sign-in error: $e');
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

  /// Send OTP to phone number via Firebase (not Supabase)
  /// Fire-and-forget: sendOTP triggers callbacks asynchronously.
  /// Always returns true — OTP screen shows immediately.
  Future<bool> signInWithPhone(String phone, {PhoneCountry? country}) async {
    _error = null;
    safeNotifyListeners();

    try {
      await PhoneAuthService().sendOTP(phone, country: country);
      final error = PhoneAuthService().lastError;
      if (error != null) {
        _error = error;
        return false;
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  /// Verify OTP via Firebase, then sign into Supabase.
  ///
  /// Firebase handles SMS delivery and code verification.
  /// After verification, we create/sign-in a Supabase user using a
  /// deterministic email+password derived from the phone number.
  Future<bool> verifyOtp(String phone, String token, {String? fullName, String? role, PhoneCountry? country}) async {
    _isLoading = true;
    _error = null;
    safeNotifyListeners();

    try {
      // 1. Verify OTP with Firebase
      final result = await PhoneAuthService().verifyOTP(token);
      if (!result.success) {
        _error = result.error;
        return false;
      }

      // 2. Sign into Supabase with phone-based credentials
      final normalizedPhone = PhoneAuthService().formatPhone(
        phone,
        country ?? PhoneAuthService.defaultCountry,
      );
      // Create clean email from phone digits only
      final phoneDigits = normalizedPhone.replaceAll(RegExp(r'[^\d]'), '');
      final fakeEmail = 'phone$phoneDigits@canteenpay.com';
      final password = 'cp_${phoneDigits}_2026';
      debugPrint('AuthProvider: Supabase email=$fakeEmail');

      // Try sign in first (existing user)
      try {
        await _supabase.auth.signInWithPassword(
          email: fakeEmail,
          password: password,
        );
      } on AuthException {
        // User doesn't exist — sign up
        await _supabase.auth.signUp(
          email: fakeEmail,
          password: password,
          data: {
            'full_name': fullName ?? 'User',
            'role': role ?? 'parent',
            'phone': normalizedPhone,
          },
        );
        // Sign in after signup to establish session
        await _supabase.auth.signInWithPassword(
          email: fakeEmail,
          password: password,
        );
      }

      // 3. Update profile with phone number and metadata
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final updates = <String, dynamic>{
          'phone': normalizedPhone,
        };
        if (fullName != null && fullName.isNotEmpty) {
          updates['full_name'] = fullName;
        }
        if (role != null && role.isNotEmpty) {
          updates['role'] = role;
        }
        if (updates.length > 1) {
          // More than just phone
          await _supabase.from('profiles').update(updates).eq('id', userId);
        } else {
          await _supabase
              .from('profiles')
              .update({'phone': normalizedPhone}).eq('id', userId);
        }
      }

      // 4. Sign out of Firebase (we only use it for OTP verification)
      await firebase.FirebaseAuth.instance.signOut();

      // 5. Load profile and auto-link
      await _loadUserProfile();
      if (_user?.role == 'parent' && normalizedPhone.isNotEmpty) {
        _autoLinkParentByPhone(normalizedPhone);
      }
      if (_user?.role == 'seller' && normalizedPhone.isNotEmpty) {
        _autoLinkSellerByPhone(normalizedPhone);
      }

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      safeNotifyListeners();
    }
  }

  /// Auto-link parent to students by matching phone number.
  /// Runs silently in the background after OTP login.
  Future<void> _autoLinkParentByPhone(String phone) async {
    try {
      // Normalize phone: strip leading 0, ensure +95 prefix
      String normalized = phone.replaceAll(RegExp(r'\s+'), '');
      if (normalized.startsWith('0')) {
        normalized = '+95${normalized.substring(1)}';
      } else if (!normalized.startsWith('+')) {
        normalized = '+$normalized';
      }

      // Query students whose parent_phone matches
      final students = await _supabase
          .from('students')
          .select('id')
          .eq('parent_phone', normalized);

      if ((students as List).isEmpty || _user == null) return;

      final parentId = _user!.id;

      for (final student in students) {
        final studentId = student['id'] as String;

        final existing = await _supabase
            .from('parent_student_links')
            .select('id')
            .eq('parent_id', parentId)
            .eq('student_id', studentId)
            .maybeSingle();

        if (existing == null) {
          await _supabase.from('parent_student_links').insert({
            'parent_id': parentId,
            'student_id': studentId,
          });
        }
      }
    } catch (e) {
      debugPrint('AuthProvider: Auto-link by phone failed: $e');
    }
  }

  /// Auto-link seller to canteen_sellers record and school by phone.
  /// When admin pre-creates a seller with a phone number, and the seller
  /// later signs up via OTP, this links them automatically.
  Future<void> _autoLinkSellerByPhone(String phone) async {
    try {
      String normalized = phone.replaceAll(RegExp(r'\s+'), '');
      if (normalized.startsWith('0')) {
        normalized = '+95${normalized.substring(1)}';
      } else if (!normalized.startsWith('+')) {
        normalized = '+$normalized';
      }

      // Find canteen_sellers record matching this phone
      final sellers = await _supabase
          .from('canteen_sellers')
          .select('id, school_id, profile_id')
          .eq('phone', normalized);

      if ((sellers as List).isEmpty || _user == null) return;

      final userId = _user!.id;

      for (final seller in sellers) {
        final sellerId = seller['id'] as String;
        final schoolId = seller['school_id'] as String?;
        final existingProfileId = seller['profile_id'] as String?;

        // Link this seller record to the user's profile
        if (existingProfileId == null || existingProfileId != userId) {
          await _supabase
              .from('canteen_sellers')
              .update({'profile_id': userId})
              .eq('id', sellerId);
        }

        // Also update the user's profile school_id to match the seller's school
        if (schoolId != null && _user?.schoolId != schoolId) {
          await _supabase
              .from('profiles')
              .update({'school_id': schoolId})
              .eq('id', userId);
        }
      }

      // Reload profile to pick up school_id change
      await _loadUserProfile();
    } catch (e) {
      debugPrint('AuthProvider: Auto-link seller by phone failed: $e');
    }
  }

  /// Auto-link parent to students by matching email address.
  Future<void> _autoLinkParentByEmail(String email) async {
    try {
      final students = await _supabase
          .from('students')
          .select('id')
          .eq('parent_email', email.toLowerCase());

      if ((students as List).isEmpty || _user == null) return;

      final parentId = _user!.id;

      for (final student in students) {
        final studentId = student['id'] as String;

        final existing = await _supabase
            .from('parent_student_links')
            .select('id')
            .eq('parent_id', parentId)
            .eq('student_id', studentId)
            .maybeSingle();

        if (existing == null) {
          await _supabase.from('parent_student_links').insert({
            'parent_id': parentId,
            'student_id': studentId,
          });
        }
      }
    } catch (e) {
      debugPrint('AuthProvider: Auto-link by email failed: $e');
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
