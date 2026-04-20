import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthFloatingInputField extends StatelessWidget {
  const AuthFloatingInputField({
    super.key,
    required this.label,
    required this.fillColor,
    required this.textColor,
    required this.hintColor,
    this.controller,
    this.prefixIcon,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.error,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.inputFormatters,
    this.suffix,
    this.focusColor,
  });

  final TextEditingController? controller;
  final String label;
  final Color fillColor;
  final Color textColor;
  final Color hintColor;
  final IconData? prefixIcon;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? error;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;
  final Color? focusColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textSelectionTheme = Theme.of(context).textSelectionTheme;
    final primaryColor = focusColor ?? colorScheme.primary;
    final cursorColor = textSelectionTheme.cursorColor ?? primaryColor;
    final errorColor = colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType ?? TextInputType.text,
          textInputAction: textInputAction,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: TextStyle(color: textColor, fontSize: 16),
          cursorColor: cursorColor,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: hintColor.withValues(alpha: 0.78),
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            floatingLabelStyle: TextStyle(
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.05,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            filled: true,
            fillColor: fillColor,
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    color: hintColor.withValues(alpha: 0.78),
                    size: 21,
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            suffixIcon: suffix,
            suffixIconConstraints: suffix != null
                ? const BoxConstraints(minHeight: 32, minWidth: 32)
                : null,
            counterText: maxLength != null ? '' : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: primaryColor.withValues(alpha: 0.28),
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: errorColor.withValues(alpha: 0.24),
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: errorColor.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: errorColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    error!,
                    softWrap: true,
                    style: TextStyle(color: errorColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
