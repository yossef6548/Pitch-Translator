import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/exercises/exercise_catalog.dart';
import 'package:pitch_translator/main.dart';

void main() {
  testWidgets(
      'Start Exercise forwards toggle selections into live session config',
      (tester) async {
    final exercise = ExerciseCatalog.byId('DA_2');

    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home:
            ExerciseConfigScreen(exercise: exercise, initialLevel: LevelId.l2),
      ),
    );

    await tester
        .tap(find.widgetWithText(SwitchListTile, 'Randomize within range'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Reference tone'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Numeric overlay'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Shape warping'));
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.widgetWithText(SwitchListTile, 'Color flood'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Color flood'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(SwitchListTile, 'Haptics'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Haptics'));
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Start Exercise'));
    await tester.tap(find.widgetWithText(FilledButton, 'Start Exercise'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Randomize: ON'), findsOneWidget);
    expect(find.textContaining('Reference: OFF'), findsOneWidget);
    expect(find.textContaining('Shape: OFF'), findsOneWidget);
    expect(find.textContaining('Color: OFF'), findsOneWidget);
    expect(find.textContaining('Haptics: ON'), findsOneWidget);
    expect(find.text('Cents: —'), findsOneWidget);
  });
}
