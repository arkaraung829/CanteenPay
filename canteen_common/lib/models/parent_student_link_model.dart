/// Parent-Student Link Model
///
/// Represents the relationship between a parent and a student.
/// Supports optional eager loading of nested student and wallet data.
import 'student_model.dart';
import 'wallet_model.dart';

class ParentStudentLinkModel {
  final String id;
  final String parentId;
  final String studentId;
  final String? relationship;
  final bool isPrimary;
  final DateTime? createdAt;

  /// Optional nested models for eager loading
  final StudentModel? student;
  final WalletModel? wallet;

  ParentStudentLinkModel({
    required this.id,
    required this.parentId,
    required this.studentId,
    this.relationship,
    this.isPrimary = false,
    this.createdAt,
    this.student,
    this.wallet,
  });

  /// Create ParentStudentLinkModel from JSON
  factory ParentStudentLinkModel.fromJson(Map<String, dynamic> json) {
    // Parse student data (Supabase returns 'students' for the table name)
    final studentData = json['student'] ?? json['students'];
    StudentModel? student;
    WalletModel? wallet;

    if (studentData is Map<String, dynamic>) {
      student = StudentModel.fromJson(studentData);

      // Wallet is nested inside student data: students(*, wallets(*))
      final walletData = studentData['wallets'] ?? studentData['wallet'];
      if (walletData is Map<String, dynamic>) {
        wallet = WalletModel.fromJson(walletData);
      } else if (walletData is List && walletData.isNotEmpty) {
        wallet = WalletModel.fromJson(walletData[0] as Map<String, dynamic>);
      }
    }

    // Also check top-level wallet (for backward compatibility)
    if (wallet == null) {
      final topWallet = json['wallet'] ?? json['wallets'];
      if (topWallet is Map<String, dynamic>) {
        wallet = WalletModel.fromJson(topWallet);
      }
    }

    return ParentStudentLinkModel(
      id: json['id']?.toString() ?? '',
      parentId: json['parent_id']?.toString() ?? json['parentId']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? json['studentId']?.toString() ?? '',
      relationship: json['relationship'],
      isPrimary: json['is_primary'] ?? json['isPrimary'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : json['createdAt'] != null
              ? DateTime.parse(json['createdAt'])
              : null,
      student: student,
      wallet: wallet,
    );
  }

  /// Convert ParentStudentLinkModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_id': parentId,
      'student_id': studentId,
      if (relationship != null) 'relationship': relationship,
      'is_primary': isPrimary,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Copy with method
  ParentStudentLinkModel copyWith({
    String? id,
    String? parentId,
    String? studentId,
    String? relationship,
    bool? isPrimary,
    DateTime? createdAt,
    StudentModel? student,
    WalletModel? wallet,
  }) {
    return ParentStudentLinkModel(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      studentId: studentId ?? this.studentId,
      relationship: relationship ?? this.relationship,
      isPrimary: isPrimary ?? this.isPrimary,
      createdAt: createdAt ?? this.createdAt,
      student: student ?? this.student,
      wallet: wallet ?? this.wallet,
    );
  }
}
