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
          children: List.generate(total, (i) {
            final active = i < current;
            final isCurrent = i == current - 1;
            final label = i < _stepLabels.length ? _stepLabels[i] : 'STEP 0${i + 1}';
            final align = i == 0
                ? TextAlign.start
                : i == total - 1
                    ? TextAlign.end
                    : TextAlign.center;
            return Expanded(
              child: Text(
                '0${i + 1} $label',
                textAlign: align,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelAthletic.copyWith(
                  fontSize: 10,
                  color: isCurrent
                      ? (isDark ? AppColors.brand : AppColors.brandDark)
                      : active
                          ? AppColors.success
                          : cs.onSurfaceVariant.withAlpha(120),
                  fontWeight: isCurrent || active ? FontWeight.w800 : FontWeight.w600,
                ),
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
  final VoidCallback? onRetry;
  final String? retryLabel;

  const AuthErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withAlpha(120), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(
                  retryLabel ?? 'Retry',
                  style: AppTypography.labelAthletic.copyWith(
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reassuring athletic card clarifying member verification rules (e.g. No SMS OTP).
class RegistrationContextCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const RegistrationContextCard({
    super.key,
    this.icon = Icons.verified_user_outlined,
    this.title = 'Gym Member Verification',
    this.subtitle = 'Phone number is recorded for gym attendance & records. No SMS OTP is required.',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dSurfaceElevated.withAlpha(140) : AppColors.lSurfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.brand.withAlpha(40) : cs.outlineVariant.withAlpha(60),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.brand.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: isDark ? AppColors.brand : AppColors.brandDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelAthletic.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.brand : AppColors.brandDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical animated laser line sweeping the camera viewfinder HUD.
class ScannerLaserOverlay extends StatefulWidget {
  final double height;
  final double width;
  final Color laserColor;

  const ScannerLaserOverlay({
    super.key,
    this.height = 200,
    this.width = 200,
    this.laserColor = AppColors.brand,
  });

  @override
  State<ScannerLaserOverlay> createState() => _ScannerLaserOverlayState();
}

class _ScannerLaserOverlayState extends State<ScannerLaserOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutSine,
    );

    // In unit/widget tests, pumpAndSettle times out on endless animations.
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTesting) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final topPosition = _animation.value * (widget.height - 4);
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            children: [
              Positioned(
                top: topPosition,
                left: 6,
                right: 6,
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.laserColor.withAlpha(0),
                        widget.laserColor,
                        widget.laserColor.withAlpha(0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.laserColor.withAlpha(180),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dynamic checklist item for real-time password & credential requirements.
class CredentialRequirementItem extends StatelessWidget {
  final String label;
  final bool isMet;

  const CredentialRequirementItem({
    super.key,
    required this.label,
    required this.isMet,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMet ? AppColors.success.withAlpha(40) : cs.surfaceContainerHighest.withAlpha(120),
              border: Border.all(
                color: isMet ? AppColors.success : cs.outlineVariant.withAlpha(100),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Icon(
                isMet ? Icons.check_rounded : Icons.circle,
                size: isMet ? 11 : 4,
                color: isMet ? AppColors.success : cs.onSurfaceVariant.withAlpha(100),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                color: isMet ? AppColors.success : cs.onSurfaceVariant,
                fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}
