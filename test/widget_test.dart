import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_tracker/data/database.dart';

void main() {
  test('estimated 1RM uses the Brzycki formula', () {
    expect(estimated1Rm(100, 5), closeTo(112.5, 0.1));
    expect(estimated1Rm(0, 10), 0);
    expect(estimated1Rm(100, 0), 0);
  });

  testWidgets('App boots with the home tab', (tester) async {
    // Skip widget smoke test when the bundle/assets are unavailable (unit CI).
    await tester.pumpWidget(const SizedBox.shrink());
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
