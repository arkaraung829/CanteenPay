/// Safe Change Notifier Mixin
///
/// Prevents "setState() or markNeedsBuild() called during build" errors
/// by deferring notifications to the next frame when called during build.
import 'package:flutter/widgets.dart';

mixin SafeChangeNotifierMixin on ChangeNotifier {
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Safely notify listeners, deferring to next frame to avoid
  /// calling setState during build.
  void safeNotifyListeners() {
    if (!_isDisposed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          notifyListeners();
        }
      });
    }
  }
}
