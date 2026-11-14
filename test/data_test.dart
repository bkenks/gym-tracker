import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_tracker/data/database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('seeded exercises load from bundled asset', () async {
    final all = await db.select(db.exercises).get();
    expect(all.length, greaterThan(150));
    expect(all.any((e) => e.name == 'Barbell Bench Press'), isTrue);
    expect(all.any((e) => e.primaryMuscle == MuscleGroups.quads), isTrue);
  });

  test('full workout lifecycle: start, log sets, finish, stats', () async {
    final exercise = (await db.select(db.exercises).get()).first;

    // Start empty workout.
    final workoutId = await db.startWorkout(name: 'Test Workout');
    var active = await db.watchActiveWorkout().first;
    expect(active!.workout.id, workoutId);
    expect(active.entries, isEmpty);

    // Add exercise with a template set.
    await db.addExerciseToWorkout(
      workoutId,
      RoutineExerciseInput(
        exerciseId: exercise.id,
        sets: const [SetInput(reps: 10), SetInput(reps: 10)],
      ),
    );
    active = await db.watchActiveWorkout().first;
    expect(active!.entries.single.sets.length, 2);

    // Complete both sets with values.
    final sets = active.entries.single.sets;
    await db.updateWorkoutSet(sets[0].id,
        const SetInput(weightKg: 100, reps: 10, isCompleted: true));
    await db.updateWorkoutSet(sets[1].id,
        const SetInput(weightKg: 110, reps: 5, isCompleted: true));
    await db.addSetToExercise(
        active.entries.single.workoutExercise.id,
        const SetInput(weightKg: 120, reps: 3, isCompleted: true));

    // Finish.
    await db.finishWorkout(workoutId, bodyWeightKg: 80);
    expect(await db.watchActiveWorkout().first, isNull);

    final history = await db.watchWorkoutHistory().first;
    expect(history.length, 1);
    final done = history.single;
    expect(done.completedSets, 3);
    expect(done.totalVolume, closeTo(100 * 10 + 110 * 5 + 120 * 3, 0.01));

    // Stats & records reflect the completed work.
    final stats = await db.exerciseVolumeHistory(exercise.id);
    expect(stats.length, 1);
    expect(stats.single.volume, done.totalVolume);
    expect(stats.single.bestEstimated1Rm, greaterThan(120));

    final records = await db.exerciseRecords(exercise.id);
    expect(records.maxWeight, 120);
    expect(records.maxEstimated1Rm, stats.single.bestEstimated1Rm);

    // Last-set defaults for the next session.
    final last = await db.lastSetForExercise(exercise.id);
    expect(last!.weightKg, 120);
    expect(last.reps, 3);
  });

  test('routines save, load and delete', () async {
    final ex = (await db.select(db.exercises).get()).take(2).toList();
    final id = await db.saveRoutine(
      name: 'Push Day',
      exercisesInput: [
        RoutineExerciseInput(
          exerciseId: ex[0].id,
          restSeconds: 90,
          sets: const [SetInput(weightKg: 60, reps: 8)],
        ),
        RoutineExerciseInput(
          exerciseId: ex[1].id,
          sets: const [SetInput(reps: 12), SetInput(reps: 12)],
        ),
      ],
    );

    final full = await db.getFullRoutine(id);
    expect(full!.routine.name, 'Push Day');
    expect(full.entries.length, 2);
    expect(full.entries[0].sets.single.weightKg, 60);
    expect(full.entries[1].sets.length, 2);

    await db.deleteRoutine(id);
    expect(await db.getFullRoutine(id), isNull);
  });

  test('discard removes workout and its sets', () async {
    final exercise = (await db.select(db.exercises).get()).first;
    final workoutId = await db.startWorkout(name: 'Abandoned');
    await db.addExerciseToWorkout(
        workoutId, RoutineExerciseInput(exerciseId: exercise.id));
    await db.abandonWorkout(workoutId);
    expect(await db.watchActiveWorkout().first, isNull);
    expect(await db.watchWorkoutHistory().first, isEmpty);
    expect(await db.select(db.workoutSets).get(), isEmpty);
  });

  test('body weight upsert per day', () async {
    final day = DateTime(2026, 11, 12);
    await db.upsertBodyWeight(80, day);
    await db.upsertBodyWeight(81, day);
    final all = await db.select(db.bodyWeights).get();
    expect(all.length, 1);
    expect(all.single.weightKg, 81);
  });

  test('custom exercise insert', () async {
    final id = await db.insertCustomExercise(const ExercisesCompanion(
      name: Value('My Weird Exercise'),
      primaryMuscle: Value(MuscleGroups.chest),
      equipment: Value('Other'),
      isCustom: Value(true),
    ));
    final created = await (db.select(db.exercises)
          ..where((e) => e.id.equals(id)))
        .getSingle();
    expect(created.isCustom, isTrue);
  });
}
