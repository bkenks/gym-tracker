import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/units.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../common/set_log_row.dart';
import '../exercises/exercise_picker.dart';
import '../rest_timer.dart';

/// Text hint of the last logged set for an exercise (e.g. "60 kg × 10").
final previousSetTextProvider =
    FutureProvider.family<String?, int>((ref, exerciseId) async {
  final last = await ref.watch(databaseProvider).lastSetForExercise(exerciseId);
  if (last == null) return null;
  return '${formatWeight(last.weightKg)} ${weightUnitLabel()} × ${last.reps}';
});

class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key, required this.workoutId});

  final int workoutId;

  static Future<void> push(BuildContext context, int workoutId) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ActiveWorkoutScreen(workoutId: workoutId)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeWorkoutProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        actions: [
          IconButton(
            tooltip: 'Finish workout',
            icon: const Icon(Icons.check),
            onPressed: () => _finish(context, ref),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'discard') _confirmDiscard(context, ref);
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'discard', child: Text('Discard workout')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addExercise(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add exercise'),
      ),
      body: activeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workout) {
          if (workout == null) {
            return const Center(child: Text('Workout ended'));
          }
          return Column(
            children: [
              _HeaderBar(workout: workout),
              const _RestTimerBar(),
              const Divider(height: 1),
              Expanded(
                child: workout.entries.isEmpty
                    ? const Center(child: Text('Add an exercise to begin'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: workout.entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _ExerciseCard(entry: workout.entries[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final exercise = await ExercisePickerScreen.pushPicker(context);
    if (exercise == null) return;
    final db = ref.read(databaseProvider);
    final last = await db.lastSetForExercise(exercise.id);
    final defaultRest = ref.read(settingsProvider).defaultRestSeconds;
    await db.addExerciseToWorkout(
      workoutId,
      RoutineExerciseInput(
        exerciseId: exercise.id,
        restSeconds: defaultRest,
        sets: [if (last != null) last else const SetInput(reps: 10)],
      ),
    );
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final workout = ref.read(activeWorkoutProvider).value;
    if (workout == null) return;
    final completedSets = workout.entries
        .expand((e) => e.sets)
        .where((s) => s.isCompleted)
        .length;
    final notesController = TextEditingController(text: workout.workout.notes);
    final weightController = TextEditingController(
      text: workout.workout.bodyWeightKg != null
          ? formatWeight(workout.workout.bodyWeightKg!)
          : '',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finish workout?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$completedSets sets · ${formatDuration(workout.duration.inSeconds)}'),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Body weight (${weightUnitLabel()}) — optional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finish')),
        ],
      ),
    );
    if (confirmed == true) {
      final bw = weightController.text.trim().isEmpty
          ? null
          : parseWeight(weightController.text);
      await ref.read(databaseProvider).finishWorkout(
            workoutId,
            notes: notesController.text.trim(),
            bodyWeightKg: bw,
          );
      ref.read(restTimerProvider.notifier).stop();
      if (context.mounted) Navigator.of(context).pop();
    }
    notesController.dispose();
    weightController.dispose();
  }

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text('All logged sets will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(databaseProvider).abandonWorkout(workoutId);
      ref.read(restTimerProvider.notifier).stop();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.workout});

  final FullWorkout workout;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(workout.workout.name,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis),
          ),
          Text(formatDuration(workout.duration.inSeconds), style: style),
          const SizedBox(width: 16),
          Text('${workout.completedSets} sets', style: style),
          const SizedBox(width: 16),
          Text('${formatWeight(workout.totalVolume)} ${weightUnitLabel()}', style: style),
        ],
      ),
    );
  }
}

class _RestTimerBar extends ConsumerWidget {
  const _RestTimerBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(restTimerProvider);
    if (!timer.active) return const SizedBox.shrink();
    final notifier = ref.read(restTimerProvider.notifier);
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 18),
            const SizedBox(width: 8),
            Text('Rest: ${formatDuration(timer.remainingSeconds)}',
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton(
              onPressed: () => notifier.addTime(30),
              child: const Text('+30s'),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              tooltip: 'Skip rest',
              onPressed: notifier.stop,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({required this.entry});

  final WorkoutExerciseEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final previous = ref.watch(previousSetTextProvider(entry.exercise.id)).value;
    final previousText = previous ?? '—';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.exercise.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis),
                ),
                ActionChip(
                  avatar: const Icon(Icons.timer_outlined, size: 16),
                  label: Text('${entry.workoutExercise.restSeconds}s'),
                  onPressed: () async {
                    final controller = TextEditingController(
                        text: '${entry.workoutExercise.restSeconds}');
                    final result = await showDialog<int>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Rest timer · ${entry.exercise.name}'),
                        content: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          decoration: const InputDecoration(labelText: 'Seconds'),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () =>
                                  Navigator.pop(ctx, int.tryParse(controller.text)),
                              child: const Text('Save')),
                        ],
                      ),
                    );
                    if (result != null && result > 0) {
                      await (db.update(db.workoutExercises)
                            ..where((e) => e.id.equals(entry.workoutExercise.id)))
                          .write(WorkoutExercisesCompanion(restSeconds: Value(result)));
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Remove exercise',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Remove ${entry.exercise.name}?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Remove')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await db.deleteWorkoutExercise(entry.workoutExercise.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            SetTableHeader(),
            for (final set in entry.sets)
              SetLogRow(
                key: ObjectKey(set),
                index: set.position,
                setType: set.setType,
                weightKg: set.weightKg,
                reps: set.reps,
                previousText: previousText,
                onChanged: (type, w, r) => db.updateWorkoutSet(
                  set.id,
                  SetInput(
                    setType: type,
                    weightKg: w,
                    reps: r,
                    rpe: set.rpe,
                    isCompleted: set.isCompleted,
                  ),
                ),
                onDelete: () => db.deleteWorkoutSet(set.id),
                isCompleted: set.isCompleted,
                onCompleteToggle: (type, w, r) async {
                  final nowCompleted = !set.isCompleted;
                  await db.updateWorkoutSet(
                    set.id,
                    SetInput(
                      setType: type,
                      weightKg: w,
                      reps: r,
                      rpe: set.rpe,
                      isCompleted: nowCompleted,
                    ),
                  );
                  if (nowCompleted) {
                    await ref
                        .read(restTimerProvider.notifier)
                        .start(entry.workoutExercise.restSeconds);
                  }
                },
              ),
            TextButton.icon(
              onPressed: () async {
                // Default the new set to the values of the previous set.
                final last = entry.sets.isEmpty
                    ? const SetInput(reps: 10)
                    : SetInput(
                        setType: entry.sets.last.setType,
                        weightKg: entry.sets.last.weightKg,
                        reps: entry.sets.last.reps,
                        isCompleted: entry.sets.last.isCompleted,
                      );
                await db.addSetToExercise(entry.workoutExercise.id, last);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add set'),
            ),
          ],
        ),
      ),
    );
  }
}
