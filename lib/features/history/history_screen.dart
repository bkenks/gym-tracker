import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/units.dart';
import '../../data/providers.dart';
import 'workout_detail_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(workoutHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workouts) => workouts.isEmpty
            ? const Center(child: Text('No workouts yet'))
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: workouts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final w = workouts[i];
                  final subtitle = [
                    '${w.entries.length} exercises',
                    '${w.completedSets} sets',
                    '${formatWeight(w.totalVolume)} ${weightUnitLabel()}',
                    formatDuration(w.duration.inSeconds),
                  ].join(' · ');
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        DateFormat('d').format(w.workout.startedAt),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    title: Text(w.workout.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${DateFormat('EEEE, MMM yyyy').format(w.workout.startedAt)}\n$subtitle',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => WorkoutDetailScreen.push(context, w.workout.id),
                  );
                },
              ),
      ),
    );
  }
}
