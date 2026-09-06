// lib/features/workouts/presentation/workout_complete_dialog.dart
// Workout Celebration & Volume Breakdown Modal
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';

class WorkoutCompleteDialog extends StatelessWidget {
  final String routineTitle;
  final int durationMinutes;
  final int completedSets;
  final double totalVolumeKg;

  const WorkoutCompleteDialog({
    super.key,
    required this.routineTitle,
    required this.durationMinutes,
    required this.completedSets,
    required this.totalVolumeKg,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.dSurface : AppColors.lSurface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fire / Trophy Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.flameGlow,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.flameStreak, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.flameStreak,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'WORKOUT COMPLETE!',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 18,
                letterSpacing: 2.0,
                color: AppColors.flameStreak,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              routineTitle,
              style: AppTypography.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Metrics Grid
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'DURATION',
                    value: '$durationMinutes min',
                    icon: Icons.timer_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'SETS DONE',
                    value: '$completedSets',
                    icon: Icons.fitness_center_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    label: 'VOLUME',
                    value: '${totalVolumeKg.toInt()} kg',
                    icon: Icons.bolt_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Save & Return to Dashboard',
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Exit session screen
              },
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.brand),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.labelAthletic.copyWith(
              fontSize: 8,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
