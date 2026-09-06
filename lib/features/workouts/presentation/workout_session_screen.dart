// lib/features/workouts/presentation/workout_session_screen.dart
// Active Workout Session Logger with Rest Timer (Apex Precision)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../models/workout.dart';
import 'workout_complete_dialog.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final WorkoutRoutine routine;
  const WorkoutSessionScreen({super.key, required this.routine});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  late DateTime _startTime;
  int _restSecondsRemaining = 0;
  Timer? _restTimer;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    HapticFeedback.mediumImpact();
    setState(() => _restSecondsRemaining = seconds);

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining > 0) {
        setState(() => _restSecondsRemaining--);
      } else {
        HapticFeedback.heavyImpact();
        timer.cancel();
      }
    });
  }

  void _finishWorkout() {
    final duration = DateTime.now().difference(_startTime);
    int completedSets = 0;
    double totalVolume = 0;

    for (final ex in widget.routine.exercises) {
      for (final s in ex.sets) {
        if (s.isCompleted) {
          completedSets++;
          totalVolume += (s.weightKg * s.reps);
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WorkoutCompleteDialog(
        routineTitle: widget.routine.title,
        durationMinutes: duration.inMinutes > 0 ? duration.inMinutes : 1,
        completedSets: completedSets,
        totalVolumeKg: totalVolume,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.routine.title.toUpperCase(),
          style: AppTypography.labelAthletic.copyWith(
            fontSize: 14,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _finishWorkout,
              child: Text(
                'FINISH',
                style: AppTypography.labelAthletic.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Rest Timer Bar (Sticky) ──────────────────────────────────────
          if (_restSecondsRemaining > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: isDark ? AppColors.brand.withAlpha(40) : AppColors.brandContainer,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_rounded, color: AppColors.brand, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Rest Timer: ${_restSecondsRemaining}s',
                        style: AppTypography.labelAthletic.copyWith(
                          fontSize: 13,
                          color: isDark ? AppColors.brand : AppColors.brandDark,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      _restTimer?.cancel();
                      setState(() => _restSecondsRemaining = 0);
                    },
                    child: Text(
                      'SKIP',
                      style: AppTypography.labelAthletic.copyWith(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Exercises List ───────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: widget.routine.exercises.length,
              itemBuilder: (ctx, index) {
                final exercise = widget.routine.exercises[index];
                return _ExerciseCard(
                  exercise: exercise,
                  onSetCompleted: () => _startRestTimer(60),
                );
              },
            ),
          ),

          // ── Bottom Action ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.dSurface : AppColors.lSurface,
              border: Border(top: BorderSide(color: cs.outline)),
            ),
            child: SafeArea(
              child: AppButton(
                text: 'Finish Workout',
                icon: const Icon(Icons.check_circle_outline_rounded),
                onPressed: _finishWorkout,
                fullWidth: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onSetCompleted;

  const _ExerciseCard({
    required this.exercise,
    required this.onSetCompleted,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dSurface : AppColors.lSurface,
        borderRadius: AppRadii.card,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.exercise.name,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                widget.exercise.targetMuscle,
                style: AppTypography.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.exercise.instructions,
            style: AppTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          // Sets Table Header
          Row(
            children: [
              const SizedBox(width: 36, child: Text('SET', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              const Expanded(child: Center(child: Text('KG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
              const Expanded(child: Center(child: Text('REPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 48, child: Center(child: Text('DONE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))),
            ],
          ),
          const SizedBox(height: 8),

          // Sets rows
          ...widget.exercise.sets.map((set) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '#${set.setNumber}',
                      style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${set.weightKg} kg',
                        style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.dSurfaceAlt : AppColors.lSurfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${set.reps}',
                        style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    height: 36,
                    child: IconButton(
                      icon: Icon(
                        set.isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: set.isCompleted ? AppColors.brand : cs.outline,
                        size: 22,
                      ),
                      onPressed: () {
                        setState(() => set.isCompleted = !set.isCompleted);
                        if (set.isCompleted) {
                          widget.onSetCompleted();
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
