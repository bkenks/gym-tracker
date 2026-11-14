import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/units.dart';
import '../../data/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Imperial units (lb)'),
            subtitle: const Text('Display weights in pounds instead of kilograms'),
            value: settings.imperialUnits,
            onChanged: (v) async {
              await saveImperialUnits(ref, v);
              setImperial(v);
            },
          ),
          ListTile(
            title: const Text('Default rest timer'),
            subtitle: Text('${settings.defaultRestSeconds} seconds'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final controller =
                  TextEditingController(text: '${settings.defaultRestSeconds}');
              final result = await showDialog<int>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Default rest timer'),
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
                await saveDefaultRestSeconds(ref, result);
              }
            },
          ),
          const Divider(),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Gym Tracker',
            applicationVersion: '0.1.0',
            child: Text('About'),
          ),
        ],
      ),
    );
  }
}
