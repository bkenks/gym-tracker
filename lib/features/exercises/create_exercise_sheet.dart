import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/providers.dart';

/// Bottom sheet to create a custom exercise. Returns the created [Exercise].
Future<Exercise?> showCreateExerciseSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const CreateExerciseSheet(),
  );
}

class CreateExerciseSheet extends ConsumerStatefulWidget {
  const CreateExerciseSheet({super.key});

  @override
  ConsumerState<CreateExerciseSheet> createState() => _CreateExerciseSheetState();
}

class _CreateExerciseSheetState extends ConsumerState<CreateExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _primaryMuscle = MuscleGroups.chest;
  final Set<String> _secondaryMuscles = {};
  String _equipment = 'Barbell';

  static const _equipmentOptions = [
    'Barbell',
    'Dumbbell',
    'Machine',
    'Cable',
    'EZ Bar',
    'Smith Machine',
    'Kettlebell',
    'Band',
    'Bodyweight',
    'Cardio Machine',
    'Weight Plate',
    'Medicine Ball',
    'Trap Bar',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final db = ref.read(databaseProvider);
    final id = await db.insertCustomExercise(ExercisesCompanion(
      name: Value(_nameController.text.trim()),
      primaryMuscle: Value(_primaryMuscle),
      secondaryMuscles: Value(jsonEncode(_secondaryMuscles.toList())),
      equipment: Value(_equipment),
      isCustom: const Value(true),
    ));
    final created = await (db.select(db.exercises)
          ..where((e) => e.id.equals(id)))
        .getSingle();
    if (mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 0,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('New Exercise', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _equipment,
                decoration: const InputDecoration(labelText: 'Equipment'),
                items: [
                  for (final e in _equipmentOptions)
                    DropdownMenuItem(value: e, child: Text(e)),
                ],
                onChanged: (v) => setState(() => _equipment = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _primaryMuscle,
                decoration: const InputDecoration(labelText: 'Primary muscle'),
                items: [
                  for (final m in MuscleGroups.all)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) => setState(() => _primaryMuscle = v!),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Secondary muscles',
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: -4,
                children: [
                  for (final m in MuscleGroups.all)
                    FilterChip(
                      label: Text(m),
                      selected: _secondaryMuscles.contains(m),
                      onSelected: (sel) => setState(() =>
                          sel ? _secondaryMuscles.add(m) : _secondaryMuscles.remove(m)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Create exercise'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
