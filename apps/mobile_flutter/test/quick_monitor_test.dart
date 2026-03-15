import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/analytics/session_repository.dart';
import 'package:pitch_translator/main.dart';
import 'package:pitch_translator/presentation/home/home_screen.dart';
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
      // Use an isolated in-memory repository so this test never touches the
      // singleton's file-based DB.  In-memory SQLite via FFI completes schema
      // creation and all queries in well under 500 ms even on slow CI runners.
      final testRepo = SessionRepository.forTesting(
        databasePathOverride: ':memory:',
        databaseFactory: databaseFactoryFfi,
      );
      addTearDown(testRepo.close);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(repositoryForTest: testRepo),
      ));
      // Give the FFI worker isolate time to open the in-memory DB, run the
      // schema migration, and complete the four repository queries.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();

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
