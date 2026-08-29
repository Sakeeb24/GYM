// lib/core/widgets/app_button.dart
// Athletic High-Energy Action Button with Physics Feedback
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { filled, outlined, tonal, gold, danger }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool enabled;
  final Widget? icon;
  final double radius;
  final bool fullWidth;
  final double height;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.enabled = true,
    this.icon,
    this.radius = AppRadii.sm,
    this.fullWidth = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color textColor;
    Color iconColor;

    switch (variant) {
      case AppButtonVariant.filled:
        textColor = Colors.black;
        iconColor = Colors.black;
        break;
      case AppButtonVariant.gold:
        textColor = Colors.black;
        iconColor = Colors.black;
        break;
      case AppButtonVariant.danger:
        textColor = Colors.white;
        iconColor = Colors.white;
        break;
      case AppButtonVariant.outlined:
      case AppButtonVariant.tonal:
        textColor = isDark ? AppColors.brand : AppColors.brandDark;
        iconColor = textColor;
        break;
    }

    final content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          IconTheme(
            data: IconThemeData(size: 18, color: iconColor),
            child: icon!,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: AppTypography.labelLarge.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: enabled
                ? textColor
                : (isDark ? AppColors.dTextTertiary : AppColors.lTextTertiary),
          ),
        ),
      ],
    );

    final borderRadius = BorderRadius.circular(radius);

    Widget button;

    switch (variant) {
      case AppButtonVariant.filled:
        button = ElevatedButton(
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
          child: content,
        );
        break;

      case AppButtonVariant.gold:
        button = ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.goldMedal,
            disabledBackgroundColor: isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceAlt,
            foregroundColor: Colors.black,
            disabledForegroundColor: isDark ? AppColors.dTextTertiary : AppColors.lTextTertiary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.danger:
        button = ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.outlined:
        button = OutlinedButton(
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
          child: content,
        );
        break;

      case AppButtonVariant.tonal:
        button = FilledButton.tonal(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
            foregroundColor: isDark ? AppColors.brand : AppColors.brandDark,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
          ),
          child: content,
        );
        break;
    }

    return SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: button,
    );
  }
}
