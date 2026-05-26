/// Session Service
///
/// Auto-logout on inactivity for CanteenPay.
/// Starts a timer that resets on user interaction.
/// After 15 minutes of inactivity, triggers Supabase sign out.
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logging_service.dart';

/// Service for session timeout / auto-logout
class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  final LoggingService _logger = LoggingService();

  Timer? _inactivityTimer;

  /// Default timeout: 15 minutes
  static const Duration defaultTimeout = Duration(minutes: 15);

  /// The timeout duration (can be overridden)
  Duration timeout = defaultTimeout;

  /// Callback fired when the session expires.
  /// The app should listen to this and navigate to the login screen.
  void Function()? onSessionExpired;

  /// Start the inactivity timer.
  /// Call this after the user logs in.
  void startTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(timeout, _onTimeout);
    _logger.debug(
        'Session timer started (${timeout.inMinutes} min)', tag: 'SESSION');
  }

  /// Reset the timer — call this on any user interaction.
  void resetTimer() {
    if (_inactivityTimer == null || !_inactivityTimer!.isActive) return;
    _inactivityTimer!.cancel();
    _inactivityTimer = Timer(timeout, _onTimeout);
  }

  /// Called when the inactivity timer fires
  Future<void> _onTimeout() async {
    _logger.info('Session timed out due to inactivity', tag: 'SESSION');

    try {
      await Supabase.instance.client.auth.signOut();
      _logger.info('User signed out due to session timeout', tag: 'SESSION');
    } catch (e) {
      _logger.error('Failed to sign out on session timeout',
          tag: 'SESSION', error: e);
    }

    onSessionExpired?.call();
  }

  /// Stop the timer and clean up.
  void dispose() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    onSessionExpired = null;
    _logger.debug('Session timer disposed', tag: 'SESSION');
  }
}
