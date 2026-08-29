// lib/core/widgets/app_empty_state.dart
// Athletic Empty State Display
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';

class AppEmptyState extends StatelessWidget {
  final String message;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AppEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: cs.outline, width: 1.5),
              ),
              child: Icon(
                icon ?? Icons.fitness_center_rounded,
                size: 32,
                color: isDark ? AppColors.brand : AppColors.brandDark,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              message,
              style: AppTypography.headlineSmall.copyWith(color: cs.onSurface),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 20),
              AppButton(
                text: actionLabel!,
                onPressed: onAction,
                variant: AppButtonVariant.outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
