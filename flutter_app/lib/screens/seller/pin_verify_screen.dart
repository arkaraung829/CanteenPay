import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/scanner_provider.dart';
import '../../providers/sales_provider.dart';
import '../../services/haptic_service.dart';

/// PIN verification screen — the student/buyer sees the amount
/// and enters their 4-digit PIN to confirm the purchase.
class PinVerifyScreen extends StatefulWidget {
  final int amount;
  const PinVerifyScreen({super.key, required this.amount});

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  String _pin = '';
  bool _isWrong = false;
  bool _isCharging = false;
  int _attempts = 0;

  void _onDigit(String digit) {
    if (_pin.length >= 4 || _isCharging) return;
    setState(() {
      _pin += digit;
      _isWrong = false;
    });
    if (_pin.length == 4) {
      _verifyAndCharge();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty || _isCharging) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _isWrong = false;
    });
  }

  Future<void> _verifyAndCharge() async {
    final scanner = context.read<ScannerProvider>();
    final student = scanner.scannedStudent;
    if (student == null) return;

    // Verify PIN
    if (_pin != student.pinCode) {
      HapticService.error();
      _attempts++;
      debugPrint('PIN FAILED: student=${student.displayName} '
          'code=${student.studentCode} attempt=$_attempts '
          'time=${DateTime.now().toIso8601String()}');
      setState(() {
        _isWrong = true;
        _pin = '';
      });
      if (_attempts >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Too many wrong attempts. Please scan again.'),
              backgroundColor: Colors.red,
            ),
          );
          scanner.reset();
          context.go('/seller');
        }
      }
      return;
    }

    // PIN correct — process the charge
    HapticService.success();
    setState(() => _isCharging = true);

    // Check connectivity before processing
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw const SocketException('No internet');
      }
    } on SocketException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No internet connection. Please check and try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isCharging = false);
      }
      return;
    }

    try {
      final sales = context.read<SalesProvider>();
      final auth = context.read<AuthProvider>();
      final wallet = scanner.scannedWallet;

      if (wallet == null) return;

      final result = await SupabaseService.instance.processPurchase(
        qrData: student.qrData ?? '',
        amount: widget.amount,
        sellerProfileId: auth.user?.id ?? '',
        description: 'Canteen Purchase',
      );

      final referenceId = result['reference_id']?.toString() ??
          result['transaction_id']?.toString() ?? '';
      final newBalance = (result['new_balance'] as num?)?.toInt() ??
          (wallet.balance - widget.amount);
      final txnId = result['transaction_id']?.toString() ?? '';

      final transaction = TransactionModel(
        id: txnId,
        walletId: wallet.id,
        type: 'purchase',
        amount: widget.amount,
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
          'amountCharged': widget.amount,
          'referenceId': referenceId,
        });
      }
    } catch (e) {
      HapticService.error();
      if (mounted) {
        setState(() => _isCharging = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanner = context.watch<ScannerProvider>();
    final student = scanner.scannedStudent;

    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm Payment')),
        body: const Center(child: Text('No student data')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Confirm Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Amount display — prominent
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: AppTheme.shadowMd,
              ),
              child: Column(
                children: [
                  Text(
                    CurrencyFormatter.formatMMK(widget.amount),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.1),
                        child: Text(
                          student.displayName.isNotEmpty
                              ? student.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        student.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student.gradeAndClass,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Instruction for student
            Text(
              _isCharging
                  ? 'Processing payment...'
                  : 'Student: enter your 4-digit PIN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _isWrong ? AppTheme.error : AppTheme.textSecondary,
              ),
            ),
            if (_isWrong) ...[
              const SizedBox(height: 4),
              Text(
                'Wrong PIN. ${3 - _attempts} attempts remaining.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.error,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isWrong
                        ? AppTheme.error
                        : filled
                            ? AppTheme.primary
                            : Colors.transparent,
                    border: Border.all(
                      color: _isWrong ? AppTheme.error : AppTheme.primary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            if (_isCharging) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(),
            ],

            const Spacer(),

            // Number pad
            if (!_isCharging)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    for (final row in [
                      ['1', '2', '3'],
                      ['4', '5', '6'],
                      ['7', '8', '9'],
                      ['', '0', 'del'],
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: row.map((key) {
                            if (key.isEmpty) {
                              return const SizedBox(width: 72, height: 56);
                            }
                            if (key == 'del') {
                              return SizedBox(
                                width: 72,
                                height: 56,
                                child: TextButton(
                                  onPressed: _onBackspace,
                                  child: const Icon(
                                    Icons.backspace_outlined,
                                    size: 24,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              );
                            }
                            return SizedBox(
                              width: 72,
                              height: 56,
                              child: TextButton(
                                onPressed: () => _onDigit(key),
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                child: Text(
                                  key,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
