import 'package:flutter/material.dart';

import 'features/exercises/exercise_picker.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/settings/settings_screen.dart';

/// Main shell with bottom navigation.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 840;
    final screens = const [
      HomeScreen(),
      ExercisePickerScreen(),
      HistoryScreen(),
      ProgressScreen(),
      SettingsScreen(),
    ];
    final destinations = const [
      (icon: Icons.home_outlined, selected: Icons.home, label: 'Home'),
      (icon: Icons.fitness_center_outlined, selected: Icons.fitness_center, label: 'Exercises'),
      (icon: Icons.history, selected: Icons.history, label: 'History'),
      (icon: Icons.insights_outlined, selected: Icons.insights, label: 'Progress'),
      (icon: Icons.settings_outlined, selected: Icons.settings, label: 'Settings'),
    ];

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: screens[_index]),
          ],
        ),
      );
    }

    return Scaffold(
      body: screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
