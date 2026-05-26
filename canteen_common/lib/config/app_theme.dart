/// CanteenPay App Theme
///
/// Centralized theme colors and ThemeData for consistent UI across
/// all CanteenPay applications.
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ============================================================================
  // BRAND COLORS
  // ============================================================================

  /// Primary deep blue
  static const Color primary = Color(0xFF1565C0);

  /// Secondary amber
  static const Color secondary = Color(0xFFFFA000);

  /// Success green
  static const Color success = Color(0xFF43A047);

  /// Error red
  static const Color error = Color(0xFFE53935);

  /// Background
  static const Color background = Color(0xFFF5F5F5);

  /// Surface
  static const Color surface = Colors.white;

  /// Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // ============================================================================
  // THEME DATA
  // ============================================================================

  /// Light theme for CanteenPay
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        error: error,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
