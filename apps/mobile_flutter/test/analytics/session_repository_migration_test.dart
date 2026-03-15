import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pitch_translator/analytics/session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  DatabaseFactory? _previousDatabaseFactory;

  setUpAll(() {
    sqfliteFfiInit();
    try {
      _previousDatabaseFactory = databaseFactory;
    } on StateError {
      // databaseFactory not yet initialized (e.g. on Linux CI with sqflite_common_ffi)
    }
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() {
    if (_previousDatabaseFactory != null) {
      databaseFactory = _previousDatabaseFactory!;
    }
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pt_repo_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('fresh schema has all current v7 columns and indexes', () async {
    final dbPath = p.join(tempDir.path, 'fresh.db');
    final repository = SessionRepository.forTesting(databasePathOverride: dbPath);
    await repository.recentSessions(limit: 1);
    await repository.close();

    final db = await openDatabase(dbPath);
    final versionRows = await db.rawQuery('PRAGMA user_version');
    expect((versionRows.first['user_version'] as num).toInt(), 7);

    final sessionColumns = await db.rawQuery('PRAGMA table_info(sessions)');
    final sessionColumnNames =
        sessionColumns.map((row) => row['name'] as String).toSet();
    expect(sessionColumnNames.contains('stability_cents'), isTrue);
    expect(sessionColumnNames.contains('lock_ratio'), isTrue);
    expect(sessionColumnNames.contains('stability_score'), isFalse);

    final driftColumns = await db.rawQuery('PRAGMA table_info(drift_events)');
    final driftColumnNames =
        driftColumns.map((row) => row['name'] as String).toSet();
    expect(driftColumnNames.contains('before_midi'), isTrue);
    expect(driftColumnNames.contains('before_cents'), isTrue);
    expect(driftColumnNames.contains('before_freq_hz'), isTrue);
    expect(driftColumnNames.contains('after_midi'), isTrue);
    expect(driftColumnNames.contains('after_cents'), isTrue);
    expect(driftColumnNames.contains('after_freq_hz'), isTrue);
    expect(driftColumnNames.contains('audio_snippet_uri'), isTrue);

    final attemptColumns = await db.rawQuery('PRAGMA table_info(attempts)');
    final attemptColumnNames =
        attemptColumns.map((row) => row['name'] as String).toSet();
    expect(attemptColumnNames.contains('target_note'), isTrue);
    expect(attemptColumnNames.contains('target_octave'), isTrue);
    expect(attemptColumnNames.contains('avg_error_cents'), isTrue);

    final attemptIndexes = await db.rawQuery('PRAGMA index_list(attempts)');
    expect(
      attemptIndexes.any((row) => row['name'] == 'idx_attempts_lookup'),
      isTrue,
    );

    final masteryIndexes = await db.rawQuery(
      'PRAGMA index_list(mastery_history)',
    );
    expect(
      masteryIndexes.any((row) => row['name'] == 'idx_mastery_lookup'),
      isTrue,
    );

    await db.close();
  });

  test('upgrade from old version drops and recreates tables with v7 schema',
      () async {
    final dbPath = p.join(tempDir.path, 'old_version.db');

    // Simulate an old database at version 5 with the old schema.
    final oldDb = await openDatabase(dbPath, version: 5, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          exercise_id TEXT NOT NULL,
          mode_label TEXT NOT NULL,
          started_at_ms INTEGER NOT NULL,
          ended_at_ms INTEGER NOT NULL,
          avg_error_cents REAL NOT NULL,
          stability_score REAL NOT NULL,
          drift_count INTEGER NOT NULL
        )
      ''');
      await db.insert('sessions', {
        'exercise_id': 'ex1',
        'mode_label': 'relative',
        'started_at_ms': 0,
        'ended_at_ms': 1000,
        'avg_error_cents': 10.0,
        'stability_score': 90.0,
        'drift_count': 0,
      });
    });
    await oldDb.close();

    // Opening with the repository should trigger onUpgrade → drop + recreate.
    final repository = SessionRepository.forTesting(databasePathOverride: dbPath);
    await repository.recentSessions(limit: 1);
    await repository.close();

    final db = await openDatabase(dbPath);
    final versionRows = await db.rawQuery('PRAGMA user_version');
    expect((versionRows.first['user_version'] as num).toInt(), 7);

    final sessionColumns = await db.rawQuery('PRAGMA table_info(sessions)');
    final sessionColumnNames =
        sessionColumns.map((row) => row['name'] as String).toSet();
    expect(sessionColumnNames.contains('stability_cents'), isTrue);
    expect(sessionColumnNames.contains('lock_ratio'), isTrue);
    expect(sessionColumnNames.contains('stability_score'), isFalse);

    // Old data should be gone (no backward compat).
    final rows = await db.query('sessions');
    expect(rows, isEmpty);

    await db.close();
  });

  test('computes mode-level percentiles from sorted values per group',
      () async {
    final dbPath = p.join(tempDir.path, 'percentiles.db');
    final repository =
        SessionRepository.forTesting(databasePathOverride: dbPath);

    final sessionId = await repository.recordSession(
      exerciseId: 'relative_pitch',
      modeLabel: 'relative',
      levelId: 'L1',
      startedAtMs: 1000,
      endedAtMs: 2000,
      avgErrorCents: 10,
      stabilityCents: 9,
      lockRatio: 0.9,
      driftCount: 0,
    );

    for (final value in [-30.0, -10.0, 0.0, 40.0, 100.0]) {
      await repository.recordAttempt(
        sessionId: sessionId,
        exerciseId: 'relative_pitch',
        levelId: 'L1',
        assisted: false,
        success: true,
        avgErrorCents: value,
      );
    }

    final percentiles = await repository.modeLevelPercentiles();
    expect(percentiles, hasLength(1));
    expect(percentiles.first.sampleSize, 5);
    expect(percentiles.first.p50ErrorCents, 30);
    expect(percentiles.first.p90ErrorCents, 100);

    await repository.close();
  });
}
