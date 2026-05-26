/// Error Handler Service
///
/// Centralized error handling: categorization, user-friendly messages,
/// and error sanitization (hides server internals in release mode).
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../utils/exceptions.dart';

// ---------------------------------------------------------------------------
// Error category
// ---------------------------------------------------------------------------

enum ErrorCategory {
  network,
  auth,
  database,
  validation,
  notFound,
  rateLimited,
  unknown,
}

// ---------------------------------------------------------------------------
// Error result
// ---------------------------------------------------------------------------

class ErrorResult {
  final ErrorCategory category;
  final String displayMessage;
  final String? technicalMessage;
  final bool shouldRetry;
  final bool fatal;

  const ErrorResult({
    required this.category,
    required this.displayMessage,
    this.technicalMessage,
    this.shouldRetry = false,
    this.fatal = false,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class ErrorHandlerService {
  ErrorHandlerService._();
  static final ErrorHandlerService _instance = ErrorHandlerService._();
  factory ErrorHandlerService() => _instance;

  /// Process any error and return a structured [ErrorResult].
  ErrorResult handle(
    Object error, {
    StackTrace? stackTrace,
    String? context,
    bool fatal = false,
  }) {
    final category = _categorize(error);
    final display = getDisplayMessage(error);

    if (kDebugMode) {
      debugPrint('ErrorHandlerService [$category]: $error');
      if (stackTrace != null) {
        debugPrint('$stackTrace');
      }
      if (context != null) {
        debugPrint('  context: $context');
      }
    }

    return ErrorResult(
      category: category,
      displayMessage: display,
      technicalMessage: kDebugMode ? error.toString() : null,
      shouldRetry: category == ErrorCategory.network,
      fatal: fatal,
    );
  }

  /// Return a user-friendly message for [error]. In release mode, sensitive
  /// server details are never exposed.
  String getDisplayMessage(Object error) {
    // Domain exceptions already carry safe messages.
    if (error is InsufficientBalanceException) {
      return 'Insufficient balance for this transaction';
    }
    if (error is StudentNotFoundException) {
      return 'Student not found. Please check the QR code or ID';
    }
    if (error is AuthException) {
      return 'Please log in again to continue';
    }
    if (error is ApiException) {
      return _sanitize(error.message, statusCode: error.statusCode);
    }

    // Supabase auth errors
    if (error is supa.AuthException) {
      return 'Authentication error. Please log in again';
    }

    // Network / socket errors
    if (error is SocketException || error is HttpException) {
      return 'Network error. Please check your internet connection';
    }

    // Timeouts
    if (error.toString().toLowerCase().contains('timeout')) {
      return 'Request timed out. Please try again';
    }

    // Fallback
    return _sanitize(error.toString());
  }

  // ---------------------------------------------------------------------------
  // Categorization
  // ---------------------------------------------------------------------------

  ErrorCategory _categorize(Object error) {
    if (error is SocketException ||
        error is HttpException ||
        error.toString().toLowerCase().contains('timeout') ||
        error.toString().toLowerCase().contains('network') ||
        error.toString().toLowerCase().contains('connection')) {
      return ErrorCategory.network;
    }

    if (error is AuthException || error is supa.AuthException) {
      return ErrorCategory.auth;
    }

    if (error is InsufficientBalanceException ||
        error.toString().toLowerCase().contains('validation')) {
      return ErrorCategory.validation;
    }

    if (error is StudentNotFoundException) {
      return ErrorCategory.notFound;
    }

    if (error is ApiException) {
      final code = error.statusCode;
      if (code == 401 || code == 403) return ErrorCategory.auth;
      if (code == 404) return ErrorCategory.notFound;
      if (code == 429) return ErrorCategory.rateLimited;
      if (code != null && code >= 500) return ErrorCategory.database;
    }

    return ErrorCategory.unknown;
  }

  // ---------------------------------------------------------------------------
  // Sanitization
  // ---------------------------------------------------------------------------

  /// In debug mode returns [raw] as-is. In release mode returns a generic,
  /// user-safe message.
  String _sanitize(String raw, {int? statusCode}) {
    if (kDebugMode) return raw;

    final lower = raw.toLowerCase();

    if (statusCode == 401 || lower.contains('unauthorized')) {
      return 'Please log in to continue';
    }
    if (statusCode == 403 || lower.contains('forbidden')) {
      return 'You do not have permission to perform this action';
    }
    if (statusCode == 404 || lower.contains('not found')) {
      return 'The requested item was not found';
    }
    if (statusCode == 422 || lower.contains('validation')) {
      return 'Please check your input and try again';
    }
    if (statusCode == 429 || lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many requests. Please wait a moment and try again';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Service temporarily unavailable. Please try again later';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return 'Request timed out. Please check your connection and try again';
    }
    if (lower.contains('network') ||
        lower.contains('connection') ||
        lower.contains('socket')) {
      return 'Network error. Please check your internet connection';
    }

    return 'Something went wrong. Please try again';
  }
}
