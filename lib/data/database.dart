import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

part 'database.g.dart';

enum SetType { normal, warmup, drop, failure }

/// Muscle group names used for exercises.
class MuscleGroups {
  static const chest = 'Chest';
  static const back = 'Back';
  static const shoulders = 'Shoulders';
  static const biceps = 'Biceps';
  static const triceps = 'Triceps';
  static const forearms = 'Forearms';
  static const abs = 'Abs';
  static const quads = 'Quads';
  static const hamstrings = 'Hamstrings';
  static const glutes = 'Glutes';
  static const calves = 'Calves';
  static const fullBody = 'Full Body';
  static const cardio = 'Cardio';

  static const all = [
    chest,
    back,
    shoulders,
    biceps,
    triceps,
    forearms,
    abs,
    quads,
    hamstrings,
    glutes,
    calves,
    fullBody,
    cardio,
  ];
}

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get primaryMuscle => text()();
  /// JSON-encoded list of secondary muscle group names.
  TextColumn get secondaryMuscles => text().withDefault(const Constant('[]'))();
  TextColumn get equipment => text()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class RoutineExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get restSeconds => integer().withDefault(const Constant(120))();
}

class RoutineSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineExerciseId =>
      integer().references(RoutineExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get setType => textEnum<SetType>().withDefault(const Constant('normal'))();
  RealColumn get weightKg => real().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(10))();
}

class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get routineId => integer().nullable().references(Routines, #id)();
  /// Snapshot of the routine name at start time (routines may be edited later).
  TextColumn get routineName => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  RealColumn get bodyWeightKg => real().nullable()();
}

class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  IntColumn get restSeconds => integer().withDefault(const Constant(120))();
  /// Groups exercises into a superset when equal and non-null.
  IntColumn get supersetId => integer().nullable()();
}

class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutExerciseId =>
      integer().references(WorkoutExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get setType => textEnum<SetType>().withDefault(const Constant('normal'))();
  RealColumn get weightKg => real().withDefault(const Constant(0))();
  IntColumn get reps => integer().withDefault(const Constant(0))();
  RealColumn get rpe => real().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}

class BodyWeights extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get weightKg => real()();
  DateTimeColumn get date => dateTime()();
}

