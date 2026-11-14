import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../common/set_log_row.dart';

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final int workoutId;

  static Future<void> push(BuildContext context, int workoutId) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutDetailScreen(workoutId: workoutId)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutAsync = ref.watch(workoutDetailProvider(workoutId));
    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: workoutAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workout) {
          if (workout == null) return const Center(child: Text('Workout not found'));
          final subtitle = [
            DateFormat('EEEE, MMM d, yyyy · HH:mm').format(workout.workout.startedAt),
            '${workout.entries.length} exercises · ${workout.completedSets} sets',
            '${formatDuration(workout.duration.inSeconds)} · '
                '${formatWeight(workout.totalVolume)} ${weightUnitLabel()} volume',
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(workout.workout.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              for (final line in subtitle)
                Text(line, style: Theme.of(context).textTheme.bodySmall),
              if (workout.workout.bodyWeightKg != null)
                Text(
                  'Body weight: ${formatWeight(workout.workout.bodyWeightKg!)} ${weightUnitLabel()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (workout.workout.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(workout.workout.notes),
                ),
              const SizedBox(height: 16),
              for (final entry in workout.entries)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(entry.exercise.name,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        SetTableHeader(),
                        for (final set in entry.sets)
                          _ReadOnlySetRow(set: set, index: set.position),
                        if (entry.workoutExercise.notes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(entry.workoutExercise.notes,
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReadOnlySetRow extends StatelessWidget {
  const _ReadOnlySetRow({required this.set, required this.index});

  final WorkoutSet set;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Center(
              child: Text(setTypeLetter(set.setType),
                  style: TextStyle(
                      color: setTypeColor(set.setType, context),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text('${index + 1}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const Spacer(),
          Text('${formatWeight(set.weightKg)} ${weightUnitLabel()}',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 24),
          Text('${set.reps} reps', style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
        ],
      ),
    );
  }
}
