// lib/core/widgets/app_progress_bar.dart
// Athletic Training & Attendance Progress Gauge
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? color;
  final Color? trackColor;
  final bool isAnimated;

  const AppProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.color,
    this.trackColor,
    this.isAnimated = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = color ?? (isDark ? AppColors.brand : AppColors.brandDark);
    final bgTrack = trackColor ?? (isDark ? AppColors.dSurfaceElevated : AppColors.lSurfaceAlt);
    final clamped = progress.clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bgTrack,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: clamped,
        child: Container(
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: clamped > 0.05
                ? [
                    BoxShadow(
                      color: barColor.withAlpha(80),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
