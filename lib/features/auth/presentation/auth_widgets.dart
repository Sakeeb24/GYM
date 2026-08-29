// lib/features/auth/presentation/auth_widgets.dart
// Athletic Onboarding & Auth Shared Widgets
import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_colors.dart';

/// Three-step progress bar with athletic labels (01 PERSONAL • 02 VERIFY • 03 ACCOUNT)
class AuthStepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const AuthStepIndicator({super.key, required this.current, required this.total});

  static const _stepLabels = ['PERSONAL', 'VERIFY', 'ACCOUNT'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(total, (i) {
            final active = i < current;
            final isCurrent = i == current - 1;
            final label = i < _stepLabels.length ? _stepLabels[i] : 'STEP 0${i + 1}';
            return Text(
              '0${i + 1} $label',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 10,
                color: isCurrent
                    ? (isDark ? AppColors.brand : AppColors.brandDark)
                    : active
                        ? AppColors.success
                        : cs.onSurfaceVariant.withAlpha(120),
                fontWeight: isCurrent || active ? FontWeight.w800 : FontWeight.w600,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(total, (i) {
            final active = i < current;
            final isCurrent = i == current - 1;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? (isDark ? AppColors.brand : AppColors.brandDark)
                      : active
                          ? AppColors.success
                          : (isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceAlt),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Red error banner shown inside auth & registration screens.
class AuthErrorBanner extends StatelessWidget {
  final String message;
  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withAlpha(120), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
