import 'package:flutter/services.dart';

/// Simple static utility for haptic feedback across the app.
class HapticService {
  HapticService._();

  /// Light tap - for subtle interactions.
  static void light() => HapticFeedback.lightImpact();

  /// Medium tap - for standard interactions.
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy tap - for important actions.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Success feedback - on payment success, link success, etc.
  static void success() => HapticFeedback.mediumImpact();

  /// Error feedback - on failures and errors.
  static void error() => HapticFeedback.heavyImpact();

  /// Selection click - on button taps, keypad presses.
  static void selection() => HapticFeedback.selectionClick();
}
