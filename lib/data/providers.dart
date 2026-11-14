import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final exercisesProvider = StreamProvider.family<List<Exercise>, ExerciseFilter>(
  (ref, filter) => ref.watch(databaseProvider).watchExercises(
        query: filter.query,
        muscle: filter.muscle,
        equipment: filter.equipment,
      ),
);

class ExerciseFilter {
  const ExerciseFilter({this.query = '', this.muscle, this.equipment});

  final String query;
  final String? muscle;
  final String? equipment;

  ExerciseFilter copyWith({String? query, String? muscle, String? equipment}) =>
      ExerciseFilter(
        query: query ?? this.query,
        muscle: muscle,
        equipment: equipment,
      );

  @override
  bool operator ==(Object other) =>
      other is ExerciseFilter &&
      other.query == query &&
      other.muscle == muscle &&
      other.equipment == equipment;

  @override
  int get hashCode => Object.hash(query, muscle, equipment);
}

final exerciseFilterProvider =
    NotifierProvider<ExerciseFilterNotifier, ExerciseFilter>(
        ExerciseFilterNotifier.new);

class ExerciseFilterNotifier extends Notifier<ExerciseFilter> {
  @override
  ExerciseFilter build() => const ExerciseFilter();

  void update(ExerciseFilter filter) => state = filter;
}

final routinesProvider =
    StreamProvider<List<Routine>>((ref) => ref.watch(databaseProvider).routinesStream());

final routineDetailProvider =
    FutureProvider.family<FullRoutine?, int>((ref, id) async {
  // Re-fetch when routines change.
  ref.watch(routinesProvider);
  return ref.watch(databaseProvider).getFullRoutine(id);
});

final activeWorkoutProvider = StreamProvider<FullWorkout?>(
  (ref) => ref.watch(databaseProvider).watchActiveWorkout(),
);

final workoutHistoryProvider = StreamProvider<List<FullWorkout>>(
  (ref) => ref.watch(databaseProvider).watchWorkoutHistory(),
);

final workoutDetailProvider =
    FutureProvider.family<FullWorkout?, int>((ref, id) {
  ref.watch(workoutHistoryProvider);
  return ref.watch(databaseProvider).getWorkout(id);
});

final exerciseStatsProvider =
    FutureProvider.family<List<ExerciseStatPoint>, int>(
  (ref, exerciseId) =>
      ref.watch(databaseProvider).exerciseVolumeHistory(exerciseId),
);

final exerciseRecordsProvider = FutureProvider.family<ExerciseRecords, int>(
  (ref, exerciseId) => ref.watch(databaseProvider).exerciseRecords(exerciseId),
);

final bodyWeightsProvider = StreamProvider<List<BodyWeight>>(
  (ref) => ref.watch(databaseProvider).watchBodyWeights(),
);

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden in main.dart'),
);

class Settings {
  const Settings({required this.imperialUnits, required this.defaultRestSeconds});

  final bool imperialUnits;
  final int defaultRestSeconds;
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
    SettingsNotifier.new);

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() =>
      const Settings(imperialUnits: false, defaultRestSeconds: 120);

  void update(Settings settings) => state = settings;
}

Future<void> loadSettings(ProviderContainer container) async {
  final prefs = await SharedPreferences.getInstance();
  container.read(settingsProvider.notifier).update(Settings(
    imperialUnits: prefs.getBool('imperialUnits') ?? false,
    defaultRestSeconds: prefs.getInt('defaultRestSeconds') ?? 120,
  ));
}

Future<void> saveImperialUnits(WidgetRef ref, bool value) async {
  ref.read(settingsProvider.notifier).update(Settings(
    imperialUnits: value,
    defaultRestSeconds: ref.read(settingsProvider).defaultRestSeconds,
  ));
  await ref.read(sharedPrefsProvider).setBool('imperialUnits', value);
}

Future<void> saveDefaultRestSeconds(WidgetRef ref, int value) async {
  ref.read(settingsProvider.notifier).update(Settings(
    imperialUnits: ref.read(settingsProvider).imperialUnits,
    defaultRestSeconds: value,
  ));
  await ref.read(sharedPrefsProvider).setInt('defaultRestSeconds', value);
}
