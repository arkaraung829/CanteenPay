/// Connectivity Banner
///
/// Shows an animated offline/online banner at the top of the screen.
/// Displays "No internet connection" when offline, briefly shows
/// "Back online" when reconnected, then auto-hides.
import 'dart:async';
import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late final ConnectivityService _connectivity;
  StreamSubscription<bool>? _subscription;
  bool _isOnline = true;
  bool _showBackOnline = false;

  @override
  void initState() {
    super.initState();
    _connectivity = ConnectivityService();
    _isOnline = _connectivity.isOnline;

    _subscription = _connectivity.onConnectivityChangedBool.listen((online) {
      if (!mounted) return;
      if (online && !_isOnline) {
        // Just came back online — show brief "Back online" message
        setState(() {
          _isOnline = true;
          _showBackOnline = true;
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showBackOnline = false);
        });
      } else if (!online) {
        setState(() {
          _isOnline = false;
          _showBackOnline = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Offline banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: !_isOnline ? 32 : (_showBackOnline ? 32 : 0),
          color: !_isOnline ? Colors.red.shade700 : Colors.green.shade600,
          child: Center(
            child: Text(
              !_isOnline ? 'No internet connection' : 'Back online',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
