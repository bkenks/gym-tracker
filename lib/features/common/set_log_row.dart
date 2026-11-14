import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/units.dart';
import '../../data/database.dart';

String setTypeLetter(SetType type) => switch (type) {
      SetType.normal => '-',
      SetType.warmup => 'W',
      SetType.drop => 'D',
      SetType.failure => 'F',
    };

String setTypeLabel(SetType type) => switch (type) {
      SetType.normal => 'Normal',
      SetType.warmup => 'Warmup',
      SetType.drop => 'Drop set',
      SetType.failure => 'Failure',
    };

Color setTypeColor(SetType type, BuildContext context) => switch (type) {
      SetType.warmup => Colors.orange,
      SetType.drop => Colors.blue,
      SetType.failure => Colors.red,
      SetType.normal => Theme.of(context).disabledColor,
    };

/// A data row for an existing set, with previous-set hint.
/// Used by the routine editor (local drafts) and the live workout (DB rows).
class SetLogRow extends StatefulWidget {
  const SetLogRow({
    super.key,
    required this.index,
    required this.setType,
    required this.weightKg,
    required this.reps,
    required this.previousText,
    required this.onChanged,
    required this.onDelete,
    this.isCompleted = false,
    this.onCompleteToggle,
  });

  final int index;
  final SetType setType;
  final double weightKg;
  final int reps;
  final bool isCompleted;
  final String previousText;
  final void Function(SetType setType, double weightKg, int reps) onChanged;
  final VoidCallback onDelete;
  final void Function(SetType setType, double weightKg, int reps)?
      onCompleteToggle;

  @override
  State<SetLogRow> createState() => _SetLogRowState();
}

class _SetLogRowState extends State<SetLogRow> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  double? _lastDbWeight;
  int? _lastDbReps;

  @override
  void initState() {
    super.initState();
    _syncFromDb();
  }

  void _syncFromDb() {
    _lastDbWeight = widget.weightKg;
    _lastDbReps = widget.reps;
    _weight = TextEditingController(text: formatWeight(widget.weightKg));
    _reps = TextEditingController(text: widget.reps == 0 ? '' : '${widget.reps}');
  }

  @override
  void didUpdateWidget(covariant SetLogRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sync only when the underlying data changed elsewhere (e.g. another
    // device write); avoid clobbering in-progress typing.
    if (widget.weightKg != _lastDbWeight || widget.reps != _lastDbReps) {
      _weight.dispose();
      _reps.dispose();
      _syncFromDb();
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  void _commit() {
    widget.onChanged(
      widget.setType,
      parseWeight(_weight.text),
      int.tryParse(_reps.text) ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _TypeButton(
            setType: widget.setType,
            onSelected: (t) => widget.onChanged(
                t, widget.weightKg, widget.reps),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 28,
            child: Text('${widget.index + 1}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              widget.previousText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 82,
            child: TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                suffixText: weightUnitLabel(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              onEditingComplete: _commit,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: TextField(
              controller: _reps,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              onEditingComplete: _commit,
            ),
          ),
          if (widget.onCompleteToggle != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                widget.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: widget.isCompleted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              // Commit any in-progress typing before toggling, so completing a
              // set never discards values the user just entered.
              onPressed: () => widget.onCompleteToggle!(
                  widget.setType, parseWeight(_weight.text),
                  int.tryParse(_reps.text) ?? 0),
            )
          else
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline),
              onPressed: widget.onDelete,
            ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({required this.setType, required this.onSelected});

  final SetType setType;
  final ValueChanged<SetType> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final selected = await showModalBottomSheet<SetType>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final t in SetType.values)
                  ListTile(
                    leading: _TypeBadge(setType: t),
                    title: Text(setTypeLabel(t)),
                    onTap: () => Navigator.of(ctx).pop(t),
                  ),
              ],
            ),
          ),
        );
        if (selected != null) onSelected(selected);
      },
      child: _TypeBadge(setType: setType),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.setType});

  final SetType setType;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: setTypeColor(setType, context).withValues(alpha: 0.15),
      child: Text(
        setTypeLetter(setType),
        style: TextStyle(
            color: setTypeColor(setType, context),
            fontWeight: FontWeight.bold,
            fontSize: 12),
      ),
    );
  }
}

/// Header row for the set table.
class SetTableHeader extends StatelessWidget {
  const SetTableHeader({super.key, this.showCompleteColumn = true});

  final bool showCompleteColumn;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const SizedBox(width: 36),
          SizedBox(width: 28, child: Text('SET', style: style, textAlign: TextAlign.center)),
          Expanded(child: Text('PREVIOUS', style: style, textAlign: TextAlign.center)),
          SizedBox(width: 82, child: Text('WEIGHT', style: style, textAlign: TextAlign.center)),
          const SizedBox(width: 8),
          SizedBox(width: 64, child: Text('REPS', style: style, textAlign: TextAlign.center)),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
