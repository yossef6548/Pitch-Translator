import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pitch_translator/analytics/session_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late DatabaseFactory _previousDatabaseFactory;

  setUpAll(() {
    sqfliteFfiInit();
    _previousDatabaseFactory = databaseFactory;
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() {
    databaseFactory = _previousDatabaseFactory;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pt_repo_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  Future<void> createDbAtVersion(String dbPath, int version) async {
    final db = await openDatabase(
      dbPath,
      version: version,
      onCreate: (db, _) async {
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

        if (version >= 2) {
          await db.execute('''
            CREATE TABLE attempts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id INTEGER NOT NULL,
              exercise_id TEXT NOT NULL,
              level_id TEXT NOT NULL,
              assisted INTEGER NOT NULL,
              success INTEGER NOT NULL,
              created_at_ms INTEGER NOT NULL,
              FOREIGN KEY(session_id) REFERENCES sessions(id)
            )
          ''');
          await db.execute('''
            CREATE TABLE drift_events (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id INTEGER NOT NULL,
              event_index INTEGER NOT NULL,
              confirmed_at_ms INTEGER NOT NULL,
              FOREIGN KEY(session_id) REFERENCES sessions(id)
            )
          ''');
          await db.execute('''
            CREATE TABLE mastery_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              exercise_id TEXT NOT NULL,
              level_id TEXT NOT NULL,
              mastered_at_ms INTEGER NOT NULL,
              source_session_id INTEGER,
              FOREIGN KEY(source_session_id) REFERENCES sessions(id)
            )
          ''');
        }

        if (version >= 3) {
          await db.execute('ALTER TABLE attempts ADD COLUMN target_note TEXT');
          await db.execute(
            'ALTER TABLE attempts ADD COLUMN target_octave INTEGER',
          );
          await db.execute(
            'ALTER TABLE attempts ADD COLUMN avg_error_cents REAL',
          );
        }

        if (version >= 4) {
          await db.execute(
            'ALTER TABLE drift_events ADD COLUMN before_midi INTEGER',
          );
          await db.execute(
            'ALTER TABLE drift_events ADD COLUMN before_cents REAL',
          );
          await db.execute(
            'ALTER TABLE drift_events ADD COLUMN before_freq_hz REAL',
          );
          await db.execute(
            'ALTER TABLE drift_events ADD COLUMN after_midi INTEGER',
          );
          await db.execute(
            'ALTER TABLE drift_events ADD COLUMN after_cents REAL',
          );
          await db.execute(
            'ALTER TABLE drift_events ADD COLUMN after_freq_hz REAL',
          );
          await db.execute(
            'ALTER TABLE drift_events ADD COLUMN audio_snippet_uri TEXT',
          );
        }
      },
    );
    await db.close();
  }

  test('migrates v1-v4 databases to v5 schema and indexes', () async {
    for (final oldVersion in [1, 2, 3, 4]) {
      final dbPath = p.join(tempDir.path, 'legacy_v$oldVersion.db');
      await createDbAtVersion(dbPath, oldVersion);

      final repository =
          SessionRepository.forTesting(databasePathOverride: dbPath);
      await repository.recentSessions(limit: 1);
      await repository.close();

      final db = await openDatabase(dbPath);
      final versionRows = await db.rawQuery('PRAGMA user_version');
      expect((versionRows.first['user_version'] as num).toInt(), 5);

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
    }
  });
  test('computes mode-level percentiles from sorted values per group',
      () async {
    final dbPath = p.join(tempDir.path, 'percentiles.db');
    final repository =
        SessionRepository.forTesting(databasePathOverride: dbPath);

    final sessionId = await repository.recordSession(
      exerciseId: 'relative_pitch',
      modeLabel: 'relative',
      startedAtMs: 1000,
      endedAtMs: 2000,
      avgErrorCents: 10,
      stabilityScore: 90,
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
