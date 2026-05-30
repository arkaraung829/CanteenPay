import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../services/haptic_service.dart';
import 'scan_screen.dart';
import '../../widgets/success_animation.dart';

/// Success screen displayed after a payment is processed.
class PaymentSuccessScreen extends StatefulWidget {
  final String studentName;
  final int amountCharged;
  final String referenceId;

  const PaymentSuccessScreen({
    super.key,
    required this.studentName,
    required this.amountCharged,
    this.referenceId = '',
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen> {
  @override
  void initState() {
    super.initState();

    // Haptic feedback on success
    HapticService.success();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.success,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated checkmark using SuccessAnimation widget
                SuccessAnimation(
                  size: 120,
                ),

                const SizedBox(height: 32),

                const Text(
                  'Payment Successful!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 32),

                // Transaction receipt card with enhanced shadow
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppTheme.success.withValues(alpha: 0.2),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _receiptRow('Student', widget.studentName),
                      const Divider(height: 24),
                      _receiptRow(
                        'Amount Charged',
                        CurrencyFormatter.formatMMK(widget.amountCharged),
                        valueColor: AppTheme.error,
                        valueBold: true,
                      ),
                      const Divider(height: 24),
                      _receiptRow(
                        'Time',
                        TimeOfDay.now().format(context),
                      ),
                      const Divider(height: 24),
                      _receiptRow('Reference', widget.referenceId),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Prominent Scan Next button
                SizedBox(
                  width: 220,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                              ScanScreen.autoStartScanner = true;
                              context.go('/seller');
                            },
                    icon: const Icon(Icons.qr_code_scanner, size: 24),
                    label: const Text('Scan Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: valueBold ? FontWeight.bold : FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
