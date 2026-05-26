/// API Configuration
///
/// Centralized configuration for API endpoints, timeouts, and environment
/// switching. Uses compile-time environment variables for flexibility.
import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  /// Environment from compile-time variable: --dart-define=API_ENV=production
  static const String environment =
      String.fromEnvironment('API_ENV', defaultValue: 'development');

  /// Base URL switches between debug and production
  static String get baseUrl {
    if (kReleaseMode) {
      return 'https://api.canteenpay.com/v1'; // TODO: replace with production URL
    }
    return 'http://localhost:3000/v1'; // Local development
  }

  /// HTTP timeouts
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration uploadTimeout = Duration(seconds: 60);

  /// Pagination defaults
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  /// Whether we are running in development mode
  static bool get isDevelopment => environment == 'development';

  /// Whether we are running in production mode
  static bool get isProduction => environment == 'production';
}
