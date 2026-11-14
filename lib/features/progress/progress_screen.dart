import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/units.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../exercises/exercise_picker.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  Exercise? _selected;
  _Metric _metric = _Metric.estimated1Rm;

  Future<void> _pickExercise() async {
    final exercise = await ExercisePickerScreen.pushPicker(context);
    if (exercise != null) setState(() => _selected = exercise);
  }

  @override
  Widget build(BuildContext context) {
    final bodyWeights = ref.watch(bodyWeightsProvider).value ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OutlinedButton.icon(
            onPressed: _pickExercise,
            icon: const Icon(Icons.search),
            label: Text(_selected == null
                ? 'Choose an exercise'
                : _selected!.name),
          ),
          if (_selected != null) ...[
            const SizedBox(height: 16),
            _ExerciseStats(exercise: _selected!, metric: _metric, onMetricChanged: (m) => setState(() => _metric = m)),
          ] else ...[
            const SizedBox(height: 24),
            const Center(child: Text('Pick an exercise to see volume, strength and PR trends.')),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Text('Body Weight', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _logBodyWeight(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Log'),
              ),
            ],
          ),
          if (bodyWeights.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text('No entries yet')),
            )
          else
            SizedBox(height: 200, child: _BodyWeightChart(points: bodyWeights)),
          if (bodyWeights.isNotEmpty)
            for (final bw in bodyWeights.reversed.take(5))
              ListTile(
                dense: true,
                title: Text(DateFormat('EEE, MMM d, yyyy').format(bw.date)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${formatWeight(bw.weightKg)} ${weightUnitLabel()}'),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () =>
                          ref.read(databaseProvider).deleteBodyWeight(bw.id),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _logBodyWeight(BuildContext context) async {
    final controller = TextEditingController();
    final latest = ref.read(bodyWeightsProvider).value?.lastOrNull;
    if (latest != null) {
      controller.text = formatWeight(latest.weightKg);
    }
    final saved = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log body weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Weight (${weightUnitLabel()})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, parseWeight(controller.text)),
              child: const Text('Save')),
        ],
      ),
    );
    if (saved != null && saved > 0) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await ref.read(databaseProvider).upsertBodyWeight(saved, today);
    }
  }
}

enum _Metric { volume, estimated1Rm, maxWeight }

class _ExerciseStats extends ConsumerWidget {
  const _ExerciseStats({
    required this.exercise,
    required this.metric,
    required this.onMetricChanged,
  });

  final Exercise exercise;
  final _Metric metric;
  final ValueChanged<_Metric> onMetricChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(exerciseStatsProvider(exercise.id)).value ?? [];
    final records = ref.watch(exerciseRecordsProvider(exercise.id)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (records != null && records.maxEstimated1Rm > 0)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RecordChip(
                  label: 'e1RM',
                  value: '${formatWeight(records.maxEstimated1Rm)} ${weightUnitLabel()}'),
              _RecordChip(
                  label: 'Max weight',
                  value: '${formatWeight(records.maxWeight)} ${weightUnitLabel()}'),
              _RecordChip(
                  label: 'Max volume',
                  value: '${formatWeight(records.maxVolume)} ${weightUnitLabel()}'),
            ],
          ),
        const SizedBox(height: 8),
        SegmentedButton<_Metric>(
          segments: const [
            ButtonSegment(value: _Metric.estimated1Rm, label: Text('e1RM')),
            ButtonSegment(value: _Metric.volume, label: Text('Volume')),
            ButtonSegment(value: _Metric.maxWeight, label: Text('Max weight')),
          ],
          selected: {metric},
          onSelectionChanged: (s) => onMetricChanged(s.first),
        ),
        const SizedBox(height: 16),
        if (stats.length < 2)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Log at least two workouts to see a chart')),
          )
        else
          SizedBox(
            height: 220,
            child: _StatChart(
              points: stats,
              metric: metric,
              unit: metric == _Metric.volume
                  ? '${weightUnitLabel()}·reps'
                  : weightUnitLabel(),
            ),
          ),
      ],
    );
  }
}

class _RecordChip extends StatelessWidget {
  const _RecordChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.emoji_events_outlined, size: 16),
      label: Text('$label  $value'),
    );
  }
}

class _StatChart extends StatelessWidget {
  const _StatChart({
    required this.points,
    required this.metric,
    required this.unit,
  });

  final List<ExerciseStatPoint> points;
  final _Metric metric;
  final String unit;

  @override
  Widget build(BuildContext context) {
    double y(ExerciseStatPoint p) => switch (metric) {
          _Metric.volume => p.volume,
          _Metric.estimated1Rm => p.bestEstimated1Rm,
          _Metric.maxWeight => p.maxWeight,
        };
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), y(points[i])),
    ];
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = ((maxY - minY) * 0.1).clamp(1.0, double.infinity);
    final lineColor = Theme.of(context).colorScheme.primary;

    return LineChart(
      LineChartData(
        minY: (minY - padding).clamp(0, double.infinity),
        maxY: maxY + padding,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => [
              for (final t in touched)
                LineTooltipItem(
                  '${formatWeight(t.y)} $unit\n${DateFormat('MMM d, yyyy').format(points[t.x.toInt()].date)}',
                  const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(
                formatWeight(v),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (spots.length / 4).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Text(DateFormat('MM/d').format(points[i].date),
                    style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyWeightChart extends StatelessWidget {
  const _BodyWeightChart({required this.points});

  final List<BodyWeight> points;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(points[i].date.millisecondsSinceEpoch.toDouble(), points[i].weightKg),
    ];
    final lineColor = Theme.of(context).colorScheme.tertiary;
    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => [
              for (final t in touched)
                LineTooltipItem(
                  '${formatWeight(t.y)} ${weightUnitLabel()}',
                  const TextStyle(fontSize: 12),
                ),
            ],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(formatWeight(v),
                  style: const TextStyle(fontSize: 10)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (86400000.0 * ((points.length / 4).ceil().clamp(1, 1 << 31))),
              getTitlesWidget: (v, _) => Text(
                DateFormat('MM/d').format(
                    DateTime.fromMillisecondsSinceEpoch(v.toInt())),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData:
                BarAreaData(show: true, color: lineColor.withValues(alpha: 0.12)),
          ),
        ],
      ),
    );
  }
}
