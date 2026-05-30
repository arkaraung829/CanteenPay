class AttendanceModel {
  final String id;
  final String studentId;
  final String schoolId;
  final DateTime date;
  final String status; // 'present', 'absent', 'late'
  final String? notes;
  final DateTime? createdAt;

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.schoolId,
    required this.date,
    required this.status,
    this.notes,
    this.createdAt,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      schoolId: json['school_id']?.toString() ?? '',
      date: DateTime.parse(json['date']),
      status: json['status'] ?? 'absent',
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}
