import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/presentation/train/exercise_config_screen.dart';

void main() {
  testWidgets('Exercise config screen renders scaffold text', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExerciseConfigScreen()));
    expect(find.text('Exercise config + start live session'), findsOneWidget);
  });
}
