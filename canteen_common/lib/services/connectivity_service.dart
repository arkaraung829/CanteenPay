/// Connectivity Service
///
/// Singleton wrapping connectivity_plus to check network status.
/// Exposes a boolean stream and triggers offline-action replay on reconnect.
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'offline_action_queue.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();

  /// Whether the device currently has network connectivity.
  bool get isOnline => _isOnline;

  /// Stream that emits `true`/`false` whenever connectivity changes.
  Stream<bool> get onConnectivityChangedBool => _onlineController.stream;

  /// Raw stream from connectivity_plus.
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Initialize and start listening for connectivity changes.
  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);

      _onlineController.add(_isOnline);

      debugPrint('ConnectivityService: Online = $_isOnline');

      // If we just came back online, replay queued actions.
      if (!wasOnline && _isOnline) {
        debugPrint('ConnectivityService: back online -- processing queue');
        OfflineActionQueue().onConnectivityChanged(true);
      }
    });
  }

  /// Manually check current connectivity (e.g. before a critical operation).
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    return _isOnline;
  }

  /// Dispose of resources.
  void dispose() {
    _subscription?.cancel();
    _onlineController.close();
  }
}
