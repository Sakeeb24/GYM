// lib/core/widgets/app_loading_state.dart
// Athletic Neon Loader
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppLoadingState extends StatelessWidget {
  final double strokeWidth;
  final Color? color;

  const AppLoadingState({super.key, this.strokeWidth = 3.0, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? AppColors.brand : AppColors.brandDark);
    return Center(
      child: SizedBox.square(
        dimension: 36,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          color: c,
          backgroundColor: c.withAlpha(40),
        ),
      ),
    );
  }
}
