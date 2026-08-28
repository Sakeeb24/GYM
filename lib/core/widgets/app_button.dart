// lib/core/widgets/app_button.dart
import 'package:flutter/material.dart';
import '../theme/app_radii.dart';

enum AppButtonVariant { filled, outlined, tonal }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool enabled;
  final Widget? icon;
  final double radius;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.enabled = true,
    this.icon,
    this.radius = AppRadii.sm,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 8)],
        Text(text),
      ],
    );
    final style = ElevatedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      elevation: variant == AppButtonVariant.filled ? 0 : 0,
      shadowColor: Colors.transparent,
    );
    Widget btn;
    switch (variant) {
      case AppButtonVariant.filled:
        btn = ElevatedButton(onPressed: enabled ? onPressed : null, style: style, child: child);
      case AppButtonVariant.outlined:
        btn = OutlinedButton(onPressed: enabled ? onPressed : null, style: style, child: child);
      case AppButtonVariant.tonal:
        btn = FilledButton.tonal(onPressed: enabled ? onPressed : null, style: style, child: child);
    }
    return btn;
  }
}