@DriftDatabase(
  tables: [Exercises, Routines, RoutineExercises, RoutineSets, Workouts, WorkoutExercises, WorkoutSets, BodyWeights],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'gym_tracker'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // No migrations yet (schemaVersion 1).
        },
        beforeOpen: (details) async {
          if (details.wasCreated) {
            await _seedExercises();
          }
        },
      );

  Future<void> _seedExercises() async {
    try {
      final json = await rootBundle.loadString('assets/seed/exercises.json');
      final List<dynamic> list = jsonDecode(json) as List<dynamic>;
      final rows = list
          .map((e) => ExercisesCompanion(
                name: Value(e['name'] as String),
                primaryMuscle: Value(e['primaryMuscle'] as String),
                secondaryMuscles:
                    Value(jsonEncode(e['secondaryMuscles'] ?? [])),
                equipment: Value(e['equipment'] as String),
              ))
          .toList();
      await batch((b) => b.insertAll(exercises, rows));
    } catch (e) {
      debugPrint('Failed to seed exercises: $e');
    }
  }

  // ------------------------------------------------------------------
  // Exercises
  // ------------------------------------------------------------------

  Stream<List<Exercise>> watchExercises({
    String query = '',
    String? muscle,
    String? equipment,
  }) {
    var q = select(exercises)
      ..orderBy([(e) => OrderingTerm(expression: e.name.lower())]);
    if (query.isNotEmpty) {
      q = select(exercises)
        ..where((e) => e.name.lower().like('%${query.toLowerCase()}%'))
        ..orderBy([(e) => OrderingTerm(expression: e.name.lower())]);
    }
    // Apply filters in Dart to keep the query simple and composable.
    return q.watch().map((rows) => rows.where((e) {
          if (muscle != null && e.primaryMuscle != muscle) return false;
          if (equipment != null && e.equipment != equipment) return false;
          return true;
        }).toList());
  }

  Future<int> insertCustomExercise(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  // ------------------------------------------------------------------
  // Routines
  // ------------------------------------------------------------------

  Future<List<Routine>> watchRoutines() async => select(routines).get();

  Stream<List<Routine>> routinesStream() =>
      (select(routines)..orderBy([(r) => OrderingTerm.desc(r.updatedAt)])).watch();

  /// Full routine: exercises + their template sets, ordered by position.
  Future<FullRoutine?> getFullRoutine(int routineId) async {
    final routine = await (select(routines)..where((r) => r.id.equals(routineId)))
        .getSingleOrNull();
    if (routine == null) return null;
    final exRows = await (select(routineExercises)
          ..where((e) => e.routineId.equals(routineId))
          ..orderBy([(e) => OrderingTerm.asc(e.position)]))
        .get();
    final result = <RoutineExerciseEntry>[];
    for (final re in exRows) {
      final exercise = await (select(exercises)
            ..where((e) => e.id.equals(re.exerciseId)))
          .getSingleOrNull();
      final sets = await (select(routineSets)
            ..where((s) => s.routineExerciseId.equals(re.id))
            ..orderBy([(s) => OrderingTerm.asc(s.position)]))
          .get();
      if (exercise != null) {
        result.add(RoutineExerciseEntry(routineExercise: re, exercise: exercise, sets: sets));
      }
    }
    return FullRoutine(routine: routine, entries: result);
  }

  Future<int> saveRoutine({
    int? routineId,
    required String name,
    required List<RoutineExerciseInput> exercisesInput,
  }) async {
    return transaction(() async {
      final id = routineId ??
          await into(routines).insert(RoutinesCompanion(name: Value(name)));
      if (routineId != null) {
        await (update(routines)..where((r) => r.id.equals(routineId)))
            .write(RoutinesCompanion(
          name: Value(name),
          updatedAt: Value(DateTime.now()),
        ));
        await _deleteRoutineChildren(routineId);
      }
      for (var i = 0; i < exercisesInput.length; i++) {
        final input = exercisesInput[i];
        final reId = await into(routineExercises).insert(RoutineExercisesCompanion(
          routineId: Value(id),
          exerciseId: Value(input.exerciseId),
          position: Value(i),
          restSeconds: Value(input.restSeconds),
          notes: Value(input.notes),
        ));
        for (var j = 0; j < input.sets.length; j++) {
          final s = input.sets[j];
          await into(routineSets).insert(RoutineSetsCompanion(
            routineExerciseId: Value(reId),
            position: Value(j),
            setType: Value(s.setType),
            weightKg: Value(s.weightKg),
            reps: Value(s.reps),
          ));
        }
      }
      return id;
    });
  }

  Future<void> deleteRoutine(int routineId) async {
    await transaction(() async {
      await _deleteRoutineChildren(routineId);
      await (delete(routines)..where((r) => r.id.equals(routineId))).go();
    });
  }

  Future<void> _deleteRoutineChildren(int routineId) async {
    final reIds = await (selectOnly(routineExercises)
          ..addColumns([routineExercises.id])
          ..where(routineExercises.routineId.equals(routineId)))
        .map((row) => row.read(routineExercises.id)!)
        .get();
    if (reIds.isNotEmpty) {
      await (delete(routineSets)..where((s) => s.routineExerciseId.isIn(reIds))).go();
    }
    await (delete(routineExercises)..where((e) => e.routineId.equals(routineId))).go();
  }

  // ------------------------------------------------------------------
  // Workouts
  // ------------------------------------------------------------------

  Future<int> startWorkout({
    required String name,
    int? routineId,
    String? routineName,
    List<RoutineExerciseInput>? templateExercises,
  }) async {
    return transaction(() async {
      final workoutId = await into(workouts).insert(WorkoutsCompanion(
        name: Value(name),
        routineId: Value(routineId),
        routineName: Value(routineName),
        startedAt: Value(DateTime.now()),
      ));
      if (templateExercises != null) {
        for (var i = 0; i < templateExercises.length; i++) {
          await _addExerciseToWorkout(workoutId, templateExercises[i], i);
        }
      }
      return workoutId;
    });
  }

  Future<int> addExerciseToWorkout(int workoutId, RoutineExerciseInput input) async {
    final count = await (selectOnly(workoutExercises)
          ..addColumns([workoutExercises.id.count()])
          ..where(workoutExercises.workoutId.equals(workoutId)))
        .map((row) => row.read(workoutExercises.id.count())!)
        .getSingle();
    return _addExerciseToWorkout(workoutId, input, count);
  }

  Future<int> _addExerciseToWorkout(
      int workoutId, RoutineExerciseInput input, int position) async {
    final weId = await into(workoutExercises).insert(WorkoutExercisesCompanion(
      workoutId: Value(workoutId),
      exerciseId: Value(input.exerciseId),
      position: Value(position),
      restSeconds: Value(input.restSeconds),
      notes: Value(input.notes),
    ));
    for (var j = 0; j < input.sets.length; j++) {
      final s = input.sets[j];
      await into(workoutSets).insert(WorkoutSetsCompanion(
        workoutExerciseId: Value(weId),
        position: Value(j),
        setType: Value(s.setType),
        weightKg: Value(s.weightKg),
        reps: Value(s.reps),
      ));
    }
    return weId;
  }

  Future<void> deleteWorkoutExercise(int workoutExerciseId) async {
    await transaction(() async {
      await (delete(workoutSets)
            ..where((s) => s.workoutExerciseId.equals(workoutExerciseId)))
          .go();
      await (delete(workoutExercises)..where((e) => e.id.equals(workoutExerciseId)))
          .go();
    });
  }

  Future<void> addSetToExercise(int workoutExerciseId, SetInput set) async {
    final count = await (selectOnly(workoutSets)
          ..addColumns([workoutSets.id.count()])
          ..where(workoutSets.workoutExerciseId.equals(workoutExerciseId)))
        .map((row) => row.read(workoutSets.id.count())!)
        .getSingle();
    await into(workoutSets).insert(WorkoutSetsCompanion(
      workoutExerciseId: Value(workoutExerciseId),
      position: Value(count),
      setType: Value(set.setType),
      weightKg: Value(set.weightKg),
      reps: Value(set.reps),
      isCompleted: Value(set.isCompleted),
    ));
  }

  Future<void> updateWorkoutSet(int setId, SetInput set) async {
    await (update(workoutSets)..where((s) => s.id.equals(setId))).write(
      WorkoutSetsCompanion(
        setType: Value(set.setType),
        weightKg: Value(set.weightKg),
        reps: Value(set.reps),
        rpe: Value(set.rpe),
        isCompleted: Value(set.isCompleted),
      ),
    );
  }

  Future<void> deleteWorkoutSet(int setId) async {
    await (delete(workoutSets)..where((s) => s.id.equals(setId))).go();
  }

  Future<void> finishWorkout(int workoutId, {String? notes, double? bodyWeightKg}) async {
    await (update(workouts)..where((w) => w.id.equals(workoutId))).write(
      WorkoutsCompanion(
        completedAt: Value(DateTime.now()),
        notes: notes != null ? Value(notes) : const Value.absent(),
        bodyWeightKg: bodyWeightKg != null ? Value(bodyWeightKg) : const Value.absent(),
      ),
    );
  }

  Future<void> abandonWorkout(int workoutId) async {
    await transaction(() async {
      final weIds = await (selectOnly(workoutExercises)
            ..addColumns([workoutExercises.id])
            ..where(workoutExercises.workoutId.equals(workoutId)))
          .map((row) => row.read(workoutExercises.id)!)
          .get();
      if (weIds.isNotEmpty) {
        await (delete(workoutSets)..where((s) => s.workoutExerciseId.isIn(weIds))).go();
      }
      await (delete(workoutExercises)..where((e) => e.workoutId.equals(workoutId))).go();
      await (delete(workouts)..where((w) => w.id.equals(workoutId))).go();
    });
  }

  Stream<FullWorkout?> watchActiveWorkout() {
    final query = select(workouts)
      ..where((w) => w.completedAt.isNull())
      ..orderBy([(w) => OrderingTerm.desc(w.startedAt)])
      ..limit(1);
    return query.watchSingleOrNull().asyncExpand((workout) async* {
      if (workout == null) {
        yield null;
        return;
      }
      yield* Stream.fromFuture(_loadFullWorkout(workout));
    });
  }

  Future<FullWorkout> _loadFullWorkout(Workout workout) async {
    final exRows = await (select(workoutExercises)
          ..where((e) => e.workoutId.equals(workout.id))
          ..orderBy([(e) => OrderingTerm.asc(e.position)]))
        .get();
    final entries = <WorkoutExerciseEntry>[];
    for (final we in exRows) {
      final exercise = await (select(exercises)..where((e) => e.id.equals(we.exerciseId)))
          .getSingleOrNull();
      final sets = await (select(workoutSets)
            ..where((s) => s.workoutExerciseId.equals(we.id))
            ..orderBy([(s) => OrderingTerm.asc(s.position)]))
          .get();
      if (exercise != null) {
        entries.add(WorkoutExerciseEntry(workoutExercise: we, exercise: exercise, sets: sets));
      }
    }
    return FullWorkout(workout: workout, entries: entries);
  }

  /// History of completed workouts, newest first.
  Stream<List<FullWorkout>> watchWorkoutHistory() {
    return (select(workouts)
          ..where((w) => w.completedAt.isNotNull())
          ..orderBy([(w) => OrderingTerm.desc(w.completedAt)]))
        .watch()
        .asyncMap((rows) => Future.wait(rows.map(_loadFullWorkout)));
  }

  Future<FullWorkout?> getWorkout(int workoutId) async {
    final w = await (select(workouts)..where((x) => x.id.equals(workoutId)))
        .getSingleOrNull();
    if (w == null) return null;
    return _loadFullWorkout(w);
  }

  /// Best set (by estimated 1RM) for each completed workout of an exercise.
  Future<List<ExerciseStatPoint>> exerciseVolumeHistory(int exerciseId) async {
    final q = select(workouts).join([
      innerJoin(workoutExercises, workoutExercises.workoutId.equalsExp(workouts.id)),
      innerJoin(workoutSets, workoutSets.workoutExerciseId.equalsExp(workoutExercises.id)),
    ])
      ..where(workoutExercises.exerciseId.equals(exerciseId) &
          workoutSets.isCompleted.equals(true) &
          workouts.completedAt.isNotNull())
      ..orderBy([OrderingTerm.asc(workouts.startedAt)]);
    final rows = await q.get();
    final perWorkout = <int, _Aggregated>{};
    for (final row in rows) {
      final workout = row.readTable(workouts);
      final s = row.readTable(workoutSets);
      final agg = perWorkout.putIfAbsent(workout.id, () => _Aggregated(workout.startedAt));
      agg.volume += s.weightKg * s.reps;
      final e1rm = estimated1Rm(s.weightKg, s.reps);
      if (e1rm > agg.bestE1rm) agg.bestE1rm = e1rm;
      final best = s.weightKg * s.reps;
      if (best > agg.bestVolumeSet) agg.bestVolumeSet = best;
      if (s.weightKg > agg.maxWeight) agg.maxWeight = s.weightKg;
    }
    return perWorkout.values
        .map((a) => ExerciseStatPoint(
              date: a.date,
              volume: a.volume,
              bestEstimated1Rm: a.bestE1rm,
              bestSetVolume: a.bestVolumeSet,
              maxWeight: a.maxWeight,
            ))
        .toList();
  }

  /// Personal records: estimated 1RM, max weight, max reps at max weight.
  Future<ExerciseRecords> exerciseRecords(int exerciseId) async {
    final history = await exerciseVolumeHistory(exerciseId);
    return ExerciseRecords(
      maxEstimated1Rm: history.fold(0.0, (m, p) => p.bestEstimated1Rm > m ? p.bestEstimated1Rm : m),
      maxWeight: history.fold(0.0, (m, p) => p.maxWeight > m ? p.maxWeight : m),
      maxVolume: history.fold(0.0, (m, p) => p.volume > m ? p.volume : m),
    );
  }

  /// Defaults for the next set: last logged set for this exercise (completed workouts).
  Future<SetInput?> lastSetForExercise(int exerciseId) async {
    final q = select(workoutSets).join([
      innerJoin(workoutExercises,
          workoutExercises.id.equalsExp(workoutSets.workoutExerciseId)),
      innerJoin(workouts, workouts.id.equalsExp(workoutExercises.workoutId)),
    ])
      ..where(workoutExercises.exerciseId.equals(exerciseId) &
          workouts.completedAt.isNotNull())
      ..orderBy([
        OrderingTerm.desc(workouts.startedAt),
        OrderingTerm.desc(workoutSets.id),
      ])
      ..limit(1);
    final row = await q.getSingleOrNull();
    if (row == null) return null;
    final s = row.readTable(workoutSets);
    return SetInput(setType: s.setType, weightKg: s.weightKg, reps: s.reps);
  }

  // ------------------------------------------------------------------
  // Body weight
  // ------------------------------------------------------------------

  Stream<List<BodyWeight>> watchBodyWeights() =>
      (select(bodyWeights)..orderBy([(b) => OrderingTerm.asc(b.date)])).watch();

  Future<void> upsertBodyWeight(double weightKg, DateTime date) async {
    final existing = await (select(bodyWeights)..where((b) => b.date.equals(date)))
        .getSingleOrNull();
    if (existing != null) {
      await (update(bodyWeights)..where((b) => b.id.equals(existing.id)))
          .write(BodyWeightsCompanion(weightKg: Value(weightKg)));
    } else {
      await into(bodyWeights).insert(BodyWeightsCompanion(
        weightKg: Value(weightKg),
        date: Value(date),
      ));
    }
  }

  Future<void> deleteBodyWeight(int id) async {
    await (delete(bodyWeights)..where((b) => b.id.equals(id))).go();
  }
}

