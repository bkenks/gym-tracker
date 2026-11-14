import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';
import '../common/set_log_row.dart';
import '../exercises/exercise_picker.dart';

class _SetDraft {
  _SetDraft({this.setType = SetType.normal, this.weightKg = 0, this.reps = 10});

  SetType setType;
  double weightKg;
  int reps;
}

class _ExerciseDraft {
  _ExerciseDraft({
    required this.exercise,
    this.restSeconds = 120,
    this.notes = '',
    List<_SetDraft>? sets,
  }) : sets = sets ?? [_SetDraft()];

  final Exercise exercise;
  int restSeconds;
  String notes;
  final List<_SetDraft> sets;
}

class RoutineEditorScreen extends ConsumerStatefulWidget {
  const RoutineEditorScreen({super.key, this.existing});

  final FullRoutine? existing;

  static Future<void> push(BuildContext context, {FullRoutine? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RoutineEditorScreen(existing: existing)),
    );
  }

  @override
  ConsumerState<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  final _nameController = TextEditingController();
  late final List<_ExerciseDraft> _drafts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.existing?.routine.name ?? '';
    _drafts = (widget.existing?.entries ?? []).map((e) {
      return _ExerciseDraft(
        exercise: e.exercise,
        restSeconds: e.routineExercise.restSeconds,
        notes: e.routineExercise.notes,
        sets: e.sets
            .map((s) => _SetDraft(
                setType: s.setType, weightKg: s.weightKg, reps: s.reps))
            .toList(),
      );
    }).toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a routine name')));
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    await db.saveRoutine(
      routineId: widget.existing?.routine.id,
      name: name,
      exercisesInput: [
        for (final d in _drafts)
          RoutineExerciseInput(
            exerciseId: d.exercise.id,
            restSeconds: d.restSeconds,
            notes: d.notes,
            sets: [
              for (final s in d.sets)
                SetInput(setType: s.setType, weightKg: s.weightKg, reps: s.reps),
            ],
          ),
      ],
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addExercise() async {
    final exercise = await ExercisePickerScreen.pushPicker(context);
    if (exercise != null) {
      setState(() => _drafts.add(_ExerciseDraft(exercise: exercise)));
    }
  }

  Future<void> _editRest(_ExerciseDraft draft) async {
    final controller = TextEditingController(text: '${draft.restSeconds}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rest timer · ${draft.exercise.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Seconds'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, int.tryParse(controller.text)),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result > 0) {
      setState(() => draft.restSeconds = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? 'New Routine' : 'Edit Routine'),
          actions: [
            IconButton(
              tooltip: 'Save routine',
              icon: const Icon(Icons.check),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addExercise,
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Routine name'),
              ),
            ),
            Expanded(
              child: _drafts.isEmpty
                  ? const Center(child: Text('Add exercises to build your routine'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: _drafts.length,
                      onReorder: (oldIndex, newIndex) => setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        _drafts.insert(newIndex, _drafts.removeAt(oldIndex));
                      }),
                      itemBuilder: (context, i) =>
                          _buildExerciseCard(context, i, _drafts[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, int index, _ExerciseDraft draft) {
    return Card(
      key: ValueKey(draft),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_indicator, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(draft.exercise.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  tooltip: 'Rest timer',
                  icon: const Icon(Icons.timer_outlined, size: 20),
                  onPressed: () => _editRest(draft),
                ),
                IconButton(
                  tooltip: 'Remove exercise',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _drafts.removeAt(index)),
                ),
              ],
            ),
            Text('Rest: ${draft.restSeconds}s',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            SetTableHeader(showCompleteColumn: false),
            for (var j = 0; j < draft.sets.length; j++)
              SetLogRow(
                key: ObjectKey(draft.sets[j]),
                index: j,
                setType: draft.sets[j].setType,
                weightKg: draft.sets[j].weightKg,
                reps: draft.sets[j].reps,
                previousText: '',
                onChanged: (type, w, r) => setState(() {
                  draft.sets[j].setType = type;
                  draft.sets[j].weightKg = w;
                  draft.sets[j].reps = r;
                }),
                onDelete: () => setState(() => draft.sets.removeAt(j)),
              ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => draft.sets.add(_SetDraft())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add set'),
            ),
          ],
        ),
      ),
    );
  }
}
