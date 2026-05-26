/// Announcement Model
///
/// Represents a school announcement in the CanteenPay system.
class AnnouncementModel {
  final String id;
  final String schoolId;
  final String authorId;
  final String? title;
  final String? titleMy;
  final String? body;
  final String? bodyMy;
  final List<String> targetAudience;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  AnnouncementModel({
    required this.id,
    required this.schoolId,
    required this.authorId,
    this.title,
    this.titleMy,
    this.body,
    this.bodyMy,
    this.targetAudience = const [],
    this.isPublished = false,
    this.publishedAt,
    this.expiresAt,
    this.createdAt,
  });

  /// Create AnnouncementModel from JSON
  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? json['schoolId']?.toString() ?? '',
      authorId: json['author_id']?.toString() ?? json['authorId']?.toString() ?? '',
      title: json['title'],
      titleMy: json['title_my'] ?? json['titleMy'],
      body: json['body'],
      bodyMy: json['body_my'] ?? json['bodyMy'],
      targetAudience: (json['target_audience'] ?? json['targetAudience'] ?? [])
          .cast<String>(),
      isPublished: json['is_published'] ?? json['isPublished'] ?? false,
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'])
          : json['publishedAt'] != null
              ? DateTime.parse(json['publishedAt'])
              : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : json['expiresAt'] != null
              ? DateTime.parse(json['expiresAt'])
              : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : null,
    );
  }

  /// Convert AnnouncementModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'author_id': authorId,
      if (title != null) 'title': title,
      if (titleMy != null) 'title_my': titleMy,
      if (body != null) 'body': body,
      if (bodyMy != null) 'body_my': bodyMy,
      'target_audience': targetAudience,
      'is_published': isPublished,
      if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Copy with method
  AnnouncementModel copyWith({
    String? id,
    String? schoolId,
    String? authorId,
    String? title,
    String? titleMy,
    String? body,
    String? bodyMy,
    List<String>? targetAudience,
    bool? isPublished,
    DateTime? publishedAt,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      authorId: authorId ?? this.authorId,
      title: title ?? this.title,
      titleMy: titleMy ?? this.titleMy,
      body: body ?? this.body,
      bodyMy: bodyMy ?? this.bodyMy,
      targetAudience: targetAudience ?? this.targetAudience,
      isPublished: isPublished ?? this.isPublished,
      publishedAt: publishedAt ?? this.publishedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
