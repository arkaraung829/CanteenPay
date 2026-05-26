import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/scanner_provider.dart';
import '../../providers/sales_provider.dart';
import '../../widgets/amount_keypad.dart';

/// Payment confirmation screen shown after scanning a student QR code.
class PaymentConfirmScreen extends StatefulWidget {
  const PaymentConfirmScreen({super.key});

  @override
  State<PaymentConfirmScreen> createState() => _PaymentConfirmScreenState();
}

class _PaymentConfirmScreenState extends State<PaymentConfirmScreen> {
  String _amount = '0';
  bool _isCharging = false;

  int get _amountInt => int.tryParse(_amount) ?? 0;

  void _onAmountChanged(String newAmount) {
    setState(() => _amount = newAmount);
  }

  Future<void> _onCharge() async {
    final scanner = context.read<ScannerProvider>();
    final sales = context.read<SalesProvider>();
    final auth = context.read<AuthProvider>();
    final student = scanner.scannedStudent;
    final wallet = scanner.scannedWallet;

    if (student == null || wallet == null || _amountInt <= 0) return;

    setState(() => _isCharging = true);

    try {
      // Call the real Supabase RPC for purchase processing
      final result = await SupabaseService.instance.processPurchase(
        qrData: student.qrData ?? '',
        amount: _amountInt,
        sellerProfileId: auth.user?.id ?? '',
        description: 'Canteen Purchase',
      );

      final referenceId = result['reference_id']?.toString() ?? result['transaction_id']?.toString() ?? '';
      final newBalance = (result['new_balance'] as num?)?.toInt() ?? (wallet.balance - _amountInt);
      final txnId = result['transaction_id']?.toString() ?? '';

      // Create a local transaction model for the sales list
      final transaction = TransactionModel(
        id: txnId,
        walletId: wallet.id,
        type: 'purchase',
        amount: _amountInt,
        balanceBefore: wallet.balance,
        balanceAfter: newBalance,
        description: 'Canteen Purchase',
        referenceId: referenceId,
        performedBy: auth.user?.id,
        sellerName: auth.user?.displayName ?? 'Seller',
        createdAt: DateTime.now(),
      );

      sales.addSale(transaction);
      scanner.reset();

      if (mounted) {
        context.go('/seller/payment-success', extra: {
          'studentName': student.displayName,
          'amountCharged': _amountInt,
          'newBalance': newBalance,
          'referenceId': referenceId,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCharging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanner = context.watch<ScannerProvider>();
    final student = scanner.scannedStudent;
    final wallet = scanner.scannedWallet;

    if (student == null || wallet == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: const Center(child: Text('No student data')),
      );
    }

    final insufficientBalance = _amountInt > wallet.balance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            scanner.reset();
            context.go('/seller');
          },
        ),
      ),
      body: Column(
        children: [
          // Student info card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Photo placeholder
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    student.displayName.isNotEmpty
                        ? student.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        student.gradeAndClass,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Balance',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatMMK(wallet.balance),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: wallet.isLowBalance
                            ? AppTheme.error
                            : AppTheme.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Balance warning
          if (insufficientBalance && _amountInt > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: AppTheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Insufficient balance! Student only has ${CurrencyFormatter.formatMMK(wallet.balance)}',
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Amount keypad
          Expanded(
            child: AmountKeypad(
              currentAmount: _amount,
              onAmountChanged: _onAmountChanged,
            ),
          ),

          // Charge button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      (_amountInt > 0 && !insufficientBalance && !_isCharging)
                          ? _onCharge
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: _isCharging
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _amountInt > 0
                              ? 'Charge ${CurrencyFormatter.formatMMK(_amountInt)}'
                              : 'Enter Amount',
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
