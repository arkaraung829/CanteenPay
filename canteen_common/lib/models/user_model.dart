/// User Model
///
/// Represents a user profile in the CanteenPay system.
///
/// ## Defensive Parsing Note
/// The `fromJson` factory uses defensive parsing that accepts multiple field
/// names for the same property (e.g., `full_name` and `fullName`). This is
/// intentional for backwards compatibility with different API response formats.
class UserModel {
  final String id;
  final String? email;
  final String? phone;
  final String? fullName;
  final String? fullNameMy;
  final String role;
  final String? schoolId;
  final String? avatarUrl;
  final bool isActive;
  final String? fcmToken;
  final String? locale;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    this.email,
    this.phone,
    this.fullName,
    this.fullNameMy,
    this.role = 'student',
    this.schoolId,
    this.avatarUrl,
    this.isActive = true,
    this.fcmToken,
    this.locale,
    this.createdAt,
  });

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'],
      phone: json['phone'],
      fullName: json['full_name'] ?? json['fullName'],
      fullNameMy: json['full_name_my'] ?? json['fullNameMy'],
      role: json['role'] ?? 'student',
      schoolId: json['school_id'] ?? json['schoolId'],
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      fcmToken: json['fcm_token'] ?? json['fcmToken'],
      locale: json['locale'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : null,
    );
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (fullName != null) 'full_name': fullName,
      if (fullNameMy != null) 'full_name_my': fullNameMy,
      'role': role,
      if (schoolId != null) 'school_id': schoolId,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'is_active': isActive,
      if (fcmToken != null) 'fcm_token': fcmToken,
      if (locale != null) 'locale': locale,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Display name with fallbacks
  String get displayName => fullName ?? email ?? phone ?? 'User';

  /// Role checking helpers
  bool get isAdmin => role == 'admin';
  bool get isParent => role == 'parent';
  bool get isSeller => role == 'seller';
  bool get isStudent => role == 'student';
  bool get isCounterStaff => role == 'counter_staff';
  bool get isTeacher => role == 'teacher';

  /// Copy with method
  UserModel copyWith({
    String? id,
    String? email,
    String? phone,
    String? fullName,
    String? fullNameMy,
    String? role,
    String? schoolId,
    String? avatarUrl,
    bool? isActive,
    String? fcmToken,
    String? locale,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      fullNameMy: fullNameMy ?? this.fullNameMy,
      role: role ?? this.role,
      schoolId: schoolId ?? this.schoolId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      fcmToken: fcmToken ?? this.fcmToken,
      locale: locale ?? this.locale,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
