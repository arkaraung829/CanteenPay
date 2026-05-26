import 'package:flutter/material.dart';
import 'package:canteen_common/canteen_common.dart';

/// Text field with inline validation that shows errors and a green check
/// when valid. Validates on focus lost or on change.
class ValidatedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool showValidState;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool isDense;

  const ValidatedTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.showValidState = true,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.isDense = false,
  });

  @override
  State<ValidatedTextField> createState() => _ValidatedTextFieldState();
}

class _ValidatedTextFieldState extends State<ValidatedTextField> {
  String? _errorText;
  bool _hasInteracted = false;

  void _validate(String? value) {
    if (!_hasInteracted) return;
    setState(() {
      _errorText = widget.validator?.call(value);
    });
  }

  bool get _isValid =>
      _hasInteracted &&
      _errorText == null &&
      widget.controller.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      onChanged: (value) => _validate(value),
      onTapOutside: (_) {
        FocusScope.of(context).unfocus();
        if (widget.controller.text.isNotEmpty) {
          setState(() => _hasInteracted = true);
          _validate(widget.controller.text);
        }
      },
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: widget.isDense,
        prefixIcon:
            widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: _buildSuffixIcon(),
        errorText: _errorText,
        errorStyle: const TextStyle(fontSize: 12),
        enabledBorder: _isValid
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.success,
                  width: 1.5,
                ),
              )
            : null,
        focusedBorder: _isValid
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppTheme.success,
                  width: 2,
                ),
              )
            : null,
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (!widget.showValidState) return null;
    if (_isValid) {
      return const Icon(
        Icons.check_circle,
        color: AppTheme.success,
        size: 20,
      );
    }
    if (_errorText != null) {
      return const Icon(
        Icons.error_outline,
        color: AppTheme.error,
        size: 20,
      );
    }
    return null;
  }
}
