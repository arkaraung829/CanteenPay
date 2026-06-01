import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:canteen_common/canteen_common.dart';

/// Seller payout screen — view balance and request cash payout.
class PayoutScreen extends StatefulWidget {
  const PayoutScreen({super.key});

  @override
  State<PayoutScreen> createState() => _PayoutScreenState();
}

class _PayoutScreenState extends State<PayoutScreen> {
  final _supabase = Supabase.instance.client;
  final _amountController = TextEditingController();
  bool _loading = true;
  bool _requesting = false;
  String? _sellerId;
  int _totalSales = 0;
  int _totalRefunds = 0;
  int _completedPayouts = 0;
  int _pendingPayouts = 0;
  int _availableBalance = 0;
  List<Map<String, dynamic>> _payouts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
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

      // Get balance
      final balance = await _supabase.rpc('get_seller_balance', params: {'p_seller_id': _sellerId!});

      // Get payout history
      final payouts = await _supabase
          .from('seller_payouts')
          .select()
          .eq('seller_id', _sellerId!)
          .order('requested_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _totalSales = (balance['total_sales'] as num).toInt();
          _totalRefunds = (balance['total_refunds'] as num).toInt();
          _completedPayouts = (balance['completed_payouts'] as num).toInt();
          _pendingPayouts = (balance['pending_payouts'] as num).toInt();
          _availableBalance = (balance['available_balance'] as num).toInt();
          _payouts = List<Map<String, dynamic>>.from(payouts);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('PayoutScreen: load failed: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestPayout() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (amount > _availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exceeds available balance (${CurrencyFormatter.formatMMK(_availableBalance)})'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _requesting = true);

    try {
      await _supabase.from('seller_payouts').insert({
        'seller_id': _sellerId!,
        'amount': amount,
      });

      HapticFeedback.heavyImpact();
      _amountController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payout requested! Waiting for admin approval.'), backgroundColor: Colors.green),
        );
      }

      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }

    setState(() => _requesting = false);
  }

  String _formatNum(int n) {
    return n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  String _timeAgo(String dateStr) {
    final dt = DateTime.tryParse(dateStr)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payout')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Balance card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF1976D2)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Available Balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('${_formatNum(_availableBalance)} MMK',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Stats
                  Row(
                    children: [
                      _stat('Total Sales', _totalSales, Colors.green),
                      const SizedBox(width: 8),
                      _stat('Paid Out', _completedPayouts, Colors.blue),
                      const SizedBox(width: 8),
                      _stat('Pending', _pendingPayouts, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Request payout
                  const Text('Request Payout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: '0',
                            suffixText: 'MMK',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _requesting ? null : _requestPayout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _requesting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Request'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Cash payout at school office', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const SizedBox(height: 24),

                  // History
                  if (_payouts.isNotEmpty) ...[
                    const Text('Payout History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ..._payouts.map((p) {
                      final status = p['status'] as String;
                      final amount = (p['amount'] as num).toInt();
                      final statusColor = status == 'completed' ? Colors.green
                          : status == 'approved' ? Colors.blue
                          : status == 'rejected' ? Colors.red
                          : Colors.orange;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                status == 'completed' ? Icons.check_circle
                                    : status == 'approved' ? Icons.thumb_up
                                    : status == 'rejected' ? Icons.cancel
                                    : Icons.pending,
                                color: statusColor, size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_formatNum(amount)} MMK',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  Text(_timeAgo(p['requested_at']),
                                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status.toUpperCase(),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _stat(String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_formatNum(value)} MMK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
