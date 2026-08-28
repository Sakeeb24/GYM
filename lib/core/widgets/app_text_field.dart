// lib/core/widgets/app_text_field.dart
import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboard;
  final String? hint;

  const AppTextField({super.key, this.controller, required this.label, this.obscure = false, this.keyboard, this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
