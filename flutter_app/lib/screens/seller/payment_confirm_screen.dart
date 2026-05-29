import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/scanner_provider.dart';
import '../../widgets/amount_keypad.dart';
import '../../widgets/error_card.dart';

/// Payment confirmation screen shown after scanning a student QR code.
class PaymentConfirmScreen extends StatefulWidget {
  const PaymentConfirmScreen({super.key});

  @override
  State<PaymentConfirmScreen> createState() => _PaymentConfirmScreenState();
}

class _PaymentConfirmScreenState extends State<PaymentConfirmScreen> {
  String _amount = '0';

  int get _amountInt => int.tryParse(_amount) ?? 0;

  void _onAmountChanged(String newAmount) {
    setState(() => _amount = newAmount);
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
            margin: const EdgeInsets.all(AppTheme.spacingMd),
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: AppTheme.shadowMd,
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
                // Verified badge (no balance shown to seller)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, size: 16, color: AppTheme.success),
                      SizedBox(width: 4),
                      Text('Verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Insufficient balance ErrorCard
          if (insufficientBalance && _amountInt > 0)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ErrorCard(
                message: 'Insufficient balance for this amount',
              ),
            ),

          const SizedBox(height: 8),

          // Quick-amount buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [500, 1000, 2000, 5000].map((amount) {
                final isSelected = _amountInt == amount;
                return ActionChip(
                  label: Text(
                    '${amount}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.primary,
                    ),
                  ),
                  backgroundColor: isSelected
                      ? AppTheme.primary
                      : AppTheme.primary.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  onPressed: () => _onAmountChanged(amount.toString()),
                );
              }).toList(),
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

          // Continue button → goes to PIN verify
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      (_amountInt > 0 && !insufficientBalance)
                          ? () {
                              context.push('/seller/pin-verify', extra: {
                                'amount': _amountInt,
                              });
                            }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
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
                  child: Text(
                    _amountInt > 0
                        ? 'Continue  ${CurrencyFormatter.formatMMK(_amountInt)}'
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
