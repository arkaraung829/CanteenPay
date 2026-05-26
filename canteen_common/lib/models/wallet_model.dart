/// Wallet Model
///
/// Represents a student's wallet. Balance is stored as an integer in the
/// smallest currency unit (e.g., Kyat for MMK) to avoid floating point issues.
import 'package:intl/intl.dart';

class WalletModel {
  final String id;
  final String studentId;
  final int balance;
  final String currency;
  final bool isFrozen;
  final DateTime? updatedAt;

  WalletModel({
    required this.id,
    required this.studentId,
    this.balance = 0,
    this.currency = 'MMK',
    this.isFrozen = false,
    this.updatedAt,
  });

  /// Create WalletModel from JSON
  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      balance: json['balance'] ?? 0,
      currency: json['currency'] ?? 'MMK',
      isFrozen: json['is_frozen'] ?? json['isFrozen'] ?? false,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : null,
    );
  }

  /// Convert WalletModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'balance': balance,
      'currency': currency,
      'is_frozen': isFrozen,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Formatted balance string e.g. "10,000 MMK"
  String get formattedBalance {
    final formatter = NumberFormat('#,###');
    return '${formatter.format(balance)} $currency';
  }

  /// Whether the balance is considered low (below 1000)
  bool get isLowBalance => balance < 1000;

  /// Copy with method
  WalletModel copyWith({
    String? id,
    String? studentId,
    int? balance,
    String? currency,
    bool? isFrozen,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      isFrozen: isFrozen ?? this.isFrozen,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
