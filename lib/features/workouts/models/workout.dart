// lib/features/workouts/models/workout.dart
// Athletic Training & Exercise Data Models

class ExerciseSet {
  final int setNumber;
  double weightKg;
  int reps;
  bool isCompleted;

  ExerciseSet({
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    this.isCompleted = false,
  });
}

class Exercise {
  final String id;
  final String name;
  final String targetMuscle;
  final String equipment;
  final List<ExerciseSet> sets;
  final String instructions;

  Exercise({
    required this.id,
    required this.name,
    required this.targetMuscle,
    required this.equipment,
    required this.sets,
    required this.instructions,
  });
}

class WorkoutRoutine {
  final String id;
  final String title;
  final String category; // Push, Pull, Legs, Upper, Lower, Cardio
  final String estimatedTime;
  final int totalExercises;
  final String difficulty;
  final List<Exercise> exercises;

  WorkoutRoutine({
    required this.id,
    required this.title,
    required this.category,
    required this.estimatedTime,
    required this.totalExercises,
    required this.difficulty,
    required this.exercises,
  });
}

class WorkoutTemplateData {
  static List<WorkoutRoutine> getRoutines() {
    return [
      WorkoutRoutine(
        id: 'push_hypertrophy',
        title: 'Push Power & Hypertrophy',
        category: 'Push',
        estimatedTime: '45 mins',
        totalExercises: 4,
        difficulty: 'Intermediate',
        exercises: [
          Exercise(
            id: 'bench_press',
            name: 'Barbell Bench Press',
            targetMuscle: 'Chest / Triceps',
            equipment: 'Barbell & Bench',
            instructions: 'Keep your shoulder blades retracted and drive through your feet.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 60, reps: 10),
              ExerciseSet(setNumber: 2, weightKg: 70, reps: 8),
              ExerciseSet(setNumber: 3, weightKg: 80, reps: 6),
            ],
          ),
          Exercise(
            id: 'incline_db_press',
            name: 'Incline Dumbbell Press',
            targetMuscle: 'Upper Chest',
            equipment: 'Dumbbells & 30° Bench',
            instructions: 'Lower dumbbells slowly and press up with a controlled arc.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 22, reps: 10),
              ExerciseSet(setNumber: 2, weightKg: 24, reps: 10),
              ExerciseSet(setNumber: 3, weightKg: 26, reps: 8),
            ],
          ),
          Exercise(
            id: 'lateral_raises',
            name: 'Dumbbell Lateral Raises',
            targetMuscle: 'Side Delts',
            equipment: 'Dumbbells',
            instructions: 'Lead with your elbows and maintain a slight forward lean.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 10, reps: 15),
              ExerciseSet(setNumber: 2, weightKg: 10, reps: 12),
              ExerciseSet(setNumber: 3, weightKg: 12, reps: 10),
            ],
          ),
          Exercise(
            id: 'cable_tricep_pushdown',
            name: 'Cable Tricep Pushdowns',
            targetMuscle: 'Triceps',
            equipment: 'Cable Machine',
            instructions: 'Pin elbows to your sides and lock out at the bottom.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 25, reps: 12),
              ExerciseSet(setNumber: 2, weightKg: 30, reps: 10),
              ExerciseSet(setNumber: 3, weightKg: 35, reps: 8),
            ],
          ),
        ],
      ),
      WorkoutRoutine(
        id: 'pull_strength',
        title: 'Pull & Lat Focus',
        category: 'Pull',
        estimatedTime: '50 mins',
        totalExercises: 4,
        difficulty: 'Advanced',
        exercises: [
          Exercise(
            id: 'deadlift',
            name: 'Conventional Deadlift',
            targetMuscle: 'Back / Hamstrings',
            equipment: 'Barbell',
            instructions: 'Hinge at the hips, brace your core, and stand up tall.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 100, reps: 6),
              ExerciseSet(setNumber: 2, weightKg: 120, reps: 5),
              ExerciseSet(setNumber: 3, weightKg: 140, reps: 3),
            ],
          ),
          Exercise(
            id: 'lat_pulldown',
            name: 'Lat Pulldown (Wide Grip)',
            targetMuscle: 'Lats',
            equipment: 'Cable Pulldown',
            instructions: 'Pull the bar to your upper collarbone and squeeze shoulder blades.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 50, reps: 12),
              ExerciseSet(setNumber: 2, weightKg: 55, reps: 10),
              ExerciseSet(setNumber: 3, weightKg: 60, reps: 8),
            ],
          ),
          Exercise(
            id: 'seated_cable_row',
            name: 'Seated Cable Row',
            targetMuscle: 'Mid Back / Rhomboids',
            equipment: 'Cable Row Machine',
            instructions: 'Keep your torso upright and pull to your lower abdomen.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 45, reps: 12),
              ExerciseSet(setNumber: 2, weightKg: 50, reps: 10),
              ExerciseSet(setNumber: 3, weightKg: 55, reps: 10),
            ],
          ),
          Exercise(
            id: 'barbell_bicep_curl',
            name: 'EZ-Bar Bicep Curls',
            targetMuscle: 'Biceps',
            equipment: 'EZ Curl Bar',
            instructions: 'Avoid swinging your torso; isolate the bicep contraction.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 20, reps: 12),
              ExerciseSet(setNumber: 2, weightKg: 25, reps: 10),
              ExerciseSet(setNumber: 3, weightKg: 30, reps: 8),
            ],
          ),
        ],
      ),
      WorkoutRoutine(
        id: 'leg_day_volume',
        title: 'Legs & Core Builder',
        category: 'Legs',
        estimatedTime: '45 mins',
        totalExercises: 4,
        difficulty: 'Intermediate',
        exercises: [
          Exercise(
            id: 'barbell_squat',
            name: 'Barbell Back Squats',
            targetMuscle: 'Quads / Glutes',
            equipment: 'Squat Rack & Barbell',
            instructions: 'Descend until hip crease is below knee level.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 70, reps: 10),
              ExerciseSet(setNumber: 2, weightKg: 85, reps: 8),
              ExerciseSet(setNumber: 3, weightKg: 100, reps: 6),
            ],
          ),
          Exercise(
            id: 'romanian_deadlift',
            name: 'Romanian Deadlift (Dumbbell)',
            targetMuscle: 'Hamstrings / Glutes',
            equipment: 'Dumbbells',
            instructions: 'Push hips back while keeping a flat spine.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 24, reps: 10),
              ExerciseSet(setNumber: 2, weightKg: 28, reps: 10),
              ExerciseSet(setNumber: 3, weightKg: 32, reps: 8),
            ],
          ),
          Exercise(
            id: 'leg_press',
            name: 'Incline Leg Press',
            targetMuscle: 'Quads',
            equipment: 'Leg Press Machine',
            instructions: 'Place feet shoulder-width and drive through mid-foot.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 120, reps: 12),
              ExerciseSet(setNumber: 2, weightKg: 150, reps: 10),
              ExerciseSet(setNumber: 3, weightKg: 180, reps: 8),
            ],
          ),
          Exercise(
            id: 'standing_calf_raise',
            name: 'Standing Calf Raises',
            targetMuscle: 'Calves',
            equipment: 'Calf Machine',
            instructions: 'Pause at the peak contraction and lower slowly.',
            sets: [
              ExerciseSet(setNumber: 1, weightKg: 40, reps: 15),
              ExerciseSet(setNumber: 2, weightKg: 45, reps: 15),
              ExerciseSet(setNumber: 3, weightKg: 50, reps: 12),
            ],
          ),
        ],
      ),
    ];
  }
}
