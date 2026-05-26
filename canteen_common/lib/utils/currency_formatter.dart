/// Currency Formatter
///
/// Static utility for formatting BIGINT currency amounts stored as integers
/// in the smallest unit (e.g., Kyat for MMK).
import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  /// Format as full amount with currency code
  /// e.g. 10000 => "10,000 MMK"
  static String formatMMK(int amount) {
    final formatter = NumberFormat('#,###');
    return '${formatter.format(amount)} MMK';
  }

  /// Format as compact amount
  /// e.g. 10000 => "10K", 1500000 => "1.5M"
  static String formatCompact(int amount) {
    final formatter = NumberFormat.compact();
    return formatter.format(amount);
  }
}
