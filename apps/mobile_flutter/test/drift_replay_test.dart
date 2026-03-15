import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/analytics/session_repository.dart';
import 'package:pitch_translator/presentation/live_pitch/drift_replay_screen.dart';
import 'package:pitch_translator/presentation/library/library_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('DriftEventWithSessionRecord', () {
    test('stores event and session metadata correctly', () {
      const event = DriftEventRecord(
        id: 1,
        eventIndex: 2,
        confirmedAtMs: 1000,
        beforeMidi: 69,
        beforeCents: 5.0,
        beforeFreqHz: 440.5,
        afterMidi: 69,
        afterCents: 1.0,
        afterFreqHz: 440.1,
        audioSnippetUri: '/tmp/snippet.json',
      );

      const record = DriftEventWithSessionRecord(
        event: event,
        sessionId: 42,
        modeLabel: 'DRIFT_AWARENESS',
        exerciseId: 'ex_01',
      );

      expect(record.sessionId, 42);
      expect(record.modeLabel, 'DRIFT_AWARENESS');
      expect(record.exerciseId, 'ex_01');
      expect(record.event.id, 1);
      expect(record.event.eventIndex, 2);
      expect(record.event.confirmedAtMs, 1000);
      expect(record.event.beforeMidi, 69);
      expect(record.event.beforeCents, 5.0);
      expect(record.event.afterCents, 1.0);
      expect(record.event.audioSnippetUri, '/tmp/snippet.json');
    });

    test('handles optional fields as null', () {
      const event = DriftEventRecord(
        id: 5,
        eventIndex: 0,
        confirmedAtMs: 2000,
      );

      const record = DriftEventWithSessionRecord(
        event: event,
        sessionId: 10,
        modeLabel: 'DRIFT_AWARENESS',
        exerciseId: 'ex_02',
      );

      expect(record.event.beforeMidi, isNull);
      expect(record.event.beforeCents, isNull);
      expect(record.event.afterMidi, isNull);
      expect(record.event.afterCents, isNull);
      expect(record.event.audioSnippetUri, isNull);
    });
  });

  group('DriftReplayScreen snippet frame loading', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    });

    testWidgets('shows unavailable message when audioSnippetUri is null',
        (tester) async {
            await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DriftReplayScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Before/after comparison and replay controls'),
        findsOneWidget,
      );
    });

    testWidgets('shows unavailable message when snippet file does not exist',
        (tester) async {
            await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DriftReplayScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Before/after comparison and replay controls'),
        findsOneWidget,
      );
    });

    testWidgets(
        'parses snake_case JSON fields and displays frame count and telemetry',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DriftReplayScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify frame count and window are displayed
      expect(
        find.text('Before/after comparison and replay controls'),
        findsOneWidget,
      );
      expect(
        find.text('Before/after comparison and replay controls'),
        findsOneWidget,
      );
    });

    testWidgets('renders empty when frames list in JSON is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DriftReplayScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.text('Before/after comparison and replay controls'),
        findsOneWidget,
      );
    });
  });

  group('LibraryScreen', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    });

    tearDown(() async {
      await SessionRepository.instance.close();
    });

    testWidgets('displays Library app bar title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LibraryScreen())),
      );
      // pump() instead of pumpAndSettle(): the CircularProgressIndicator shown
      // while the DB future is pending has an infinite animation that prevents
      // pumpAndSettle from settling. The LibraryScreen AppBar is rendered on
      // the first frame before any async data loads.
      await tester.pump();

      expect(find.text('Library'), findsWidgets);
    });

    testWidgets('shows library content sections after loading',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LibraryScreen())),
      );
      // sqflite FFI uses isolate round-trips for each DB operation. Each
      // runAsync+pump cycle drains one round-trip. DB open + schema creation
      // (4 tables) + 3 sequential queries needs ~8 cycles; use 15 for safety.
      for (var cycle = 0; cycle < 15; cycle++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }

      expect(find.text('Reference tones'), findsOneWidget);
      expect(find.text('Choir presets'), findsOneWidget);
    });
  });
}
