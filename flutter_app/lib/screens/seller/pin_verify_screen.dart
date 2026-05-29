import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:canteen_common/canteen_common.dart';

import '../../providers/scanner_provider.dart';
import '../../services/haptic_service.dart';

/// PIN verification screen shown after scanning a student QR code.
/// The seller must enter the student's 4-digit PIN to proceed to payment.
class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({super.key});

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  String _pin = '';
  bool _isWrong = false;
  int _attempts = 0;

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _isWrong = false;
    });
    if (_pin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _isWrong = false;
    });
  }

  void _verifyPin() {
    final scanner = context.read<ScannerProvider>();
    final student = scanner.scannedStudent;
    if (student == null) return;

    if (_pin == student.pinCode) {
      HapticService.success();
      context.go('/seller/payment-confirm');
    } else {
      HapticService.error();
      _attempts++;
      setState(() {
        _isWrong = true;
        _pin = '';
      });
      if (_attempts >= 3) {
        // After 3 wrong attempts, go back to scanner
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
  }

  @override
  Widget build(BuildContext context) {
    final scanner = context.watch<ScannerProvider>();
    final student = scanner.scannedStudent;

    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verify PIN')),
        body: const Center(child: Text('No student data')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Verify Student'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            scanner.reset();
            context.go('/seller');
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Student info
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: AppTheme.shadowMd,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                    child: Text(
                      student.displayName.isNotEmpty
                          ? student.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 2),
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
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Instruction
            Text(
              'Enter student\'s 4-digit PIN',
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

            const SizedBox(height: 20),

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
                      color: _isWrong
                          ? AppTheme.error
                          : AppTheme.primary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const Spacer(),

            // Number pad
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
