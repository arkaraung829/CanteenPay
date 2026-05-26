import 'package:flutter/material.dart';
import 'package:canteen_common/canteen_common.dart';

import '../services/haptic_service.dart';

/// Custom numeric keypad for entering payment amounts.
/// Designed for canteen sellers — large buttons, clear display, fast input.
class AmountKeypad extends StatelessWidget {
  final String currentAmount;
  final ValueChanged<String> onAmountChanged;
  final List<int> quickAmounts;

  const AmountKeypad({
    super.key,
    required this.currentAmount,
    required this.onAmountChanged,
    this.quickAmounts = const [500, 1000, 1500, 2000, 3000, 5000],
  });

  void _onDigit(String digit) {
    HapticService.medium();
    if (currentAmount == '0') {
      onAmountChanged(digit);
    } else {
      final newAmount = currentAmount + digit;
      if (newAmount.length <= 7) {
        onAmountChanged(newAmount);
      }
    }
  }

  void _onBackspace() {
    HapticService.light();
    if (currentAmount.length <= 1) {
      onAmountChanged('0');
    } else {
      onAmountChanged(currentAmount.substring(0, currentAmount.length - 1));
    }
  }

  void _onClear() {
    HapticService.medium();
    onAmountChanged('0');
  }

  void _onQuickAmount(int amount) {
    HapticService.heavy();
    onAmountChanged(amount.toString());
  }

  @override
  Widget build(BuildContext context) {
    final amount = int.tryParse(currentAmount) ?? 0;

    return Column(
      children: [
        // Display area — large and prominent
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: amount > 0 ? AppTheme.primary.withValues(alpha: 0.05) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: amount > 0 ? AppTheme.primary.withValues(alpha: 0.3) : Colors.grey[300]!,
              width: amount > 0 ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                amount > 0 ? 'Amount to charge' : 'Enter amount',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: amount > 0 ? AppTheme.primary : AppTheme.textHint,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.formatMMK(amount),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: amount > 0 ? AppTheme.primary : AppTheme.textHint,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Quick amount buttons — 3 per row, large touch targets
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: quickAmounts.take(3).map((amt) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _QuickAmountButton(
                        amount: amt,
                        isSelected: amount == amt,
                        onTap: () => _onQuickAmount(amt),
                      ),
                    ),
                  );
                }).toList(),
              ),
              Row(
                children: quickAmounts.skip(3).take(3).map((amt) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _QuickAmountButton(
                        amount: amt,
                        isSelected: amount == amt,
                        onTap: () => _onQuickAmount(amt),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Numeric keypad — big buttons for fast tapping
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildKeypadRow(['1', '2', '3']),
                _buildKeypadRow(['4', '5', '6']),
                _buildKeypadRow(['7', '8', '9']),
                _buildKeypadRow(['C', '0', '<']),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Expanded(
      child: Row(
        children: keys.map((key) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: _KeypadButton(
                label: key,
                onPressed: () {
                  if (key == 'C') {
                    _onClear();
                  } else if (key == '<') {
                    _onBackspace();
                  } else {
                    _onDigit(key);
                  }
                },
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final int amount;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.amount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.primary : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.grey[300]!,
            ),
          ),
          child: Text(
            CurrencyFormatter.formatMMK(amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _KeypadButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 80),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward().then((_) => _scaleController.reverse());
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final isAction = widget.label == 'C' || widget.label == '<';
    final isClear = widget.label == 'C';

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: isClear
            ? Colors.red[50]
            : isAction
                ? Colors.grey[200]
                : Colors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: isAction ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isClear
                    ? Colors.red[200]!
                    : isAction
                        ? Colors.grey[300]!
                        : Colors.grey[200]!,
              ),
            ),
            child: widget.label == '<'
                ? Icon(Icons.backspace_rounded, size: 28, color: Colors.grey[700])
                : Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: isAction ? 20 : 32,
                      fontWeight: FontWeight.w700,
                      color: isClear ? Colors.red[600] : AppTheme.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
