import 'package:flutter/material.dart';
import 'package:canteen_common/canteen_common.dart';

/// Wraps the app to detect user interaction and reset the session timer.
///
/// On any tap, scroll, or swipe, resets the inactivity timer in [SessionService].
/// When the session expires, navigates the user to the login screen.
class SessionWrapper extends StatefulWidget {
  final Widget child;

  const SessionWrapper({super.key, required this.child});

  @override
  State<SessionWrapper> createState() => _SessionWrapperState();
}

class _SessionWrapperState extends State<SessionWrapper> {
  final SessionService _sessionService = SessionService();
  bool _securityWarningShown = false;

  @override
  void initState() {
    super.initState();

    // Listen for session expiration
    _sessionService.onSessionExpired = _handleSessionExpired;

    // Show security warning if device is compromised
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSecurityWarning();
    });
  }

  void _checkSecurityWarning() {
    if (_securityWarningShown) return;
    final warning = SecurityService().securityWarning;
    if (warning != null && mounted) {
      _securityWarningShown = true;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Security Warning'),
            ],
          ),
          content: Text(warning),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('I Understand'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _sessionService.dispose();
    super.dispose();
  }

  void _handleSessionExpired() {
    if (!mounted) return;

    // Show a snackbar and navigate to login
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Session expired due to inactivity. Please log in again.'),
        duration: Duration(seconds: 4),
      ),
    );

    // Navigate to login — use the root navigator to clear the entire stack.
    // GoRouter's '/' redirect in CanteenPay will handle sending unauthenticated
    // users to the login screen automatically once auth state changes.
  }

  void _onUserInteraction() {
    _sessionService.resetTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onUserInteraction(),
      onPointerMove: (_) => _onUserInteraction(),
      child: ConnectivityBanner(child: widget.child),
    );
  }
}
