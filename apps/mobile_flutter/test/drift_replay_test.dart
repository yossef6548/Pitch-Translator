import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/analytics/session_repository.dart';
import 'package:pitch_translator/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('DriftReplaySheet snippet frame loading', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      tempDir = await Directory.systemTemp.createTemp('pt_drift_replay_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('shows unavailable message when audioSnippetUri is null',
        (tester) async {
      const event = DriftEventRecord(
        id: 1,
        eventIndex: 0,
        confirmedAtMs: 1000,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DriftReplaySheet(event: event)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Snippet frames unavailable for frame-by-frame replay.'),
        findsOneWidget,
      );
    });

    testWidgets('shows unavailable message when snippet file does not exist',
        (tester) async {
      const event = DriftEventRecord(
        id: 1,
        eventIndex: 0,
        confirmedAtMs: 1000,
        audioSnippetUri: '/nonexistent/path/snippet.json',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: DriftReplaySheet(event: event)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Snippet frames unavailable for frame-by-frame replay.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'parses snake_case JSON fields and displays frame count and telemetry',
        (tester) async {
      final snippetFile = File('${tempDir.path}/snippet_0.json');
      await snippetFile.writeAsString(jsonEncode({
        'sessionStartMs': 500,
        'eventIndex': 0,
        'frameCount': 2,
        'frames': [
          {
            'timestamp_ms': 1000,
            'freq_hz': 440.0,
            'midi_float': 69.0,
            'nearest_midi': 69,
            'cents_error': 8.5,
            'confidence': 0.95,
          },
          {
            'timestamp_ms': 1100,
            'freq_hz': 439.0,
            'midi_float': 68.97,
            'nearest_midi': 69,
            'cents_error': -4.2,
            'confidence': 0.91,
          },
        ],
      }));

      final event = DriftEventRecord(
        id: 1,
        eventIndex: 0,
        confirmedAtMs: 1000,
        audioSnippetUri: snippetFile.path,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DriftReplaySheet(event: event)),
        ),
      );
      await tester.pumpAndSettle();

      // Verify frame count and window are displayed
      expect(
        find.textContaining('2 frames'),
        findsOneWidget,
      );
      expect(
        find.textContaining('100ms window'),
        findsOneWidget,
      );
    });

    testWidgets('renders empty when frames list in JSON is empty',
        (tester) async {
      final snippetFile = File('${tempDir.path}/snippet_empty.json');
      await snippetFile.writeAsString(jsonEncode({
        'sessionStartMs': 500,
        'eventIndex': 0,
        'frameCount': 0,
        'frames': <dynamic>[],
      }));

      final event = DriftEventRecord(
        id: 2,
        eventIndex: 0,
        confirmedAtMs: 2000,
        audioSnippetUri: snippetFile.path,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DriftReplaySheet(event: event)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Snippet frames unavailable for frame-by-frame replay.'),
        findsOneWidget,
      );
    });
  });

  group('LibraryScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    });

    testWidgets('displays LIBRARY header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LibraryScreen())),
      );
      // Pump once to render the initial frame before async loads complete
      await tester.pump();

      expect(find.text('LIBRARY'), findsOneWidget);
    });

    testWidgets('shows empty drift replay message when no data is loaded',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LibraryScreen())),
      );
      // Allow the future to settle or fail gracefully (DB not available in test env)
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Either the empty message or the list header should be present
      expect(find.text('Recent drift replays'), findsOneWidget);
    });
  });
}
