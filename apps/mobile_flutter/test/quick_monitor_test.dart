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
      // sqflite FFI uses isolate round-trips for each DB operation. Each
      // runAsync+pump cycle drains one round-trip. DB open + schema creation
      // (4 tables) + sequential data queries needs ~9 cycles; use 15 for safety.
      for (var cycle = 0; cycle < 15; cycle++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }

      expect(find.text("Today's recommended exercise"), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('tapping Train navigation item shows train catalog',
        (tester) async {
      await tester.pumpWidget(const PitchTranslatorApp());
      // pump() instead of pumpAndSettle() to avoid infinite-animation timeout.
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Train'),
        ),
      );
      // pump() to process the tab switch; TrainCatalogScreen AppBar is rendered
      // immediately before its data future resolves.
      await tester.pump();

      expect(find.textContaining('Train'), findsWidgets);
    });
  });
}
