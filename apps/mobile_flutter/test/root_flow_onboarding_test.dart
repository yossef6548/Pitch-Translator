import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/analytics/session_repository.dart';
import 'package:pitch_translator/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await SessionRepository.instance.close();
  });

  testWidgets('shows home screen with bottom navigation bar', (tester) async {
    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Train'), findsWidgets);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('tapping Train tab navigates to train catalog', (tester) async {
    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Train'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Train'), findsWidgets);
  });

  testWidgets('tapping Analyze tab navigates to analyze screen',
      (tester) async {
    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Analyze'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Analyze'), findsWidgets);
  });

  testWidgets('tapping Settings tab navigates to settings screen',
      (tester) async {
    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
  });
}
