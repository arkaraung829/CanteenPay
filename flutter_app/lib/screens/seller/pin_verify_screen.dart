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
  int _attempts = 0;
  bool _isWrong = false;
  bool _isCharging = false;
  bool _hasProcessed = false; // Prevent duplicate charges

  void _onDigit(String digit) {
    if (_pin.length >= 4 || _isCharging) return;
    setState(() {
      _pin += digit;
      _isWrong = false;
    });
    if (_pin.length == 4) _verifyAndCharge();
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
    if (student == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student data lost. Please scan again.'), backgroundColor: Colors.red),
        );
        context.go('/seller');
      }
      return;
    }

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

    // Prevent duplicate charges
    if (_hasProcessed) return;
    _hasProcessed = true;

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
        setState(() {
          _isCharging = false;
          _hasProcessed = false;
        });
      }
      return;
    }

    try {
      final sales = context.read<SalesProvider>();
      final auth = context.read<AuthProvider>();
      final wallet = scanner.scannedWallet;

      if (wallet == null || auth.user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session error. Please try again.'), backgroundColor: Colors.red),
          );
          setState(() {
            _isCharging = false;
            _hasProcessed = false;
          });
        }
        return;
      }

      final result = await SupabaseService.instance.processPurchase(
        qrData: student.qrData ?? '',
        amount: widget.amount,
        sellerProfileId: auth.user!.id,
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
        performedBy: auth.user!.id,
        sellerName: auth.user!.displayName ?? 'Seller',
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
      if (mounted) {
        HapticService.error();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() {
          _isCharging = false;
          _hasProcessed = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanner = context.watch<ScannerProvider>();
    final student = scanner.scannedStudent;

    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PIN Verify')),
        body: const Center(child: Text('No student data. Please scan again.')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _isCharging ? null : () {
            scanner.reset();
            context.go('/seller');
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Amount display
            const SizedBox(height: 10),
            Text(
              '${CurrencyFormatter.formatMMK(widget.amount)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              student.displayName,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
            ),
            Text(
              student.gradeAndClass,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 30),

            // PIN label
            Text(
              _isCharging ? 'Processing payment...' : 'Student: enter your 4-digit PIN',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
            ),
            const SizedBox(height: 16),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? (_isWrong ? Colors.red : Colors.white)
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                );
              }),
            ),
            if (_isWrong)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Wrong PIN (${3 - _attempts} attempts left)',
                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            if (_isCharging)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(color: Colors.white),
              ),

            const Spacer(),

            // Keypad
            if (!_isCharging)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    for (final row in [['1','2','3'], ['4','5','6'], ['7','8','9'], ['','0','⌫']])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: row.map((key) {
                            if (key.isEmpty) return const SizedBox(width: 64);
                            return _keypadButton(key);
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _keypadButton(String key) {
    return GestureDetector(
      onTap: () {
        HapticService.selection();
        if (key == '⌫') {
          _onBackspace();
        } else {
          _onDigit(key);
        }
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        alignment: Alignment.center,
        child: key == '⌫'
            ? const Icon(Icons.backspace_outlined, color: Colors.white, size: 22)
            : Text(key, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
