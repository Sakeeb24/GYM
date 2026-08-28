// lib/core/widgets/app_error_state.dart
import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

class AppErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 36, color: cs.error),
          const SizedBox(height: 12),
          Text(message, style: AppTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          if (onRetry != null) ...[const SizedBox(height: 12), TextButton(onPressed: onRetry, child: const Text('Retry'))],
        ]),
      ),
    );
  }
}
