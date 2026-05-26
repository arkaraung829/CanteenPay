/// Transaction Model
///
/// Represents a financial transaction in the CanteenPay system.
/// Amounts are stored as integers in the smallest currency unit.
import 'package:intl/intl.dart';

class TransactionModel {
  final String id;
  final String walletId;
  final String type; // deposit, purchase, refund, adjustment
  final int amount;
  final int? balanceBefore;
  final int? balanceAfter;
  final String? description;
  final String? referenceId;
  final String? performedBy;
  final String? sellerId;
  final String? sellerName;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  TransactionModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    this.balanceBefore,
    this.balanceAfter,
    this.description,
    this.referenceId,
    this.performedBy,
    this.sellerId,
    this.sellerName,
    this.metadata,
    this.createdAt,
  });

  /// Create TransactionModel from JSON
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id']?.toString() ?? '',
      walletId: json['wallet_id']?.toString() ?? json['walletId']?.toString() ?? '',
      type: json['type'] ?? 'purchase',
      amount: json['amount'] ?? 0,
      balanceBefore: json['balance_before'] ?? json['balanceBefore'],
      balanceAfter: json['balance_after'] ?? json['balanceAfter'],
      description: json['description'],
      referenceId: json['reference_id'] ?? json['referenceId'],
      performedBy: json['performed_by'] ?? json['performedBy'],
      sellerId: json['seller_id'] ?? json['sellerId'],
      sellerName: json['seller_name'] ?? json['sellerName'],
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : null,
    );
  }

  /// Convert TransactionModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'type': type,
      'amount': amount,
      if (balanceBefore != null) 'balance_before': balanceBefore,
      if (balanceAfter != null) 'balance_after': balanceAfter,
      if (description != null) 'description': description,
      if (referenceId != null) 'reference_id': referenceId,
      if (performedBy != null) 'performed_by': performedBy,
      if (sellerId != null) 'seller_id': sellerId,
      if (sellerName != null) 'seller_name': sellerName,
      if (metadata != null) 'metadata': metadata,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Whether this is a debit transaction (money going out)
  bool get isDebit => type == 'purchase';

  /// Formatted amount string e.g. "10,000 MMK"
  String get formattedAmount {
    final formatter = NumberFormat('#,###');
    final prefix = isDebit ? '-' : '+';
    return '$prefix${formatter.format(amount)} MMK';
  }

  /// Formatted date string
  String get formattedDate {
    if (createdAt == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(createdAt!);
  }

  /// Copy with method
  TransactionModel copyWith({
    String? id,
    String? walletId,
    String? type,
    int? amount,
    int? balanceBefore,
    int? balanceAfter,
    String? description,
    String? referenceId,
    String? performedBy,
    String? sellerId,
    String? sellerName,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      balanceBefore: balanceBefore ?? this.balanceBefore,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      performedBy: performedBy ?? this.performedBy,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
