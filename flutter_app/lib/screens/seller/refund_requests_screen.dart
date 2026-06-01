import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

/// Seller refund requests screen — approve or reject refund requests.
class RefundRequestsScreen extends StatefulWidget {
  const RefundRequestsScreen({super.key});

  @override
  State<RefundRequestsScreen> createState() => _RefundRequestsScreenState();
}

class _RefundRequestsScreenState extends State<RefundRequestsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _sellerId;
  String? _processingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Get seller id
      final seller = await _supabase
          .from('canteen_sellers')
          .select('id')
          .eq('profile_id', userId)
          .maybeSingle();

      if (seller == null) {
        setState(() => _loading = false);
        return;
      }

      _sellerId = seller['id'];

      final data = await _supabase
          .from('refund_requests')
          .select('id, amount, reason, status, created_at, transaction_id, students(full_name, student_code)')
          .eq('seller_id', _sellerId!)
          .order('created_at', ascending: false);

      setState(() {
        _requests = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('RefundRequests: load failed: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(String requestId, String action) async {
    final isApprove = action == 'approve';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isApprove ? 'Approve Refund' : 'Reject Refund'),
        content: Text(isApprove
            ? 'Money will be returned to the student. Are you sure?'
            : 'The refund will be rejected and no money will be moved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.green : AppTheme.error,
            ),
            child: Text(isApprove ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _processingId = requestId);

    try {
      final result = await _supabase.rpc('respond_to_refund', params: {
        'p_refund_id': requestId,
        'p_action': action,
      });

      if (result is Map && result['success'] == true) {
        if (isApprove) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isApprove ? 'Refund approved' : 'Refund rejected'),
              backgroundColor: isApprove ? Colors.green : null,
            ),
          );
        }
        _load();
      } else {
        final error = result is Map ? result['error'] : 'Failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error'), backgroundColor: AppTheme.error),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  String _timeAgo(String dateStr) {
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests.where((r) => r['status'] == 'pending').toList();
    final processed = _requests.where((r) => r['status'] != 'pending').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund Requests'),
        actions: [
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${pending.length} pending',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textHint),
                      SizedBox(height: 12),
                      Text(
                        'No pending refund requests',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (pending.isNotEmpty) ...[
                        const Text(
                          'Pending Approval',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        ...pending.map((r) => _buildCard(r, isPending: true)),
                        const SizedBox(height: 24),
                      ],
                      if (processed.isNotEmpty) ...[
                        Text(
                          'History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...processed.map((r) => _buildCard(r, isPending: false)),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildCard(Map<String, dynamic> r, {required bool isPending}) {
    final student = r['students'] as Map<String, dynamic>?;
    final studentName = student?['full_name'] ?? 'Unknown';
    final studentCode = student?['student_code'] ?? '';
    final amount = r['amount'] as int;
    final status = r['status'] as String;
    final reason = r['reason'] as String?;
    final isProcessing = _processingId == r['id'];

    final statusColor = status == 'approved'
        ? Colors.green
        : status == 'rejected'
            ? AppTheme.error
            : Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isPending
            ? Border.all(color: Colors.orange.withValues(alpha: 0.4))
            : null,
        boxShadow: isPending ? AppTheme.shadowSm : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPending
                      ? Icons.pending
                      : status == 'approved'
                          ? Icons.check_circle
                          : Icons.cancel,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      studentCode,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatMMK(amount),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: $reason',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _timeAgo(r['created_at']),
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
              const Spacer(),
              if (!isPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : () => _respond(r['id'], 'reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : () => _respond(r['id'], 'approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
