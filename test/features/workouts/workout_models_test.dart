// test/features/workouts/workout_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liftflow/features/workouts/models/workout.dart';

void main() {
  group('Workout Models & Templates', () {
    test('WorkoutTemplateData returns valid routines', () {
      final routines = WorkoutTemplateData.getRoutines();
      expect(routines, isNotEmpty);
      expect(routines.length, greaterThanOrEqualTo(3));

      for (final routine in routines) {
        expect(routine.title, isNotEmpty);
        expect(routine.category, isNotEmpty);
        expect(routine.exercises, isNotEmpty);
        expect(routine.totalExercises, equals(routine.exercises.length));

        for (final ex in routine.exercises) {
          expect(ex.name, isNotEmpty);
          expect(ex.sets, isNotEmpty);
          for (final s in ex.sets) {
            expect(s.setNumber, greaterThan(0));
            expect(s.weightKg, greaterThan(0));
            expect(s.reps, greaterThan(0));
            expect(s.isCompleted, isFalse);
          }
        }
      }
    });

    test('ExerciseSet completion toggle works accurately', () {
      final set = ExerciseSet(setNumber: 1, weightKg: 80, reps: 10);
      expect(set.isCompleted, isFalse);
      set.isCompleted = true;
      expect(set.isCompleted, isTrue);
    });
  });
}
