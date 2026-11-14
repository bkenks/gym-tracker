import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import 'create_exercise_sheet.dart';

/// Screen for browsing exercises. Used as the Exercises tab and as a picker
/// (pushed with [Navigator.push]); in picker mode the selected exercise is
/// popped back to the caller.
class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key, this.pickerMode = false});

  final bool pickerMode;

  static Future<Exercise?> pushPicker(BuildContext context) =>
      Navigator.of(context).push<Exercise>(
        MaterialPageRoute(builder: (_) => const ExercisePickerScreen(pickerMode: true)),
      );

  @override
  ConsumerState<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final current = ref.read(exerciseFilterProvider);
      ref.read(exerciseFilterProvider.notifier).update(
          current.copyWith(query: _searchController.text));
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createExercise() async {
    final created = await showCreateExerciseSheet(context, ref);
    if (created != null && widget.pickerMode && mounted) {
      Navigator.of(context).pop(created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(exerciseFilterProvider);
    final exercisesAsync = ref.watch(exercisesProvider(filter));

    final muscles = <String?>[null, ...MuscleGroups.all];
    final equipmentOptions = exercisesAsync.value
            ?.map((e) => e.equipment)
            .toSet()
            .toList() ??
        <String>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickerMode ? 'Select Exercise' : 'Exercises'),
        actions: [
          IconButton(
            tooltip: 'New exercise',
            icon: const Icon(Icons.add),
            onPressed: _createExercise,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final m in muscles)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(m ?? 'All muscles'),
                      selected: filter.muscle == m,
                      onSelected: (_) => ref
                          .read(exerciseFilterProvider.notifier)
                          .update(ref.read(exerciseFilterProvider).copyWith(muscle: m)),
                    ),
                  ),
              ],
            ),
          ),
          if (equipmentOptions.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  for (final eq in [null, ...equipmentOptions])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text(eq ?? 'All equipment'),
                        selected: filter.equipment == eq,
                        onSelected: (_) => ref
                            .read(exerciseFilterProvider.notifier)
                            .update(ref
                                .read(exerciseFilterProvider)
                                .copyWith(equipment: eq)),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('No exercises found'))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => _ExerciseTile(
                        exercise: list[i],
                        pickerMode: widget.pickerMode,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends ConsumerWidget {
  const _ExerciseTile({required this.exercise, required this.pickerMode});

  final Exercise exercise;
  final bool pickerMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondary = exercise.secondaryMuscleList;
    return ListTile(
      title: Text(exercise.name),
      subtitle: Text([
        exercise.primaryMuscle,
        if (secondary.isNotEmpty) secondary.join(', '),
        exercise.equipment,
      ].join(' · ')),
      trailing: pickerMode ? const Icon(Icons.chevron_right) : null,
      onTap: () {
        if (pickerMode) {
          Navigator.of(context).pop(exercise);
        }
      },
    );
  }
}

extension on Exercise {
  List<String> get secondaryMuscleList {
    final raw = secondaryMuscles;
    if (raw.isEmpty || raw == '[]') return const [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }
}
