import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gym_tracker/data/database.dart';
import 'package:gym_tracker/data/providers.dart';
import 'package:gym_tracker/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<AppDatabase> boot(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPrefsProvider.overrideWithValue(await SharedPreferences.getInstance()),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const GymTrackerApp(),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    return db;
  }

  testWidgets('full flow: create routine, start workout, log set, finish, see history',
      (tester) async {
    final db = await boot(tester);
    expect(find.text('Start Empty Workout'), findsOneWidget);

    // --- Create a routine ---
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    expect(find.text('New Routine'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, ''), 'Push Day');
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();

    // Exercise picker: search and select.
    expect(find.text('Select Exercise'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Bench Press');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbell Bench Press'));
    await tester.pumpAndSettle();

    // Back in the editor: save via the check action.
    expect(find.text('Push Day'), findsWidgets);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    // --- Start the routine ---
    expect(find.text('Push Day'), findsOneWidget);
    await tester.tap(find.text('Push Day'));
    await tester.pumpAndSettle();
    expect(find.text('Workout'), findsOneWidget);

    // --- Log the set ---
    await tester.enterText(find.byType(TextField).at(0), '60');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.radio_button_unchecked));
    await tester.pumpAndSettle();
    // Rest timer should appear after completing the set.
    expect(find.textContaining('Rest:'), findsOneWidget);

    // --- Finish ---
    await tester.tap(find.byIcon(Icons.skip_next)); // skip rest
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check).last);
    await tester.pumpAndSettle();
    expect(find.text('Finish workout?'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    // --- Verify data landed in the database ---
    final history = await db.watchWorkoutHistory().first;
    expect(history.length, 1);
    expect(history.single.workout.routineName, 'Push Day');
    expect(history.single.completedSets, 1);
    expect(history.single.totalVolume, closeTo(600, 0.01));

    // --- History tab shows the workout ---
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Push Day'), findsOneWidget);
  });

  testWidgets('exercise picker filters by muscle group', (tester) async {
    await boot(tester);
    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();
    expect(find.text('Barbell Bench Press'), findsOneWidget);

    await tester.tap(find.text('Quads'));
    await tester.pumpAndSettle();
    expect(find.text('Barbell Bench Press'), findsNothing);
    expect(find.text('Barbell Back Squat'), findsOneWidget);
  });
}
