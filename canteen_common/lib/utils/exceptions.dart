/// Custom Exceptions
///
/// Domain-specific exceptions for the CanteenPay system.

/// General API exception with optional status code
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// Authentication-related exception
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

/// Thrown when a wallet has insufficient balance for a transaction
class InsufficientBalanceException implements Exception {
  final int currentBalance;
  final int requiredAmount;

  InsufficientBalanceException({
    required this.currentBalance,
    required this.requiredAmount,
  });

  @override
  String toString() =>
      'InsufficientBalanceException: Balance $currentBalance, required $requiredAmount';
}

/// Thrown when a student cannot be found by QR code or ID
class StudentNotFoundException implements Exception {
  final String identifier;

  StudentNotFoundException(this.identifier);

  @override
  String toString() => 'StudentNotFoundException: $identifier';
}
