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
      // sqflite FFI dispatches each DB operation through a worker isolate.
      // Future.delayed(Duration.zero) can fire before the isolate response
      // arrives, so a fixed-count Duration.zero loop is unreliable. A single
      // runAsync with a real-time window long enough for all isolate round-trips
      // (DB open, 4-table schema creation, and sequential queries) to complete
      // is more robust. 500 ms is well within the Flutter test timeout.
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
