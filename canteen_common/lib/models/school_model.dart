/// School Model
///
/// Represents a school registered in the CanteenPay system.
class SchoolModel {
  final String id;
  final String name;
  final String? nameMy;
  final String code;
  final String? address;
  final String? phone;
  final String? logoUrl;
  final bool isActive;
  final Map<String, dynamic> settings;
  final DateTime? createdAt;

  SchoolModel({
    required this.id,
    required this.name,
    this.nameMy,
    required this.code,
    this.address,
    this.phone,
    this.logoUrl,
    this.isActive = true,
    this.settings = const {},
    this.createdAt,
  });

  /// Create SchoolModel from JSON
  factory SchoolModel.fromJson(Map<String, dynamic> json) {
    return SchoolModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      nameMy: json['name_my'] ?? json['nameMy'],
      code: json['code'] ?? '',
      address: json['address'],
      phone: json['phone'],
      logoUrl: json['logo_url'] ?? json['logoUrl'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      settings: (json['settings'] as Map<String, dynamic>?) ?? {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : null,
    );
  }

  /// Convert SchoolModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (nameMy != null) 'name_my': nameMy,
      'code': code,
      if (address != null) 'address': address,
      if (phone != null) 'phone': phone,
      if (logoUrl != null) 'logo_url': logoUrl,
      'is_active': isActive,
      'settings': settings,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Copy with method
  SchoolModel copyWith({
    String? id,
    String? name,
    String? nameMy,
    String? code,
    String? address,
    String? phone,
    String? logoUrl,
    bool? isActive,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
  }) {
    return SchoolModel(
      id: id ?? this.id,
      name: name ?? this.name,
      nameMy: nameMy ?? this.nameMy,
      code: code ?? this.code,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logoUrl: logoUrl ?? this.logoUrl,
      isActive: isActive ?? this.isActive,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
