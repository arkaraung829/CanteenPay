/// Seller Model
///
/// Represents a canteen seller/stall in the CanteenPay system.
class SellerModel {
  final String id;
  final String profileId;
  final String schoolId;
  final String? stallName;
  final String? stallNameMy;
  final String? stallNumber;
  final bool isActive;
  final DateTime? createdAt;

  SellerModel({
    required this.id,
    required this.profileId,
    required this.schoolId,
    this.stallName,
    this.stallNameMy,
    this.stallNumber,
    this.isActive = true,
    this.createdAt,
  });

  /// Create SellerModel from JSON
  factory SellerModel.fromJson(Map<String, dynamic> json) {
    return SellerModel(
      id: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? json['profileId']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? json['schoolId']?.toString() ?? '',
      stallName: json['stall_name'] ?? json['stallName'],
      stallNameMy: json['stall_name_my'] ?? json['stallNameMy'],
      stallNumber: json['stall_number'] ?? json['stallNumber'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : null,
    );
  }

  /// Convert SellerModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'school_id': schoolId,
      if (stallName != null) 'stall_name': stallName,
      if (stallNameMy != null) 'stall_name_my': stallNameMy,
      if (stallNumber != null) 'stall_number': stallNumber,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Copy with method
  SellerModel copyWith({
    String? id,
    String? profileId,
    String? schoolId,
    String? stallName,
    String? stallNameMy,
    String? stallNumber,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SellerModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      schoolId: schoolId ?? this.schoolId,
      stallName: stallName ?? this.stallName,
      stallNameMy: stallNameMy ?? this.stallNameMy,
      stallNumber: stallNumber ?? this.stallNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
