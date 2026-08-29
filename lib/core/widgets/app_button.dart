// lib/core/widgets/app_button.dart
// Athletic High-Energy Action Button
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme(
            data: IconThemeData(
              size: 18,
              color: variant == AppButtonVariant.filled
                  ? Colors.black
                  : (isDark ? AppColors.brand : AppColors.brandDark),
            ),
            child: icon!,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: variant == AppButtonVariant.filled
                ? Colors.black
                : (isDark ? AppColors.brand : AppColors.brandDark),
          ),
        ),
      ],
    );

    final borderRadius = BorderRadius.circular(radius);

    switch (variant) {
      case AppButtonVariant.filled:
        return SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              disabledBackgroundColor: isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceAlt,
              foregroundColor: Colors.black,
              disabledForegroundColor: isDark ? AppColors.dTextTertiary : AppColors.lTextTertiary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
            ),
            child: child,
          ),
        );

      case AppButtonVariant.outlined:
        return SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? AppColors.brand : AppColors.brandDark,
              side: BorderSide(
                color: enabled ? (isDark ? AppColors.brand : AppColors.brandDark) : cs.outline,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
            ),
            child: child,
          ),
        );

      case AppButtonVariant.tonal:
        return SizedBox(
          height: 48,
          child: FilledButton.tonal(
            onPressed: enabled ? onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
              foregroundColor: isDark ? AppColors.brand : AppColors.brandDark,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
            ),
            child: child,
          ),
        );
    }
  }
}
