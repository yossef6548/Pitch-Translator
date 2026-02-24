import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows app shell when onboarding completion is persisted', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('ONBOARDING_CALIBRATION'), findsNothing);
  });

  testWidgets('persists onboarding completion after first-run flow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    expect(find.text('ONBOARDING_CALIBRATION'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Microphone permission granted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Headphones connected for reference playback'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Start training'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete'), isTrue);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets(
      'shows onboarding on first run when no persisted completion exists', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('ONBOARDING_CALIBRATION'), findsOneWidget);
  });

  testWidgets('advances to app shell after completing onboarding checklist', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PitchTranslatorApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Microphone permission granted'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Headphones connected for reference playback'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Start training'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });
}
