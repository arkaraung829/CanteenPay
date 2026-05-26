import 'package:flutter/material.dart';
import 'package:canteen_common/canteen_common.dart';

import '../services/haptic_service.dart';

/// Custom numeric keypad for entering payment amounts.
class AmountKeypad extends StatelessWidget {
  final String currentAmount;
  final ValueChanged<String> onAmountChanged;
  final List<int> quickAmounts;

  const AmountKeypad({
    super.key,
    required this.currentAmount,
    required this.onAmountChanged,
    this.quickAmounts = const [500, 1000, 1500, 2000, 3000],
  });

  void _onDigit(String digit) {
    HapticService.selection();
    if (currentAmount == '0') {
      onAmountChanged(digit);
    } else {
      // Limit to reasonable amount (prevent overflow)
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
    HapticService.light();
    onAmountChanged('0');
  }

  void _onQuickAmount(int amount) {
    HapticService.selection();
    onAmountChanged(amount.toString());
  }

  @override
  Widget build(BuildContext context) {
    final amount = int.tryParse(currentAmount) ?? 0;

    return Column(
      children: [
        // Display area
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              const Text(
                'Amount',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.formatMMK(amount),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Quick amount chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickAmounts.map((amt) {
              final isSelected = amount == amt;
              return ActionChip(
                label: Text(
                  CurrencyFormatter.formatMMK(amt),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                backgroundColor: isSelected
                    ? AppTheme.primary
                    : AppTheme.primary.withValues(alpha: 0.1),
                side: BorderSide.none,
                onPressed: () => _onQuickAmount(amt),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // Numeric keypad grid
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final isAction = widget.label == 'C' || widget.label == '<';

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: isAction ? Colors.grey[200] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: widget.label == '<'
                ? const Icon(Icons.backspace_outlined, size: 24)
                : Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: isAction ? 18 : 24,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
