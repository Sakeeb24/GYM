// lib/features/workouts/presentation/workout_screen.dart
// Athletic Workout Tracker & Split Routines (Apex Precision)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../models/workout.dart';
import 'workout_session_screen.dart';

class WorkoutScreen extends ConsumerStatefulWidget {
  const WorkoutScreen({super.key});

  @override
  ConsumerState<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends ConsumerState<WorkoutScreen> {
  String _selectedCategory = 'All';
  final List<WorkoutRoutine> _routines = WorkoutTemplateData.getRoutines();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredRoutines = _selectedCategory == 'All'
        ? _routines
        : _routines.where((r) => r.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TRAINING & WORKOUTS',
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 16,
            letterSpacing: 2.0,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Today's Recommended Routine Hero Card ─────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.dSurface : AppColors.lSurface,
                borderRadius: AppRadii.card,
                border: Border.all(
                  color: isDark ? AppColors.brand.withAlpha(60) : AppColors.brandDark.withAlpha(50),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.brandGlow,
                    blurRadius: 16,
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.brand.withAlpha(30) : AppColors.brandContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "TODAY'S SPLIT",
                          style: AppTypography.labelAthletic.copyWith(
                            fontSize: 10,
                            color: isDark ? AppColors.brand : AppColors.brandDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: AppColors.brand),
                          const SizedBox(width: 4),
                          Text(
                            _routines.first.estimatedTime,
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark ? AppColors.dTextSecondary : AppColors.lTextSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _routines.first.title,
                    style: AppTypography.headlineLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_routines.first.totalExercises} exercises • ${_routines.first.difficulty} Level',
                    style: AppTypography.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: 'Start Workout Now',
                    icon: const Icon(Icons.play_arrow_rounded),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkoutSessionScreen(routine: _routines.first),
                        ),
                      );
                    },
                    fullWidth: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 2. Category Filter Pills ─────────────────────────────────────
            Text(
              'TRAINING SPLITS',
              style: AppTypography.labelAthletic.copyWith(
                fontSize: 11,
                letterSpacing: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Push', 'Pull', 'Legs'].map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedCategory = cat),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.white)
                            : cs.onSurface,
                      ),
                      selectedColor: isDark ? AppColors.brand : AppColors.brandDark,
                      backgroundColor: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: cs.outline),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // ── 3. Routine List ──────────────────────────────────────────────
            ...filteredRoutines.map((routine) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.dSurface : AppColors.lSurface,
                  borderRadius: AppRadii.card,
                  border: Border.all(color: cs.outline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.fitness_center_rounded,
                          color: isDark ? AppColors.brand : AppColors.brandDark,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.title,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${routine.totalExercises} Exercises • ${routine.estimatedTime}',
                            style: AppTypography.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutSessionScreen(routine: routine),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
