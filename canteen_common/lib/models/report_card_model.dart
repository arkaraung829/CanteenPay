import 'dart:ui';

class SubjectScoreModel {
  final String id;
  final String subjectName;
  final String? subjectNameMy;
  final double? score;
  final int fullMarks;
  final int passMark;
  final String? letterGrade;
  final String? examTypeName;
  final String? remarks;

  SubjectScoreModel({
    required this.id,
    required this.subjectName,
    this.subjectNameMy,
    this.score,
    required this.fullMarks,
    this.passMark = 40,
    this.letterGrade,
    this.examTypeName,
    this.remarks,
  });

  factory SubjectScoreModel.fromJson(Map<String, dynamic> json) {
    return SubjectScoreModel(
      id: json['id']?.toString() ?? '',
      subjectName: json['subject_name'] ?? json['subjectName'] ?? '',
      subjectNameMy: json['subject_name_my'],
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
      fullMarks: json['full_marks'] ?? 100,
      passMark: json['pass_marks'] ?? 40,
      letterGrade: json['letter_grade'],
      examTypeName: json['exam_type_name'],
      remarks: json['remarks'],
    );
  }

  bool get isPassed => score != null && score! >= passMark;
}

class ReportCardModel {
  final String id;
  final String studentId;
  final String academicYear;
  final String term;
  final double? totalScore;
  final int? totalFullMarks;
  final double? percentage;
  final int? rankInClass;
  final String? overallGrade;
  final String? result;
  final String? teacherComment;
  final String? principalComment;
  final DateTime? generatedAt;
  final List<SubjectScoreModel> subjects;

  ReportCardModel({
    required this.id,
    required this.studentId,
    required this.academicYear,
    required this.term,
    this.totalScore,
    this.totalFullMarks,
    this.percentage,
    this.rankInClass,
    this.overallGrade,
    this.result,
    this.teacherComment,
    this.principalComment,
    this.generatedAt,
    this.subjects = const [],
  });

  factory ReportCardModel.fromJson(Map<String, dynamic> json, {List<SubjectScoreModel>? subjects}) {
    return ReportCardModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      academicYear: json['academic_year'] ?? '',
      term: json['term'] ?? '',
      totalScore: json['total_score'] != null ? (json['total_score'] as num).toDouble() : null,
      totalFullMarks: json['total_full_marks'],
      percentage: json['percentage'] != null ? (json['percentage'] as num).toDouble() : null,
      rankInClass: json['rank_in_class'],
      overallGrade: json['overall_grade'],
      result: json['result'],
      teacherComment: json['teacher_comment'],
      principalComment: json['principal_comment'],
      generatedAt: json['generated_at'] != null ? DateTime.parse(json['generated_at']) : null,
      subjects: subjects ?? [],
    );
  }

  Color get resultColor {
    switch (result) {
      case 'Distinction': return const Color(0xFF4CAF50);
      case 'Credit': return const Color(0xFF2196F3);
      case 'Pass': return const Color(0xFFFF9800);
      case 'Fail': return const Color(0xFFF44336);
      default: return const Color(0xFF9E9E9E);
    }
  }
}
