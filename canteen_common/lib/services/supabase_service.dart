/// Supabase Service
///
/// Central Supabase RPC and query wrapper for the CanteenPay system.
/// Uses singleton pattern for global access.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/student_model.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../models/parent_student_link_model.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  static SupabaseService get instance => _instance;

  SupabaseClient get _client => Supabase.instance.client;

  // ============================================================================
  // PURCHASES
  // ============================================================================

  /// Process a purchase transaction via RPC
  Future<Map<String, dynamic>> processPurchase({
    required String qrData,
    required int amount,
    required String sellerProfileId,
    String? description,
  }) async {
    try {
      final response = await _client.rpc('process_purchase', params: {
        'p_qr_data': qrData,
        'p_amount': amount,
        'p_seller_profile_id': sellerProfileId,
        'p_description': description,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('SupabaseService: processPurchase failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // DEPOSITS
  // ============================================================================

  /// Process a deposit transaction via RPC
  Future<Map<String, dynamic>> processDeposit({
    required String studentId,
    required int amount,
    required String staffProfileId,
    String? reference,
    String? note,
  }) async {
    try {
      final response = await _client.rpc('process_deposit', params: {
        'p_student_id': studentId,
        'p_amount': amount,
        'p_staff_profile_id': staffProfileId,
        'p_reference': reference,
        'p_note': note,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('SupabaseService: processDeposit failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // REFUNDS
  // ============================================================================

  /// Process a refund transaction via RPC
  Future<Map<String, dynamic>> processRefund({
    required String transactionId,
    required String staffProfileId,
    String? reason,
  }) async {
    try {
      final response = await _client.rpc('process_refund', params: {
        'p_transaction_id': transactionId,
        'p_staff_profile_id': staffProfileId,
        'p_reason': reason,
      });
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      debugPrint('SupabaseService: processRefund failed: $e');
      rethrow;
    }
  }

  // ============================================================================
  // QUERIES
  // ============================================================================

  /// Look up a student by QR data
  Future<StudentModel?> getStudentByQr(String qrData) async {
    try {
      final response = await _client
          .from('students')
          .select()
          .eq('qr_data', qrData)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return StudentModel.fromJson(response);
    } catch (e) {
      debugPrint('SupabaseService: getStudentByQr failed: $e');
      rethrow;
    }
  }

  /// Get wallet for a student
  Future<WalletModel?> getWallet(String studentId) async {
    try {
      final response = await _client
          .from('wallets')
          .select()
          .eq('student_id', studentId)
          .maybeSingle();

      if (response == null) return null;
      return WalletModel.fromJson(response);
    } catch (e) {
      debugPrint('SupabaseService: getWallet failed: $e');
      rethrow;
    }
  }

  /// Get transactions for a wallet with pagination
  Future<List<TransactionModel>> getTransactions(
    String walletId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('wallet_id', walletId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((json) => TransactionModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('SupabaseService: getTransactions failed: $e');
      rethrow;
    }
  }

  /// Get all students linked to a parent via parent_student_links
  Future<List<ParentStudentLinkModel>> getStudentsForParent(
    String parentId,
  ) async {
    try {
      final response = await _client
          .from('parent_student_links')
          .select('*, students(*), wallets(*)')
          .eq('parent_id', parentId);

      return (response as List)
          .map((json) => ParentStudentLinkModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('SupabaseService: getStudentsForParent failed: $e');
      rethrow;
    }
  }

  /// Search students by name or student code within a school
  Future<List<StudentModel>> searchStudents(
    String query,
    String schoolId,
  ) async {
    try {
      final response = await _client
          .from('students')
          .select()
          .eq('school_id', schoolId)
          .eq('is_active', true)
          .or('full_name.ilike.%$query%,student_code.ilike.%$query%')
          .limit(20);

      return (response as List)
          .map((json) => StudentModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('SupabaseService: searchStudents failed: $e');
      rethrow;
    }
  }
}
