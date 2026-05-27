/// Student Model
///
/// Represents a student enrolled in a school using the CanteenPay system.
class StudentModel {
  final String id;
  final String profileId;
  final String schoolId;
  final String studentCode;
  final String? qrData;
  final String? fullName;
  final String? fullNameMy;
  final String? className;
  final String? grade;
  final int? enrollmentYear;
  final String? photoUrl;
  final bool isActive;
  final int? dailySpendingLimit;
  final DateTime? createdAt;
  final String? dateOfBirth;
  final String? parentPhone;

  StudentModel({
    required this.id,
    required this.profileId,
    required this.schoolId,
    required this.studentCode,
    this.qrData,
    this.fullName,
    this.fullNameMy,
    this.className,
    this.grade,
    this.enrollmentYear,
    this.photoUrl,
    this.isActive = true,
    this.dailySpendingLimit,
    this.createdAt,
    this.dateOfBirth,
    this.parentPhone,
  });

  /// Create StudentModel from JSON
  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? json['profileId']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? json['schoolId']?.toString() ?? '',
      studentCode: json['student_code'] ?? json['studentCode'] ?? '',
      qrData: json['qr_data'] ?? json['qrData'],
      fullName: json['full_name'] ?? json['fullName'],
      fullNameMy: json['full_name_my'] ?? json['fullNameMy'],
      className: json['class_name'] ?? json['className'],
      grade: json['grade'],
      enrollmentYear: json['enrollment_year'] ?? json['enrollmentYear'],
      photoUrl: json['photo_url'] ?? json['photoUrl'],
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      dailySpendingLimit: json['daily_spending_limit'] ?? json['dailySpendingLimit'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : null,
      dateOfBirth: json['date_of_birth'] ?? json['dateOfBirth'],
      parentPhone: json['parent_phone'] ?? json['parentPhone'],
    );
  }

  /// Convert StudentModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'school_id': schoolId,
      'student_code': studentCode,
      if (qrData != null) 'qr_data': qrData,
      if (fullName != null) 'full_name': fullName,
      if (fullNameMy != null) 'full_name_my': fullNameMy,
      if (className != null) 'class_name': className,
      if (grade != null) 'grade': grade,
      if (enrollmentYear != null) 'enrollment_year': enrollmentYear,
      if (photoUrl != null) 'photo_url': photoUrl,
      'is_active': isActive,
      if (dailySpendingLimit != null) 'daily_spending_limit': dailySpendingLimit,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (parentPhone != null) 'parent_phone': parentPhone,
    };
  }

  /// Display name with fallback
  String get displayName => fullName ?? studentCode;

  /// Grade and class combined
  String get gradeAndClass {
    if (grade != null && className != null) return '$grade - $className';
    return grade ?? className ?? '';
  }

  /// Copy with method
  StudentModel copyWith({
    String? id,
    String? profileId,
    String? schoolId,
    String? studentCode,
    String? qrData,
    String? fullName,
    String? fullNameMy,
    String? className,
    String? grade,
    int? enrollmentYear,
    String? photoUrl,
    bool? isActive,
    int? dailySpendingLimit,
    DateTime? createdAt,
    String? dateOfBirth,
    String? parentPhone,
  }) {
    return StudentModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      schoolId: schoolId ?? this.schoolId,
      studentCode: studentCode ?? this.studentCode,
      qrData: qrData ?? this.qrData,
      fullName: fullName ?? this.fullName,
      fullNameMy: fullNameMy ?? this.fullNameMy,
      className: className ?? this.className,
      grade: grade ?? this.grade,
      enrollmentYear: enrollmentYear ?? this.enrollmentYear,
      photoUrl: photoUrl ?? this.photoUrl,
      isActive: isActive ?? this.isActive,
      dailySpendingLimit: dailySpendingLimit ?? this.dailySpendingLimit,
      createdAt: createdAt ?? this.createdAt,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      parentPhone: parentPhone ?? this.parentPhone,
    );
  }
}
