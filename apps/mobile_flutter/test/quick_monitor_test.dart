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

  group('Home screen navigation', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await SessionRepository.instance.close();
    });

    testWidgets('renders home screen with recommended exercise card',
        (tester) async {
      await tester.pumpWidget(const PitchTranslatorApp());
      await tester.pumpAndSettle();

      expect(find.text("Today's recommended exercise"), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('tapping Train navigation item shows train catalog',
        (tester) async {
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
  });
}