/// Brzycki formula. Returns 0 if reps >= 36 or weight <= 0.
double estimated1Rm(double weightKg, int reps) {
  if (weightKg <= 0 || reps < 1) return 0;
  if (reps >= 36) return weightKg;
  return weightKg * 36 / (37 - reps);
}

class _Aggregated {
  _Aggregated(this.date);
  final DateTime date;
  double volume = 0;
  double bestE1rm = 0;
  double bestVolumeSet = 0;
  double maxWeight = 0;
}

class SetInput {
  const SetInput({
    this.setType = SetType.normal,
    this.weightKg = 0,
    this.reps = 0,
    this.rpe,
    this.isCompleted = false,
  });

  final SetType setType;
  final double weightKg;
  final int reps;
  final double? rpe;
  final bool isCompleted;
}

class RoutineExerciseInput {
  const RoutineExerciseInput({
    required this.exerciseId,
    this.notes = '',
    this.restSeconds = 120,
    this.sets = const [SetInput(reps: 10)],
  });

  final int exerciseId;
  final String notes;
  final int restSeconds;
  final List<SetInput> sets;
}

class RoutineExerciseEntry {
  RoutineExerciseEntry({
    required this.routineExercise,
    required this.exercise,
    required this.sets,
  });

  final RoutineExercise routineExercise;
  final Exercise exercise;
  final List<RoutineSet> sets;
}

