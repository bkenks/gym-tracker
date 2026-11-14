import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../routines/routine_editor.dart';
import '../workout/active_workout_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _startRoutine(BuildContext context, WidgetRef ref, Routine routine) async {
    final db = ref.read(databaseProvider);
    final full = await db.getFullRoutine(routine.id);
    if (full == null || !context.mounted) return;
    final workoutId = await db.startWorkout(
      name: routine.name,
      routineId: routine.id,
      routineName: routine.name,
      templateExercises: [
        for (final e in full.entries)
          RoutineExerciseInput(
            exerciseId: e.exercise.id,
            restSeconds: e.routineExercise.restSeconds,
            notes: e.routineExercise.notes,
            sets: [
              for (final s in e.sets)
                SetInput(setType: s.setType, weightKg: s.weightKg, reps: s.reps),
            ],
          ),
      ],
    );
    if (context.mounted) {
      await ActiveWorkoutScreen.push(context, workoutId);
    }
  }

  Future<void> _startEmpty(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final name = 'Workout · ${DateFormat('EEE, MMM d').format(now)}';
    final workoutId = await db.startWorkout(name: name);
    if (context.mounted) {
      await ActiveWorkoutScreen.push(context, workoutId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(routinesProvider);
    final active = ref.watch(activeWorkoutProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Gym Tracker')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ListTile(
                leading: const Icon(Icons.fitness_center),
                title: Text(active.workout.name,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    'In progress · ${active.completedSets} sets · ${formatDuration(active.duration.inSeconds)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ActiveWorkoutScreen.push(context, active.workout.id),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: OutlinedButton.icon(
              onPressed: () => _startEmpty(context, ref),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Empty Workout'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Text('Routines', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => RoutineEditorScreen.push(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
          ),
          Expanded(
            child: routinesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (routines) => routines.isEmpty
                  ? const Center(child: Text('No routines yet. Create one to get started faster.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: routines.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final routine = routines[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(routine.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  final full = await ref
                                      .read(databaseProvider)
                                      .getFullRoutine(routine.id);
                                  if (context.mounted) {
                                    RoutineEditorScreen.push(context, existing: full);
                                  }
                                },
                              ),
                              IconButton(
                                tooltip: 'Delete',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _confirmDelete(context, ref, routine),
                              ),
                            ],
                          ),
                          onTap: () => _startRoutine(context, ref, routine),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${routine.name}"?'),
        content: const Text('This routine will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).deleteRoutine(routine.id);
    }
  }
}
