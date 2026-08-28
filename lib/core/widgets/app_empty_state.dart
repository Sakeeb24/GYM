// lib/core/widgets/app_empty_state.dart
import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

class AppEmptyState extends StatelessWidget {
  final String message;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AppEmptyState({super.key, required this.message, this.icon, this.onAction, this.actionLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon ?? Icons.inbox_outlined, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          if (onAction != null && actionLabel != null)
            ...[const SizedBox(height: 12), TextButton(onPressed: onAction, child: Text(actionLabel!))],
        ]),
      ),
    );
  }
}
