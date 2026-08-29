// lib/core/widgets/app_text_field.dart
import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboard;
  final String? hint;
  final Widget? suffixIcon;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.obscure = false,
    this.keyboard,
    this.hint,
    this.suffixIcon,
    this.errorText,
    this.onChanged,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      onChanged: onChanged,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
        errorText: errorText,
        counterText: '',
      ),
    );
  }
}