class FullRoutine {
  FullRoutine({required this.routine, required this.entries});

  final Routine routine;
  final List<RoutineExerciseEntry> entries;
}

class WorkoutExerciseEntry {
  WorkoutExerciseEntry({
    required this.workoutExercise,
    required this.exercise,
    required this.sets,
  });

  final WorkoutExercise workoutExercise;
  final Exercise exercise;
  final List<WorkoutSet> sets;
}

class FullWorkout {
  FullWorkout({required this.workout, required this.entries});

  final Workout workout;
  final List<WorkoutExerciseEntry> entries;

  Duration get duration =>
      (workout.completedAt ?? DateTime.now()).difference(workout.startedAt);

  int get completedSets =>
      entries.expand((e) => e.sets).where((s) => s.isCompleted).length;

  double get totalVolume => entries
      .expand((e) => e.sets)
      .where((s) => s.isCompleted)
      .fold(0.0, (sum, s) => sum + s.weightKg * s.reps);
}

class ExerciseStatPoint {
  ExerciseStatPoint({
    required this.date,
    required this.volume,
    required this.bestEstimated1Rm,
    required this.bestSetVolume,
    required this.maxWeight,
  });

  final DateTime date;
  final double volume;
  final double bestEstimated1Rm;
  final double bestSetVolume;
  final double maxWeight;
}

class ExerciseRecords {
  const ExerciseRecords({
    required this.maxEstimated1Rm,
    required this.maxWeight,
    required this.maxVolume,
  });

  final double maxEstimated1Rm;
  final double maxWeight;
  final double maxVolume;
}
