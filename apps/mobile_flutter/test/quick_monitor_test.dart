import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Quick Monitor', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    });

    testWidgets('renders Quick Monitor card with expected elements', (tester) async {
      await tester.pumpWidget(const PitchTranslatorApp());
      await tester.pumpAndSettle();

      expect(find.text('Quick Monitor'), findsOneWidget);
      expect(find.text('Tap to open LIVE_PITCH'), findsOneWidget);
    });

    testWidgets('tap opens LivePitchScreen with passive config (reference OFF)', (tester) async {
      await tester.pumpWidget(const PitchTranslatorApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quick Monitor'));
      await tester.pumpAndSettle();

      expect(find.textContaining('LIVE_PITCH • PF_1'), findsOneWidget);
      expect(find.textContaining('Reference: OFF'), findsOneWidget);
    });
  });
}
