import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class SessionRecord {
  SessionRecord({
    required this.id,
    required this.exerciseId,
    required this.modeLabel,
    required this.startedAtMs,
    required this.endedAtMs,
    required this.avgErrorCents,
    required this.stabilityScore,
    required this.driftCount,
  });

  final int id;
  final String exerciseId;
  final String modeLabel;
  final int startedAtMs;
  final int endedAtMs;
  final double avgErrorCents;
  final double stabilityScore;
  final int driftCount;

  int get durationMs => endedAtMs - startedAtMs;

  factory SessionRecord.fromMap(Map<String, Object?> map) {
    return SessionRecord(
      id: map['id'] as int,
      exerciseId: map['exercise_id'] as String,
      modeLabel: map['mode_label'] as String,
      startedAtMs: map['started_at_ms'] as int,
      endedAtMs: map['ended_at_ms'] as int,
      avgErrorCents: (map['avg_error_cents'] as num).toDouble(),
      stabilityScore: (map['stability_score'] as num).toDouble(),
      driftCount: map['drift_count'] as int,
    );
  }
}

class TrendSnapshot {
  const TrendSnapshot({
    required this.avgErrorCents,
    required this.stabilityScore,
    required this.driftPerSession,
    required this.sampleSize,
  });

  final double avgErrorCents;
  final double stabilityScore;
  final double driftPerSession;
  final int sampleSize;
}

class TrendPoint {
  const TrendPoint({
    required this.endedAtMs,
    required this.avgErrorCents,
    required this.stabilityScore,
    required this.driftCount,
  });

  final int endedAtMs;
  final double avgErrorCents;
  final double stabilityScore;
  final int driftCount;
}

class WeaknessMapCell {
  const WeaknessMapCell({
    required this.note,
    required this.octave,
    required this.avgErrorCents,
    required this.attemptCount,
  });

  final String note;
  final int octave;
  final double avgErrorCents;
  final int attemptCount;
}

class DriftEventRecord {
  const DriftEventRecord({
    required this.id,
    required this.eventIndex,
    required this.confirmedAtMs,
    this.beforeMidi,
    this.beforeCents,
    this.beforeFreqHz,
    this.afterMidi,
    this.afterCents,
    this.afterFreqHz,
    this.audioSnippetUri,
  });

  final int id;
  final int eventIndex;
  final int confirmedAtMs;
  final int? beforeMidi;
  final double? beforeCents;
  final double? beforeFreqHz;
  final int? afterMidi;
  final double? afterCents;
  final double? afterFreqHz;
  final String? audioSnippetUri;
}

class DriftEventWrite {
  const DriftEventWrite({
    required this.eventIndex,
    required this.confirmedAtMs,
    this.beforeMidi,
    this.beforeCents,
    this.beforeFreqHz,
    this.afterMidi,
    this.afterCents,
    this.afterFreqHz,
    this.audioSnippetUri,
  });

  final int eventIndex;
  final int confirmedAtMs;
  final int? beforeMidi;
  final double? beforeCents;
  final double? beforeFreqHz;
  final int? afterMidi;
  final double? afterCents;
  final double? afterFreqHz;
  final String? audioSnippetUri;
}

class SessionRepository {
  SessionRepository._();

  static final SessionRepository instance = SessionRepository._();

  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;

    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'pitch_translator.db');

    _db = await openDatabase(
      dbPath,
      version: 4,
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createV2Tables(db);
        }
        if (oldVersion < 3) {
          await _migrateToV3(db);
        }
        if (oldVersion < 4) {
          await _migrateToV4(db);
        }
      },
    );

    return _db!;
  }

  Future<void> _createSchema(Database db) async {
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
    await _createV2Tables(db);
    await _migrateToV3(db);
    await _migrateToV4(db);
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attempts (
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
      CREATE TABLE IF NOT EXISTS drift_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        event_index INTEGER NOT NULL,
        confirmed_at_ms INTEGER NOT NULL,
        FOREIGN KEY(session_id) REFERENCES sessions(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mastery_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_id TEXT NOT NULL,
        level_id TEXT NOT NULL,
        mastered_at_ms INTEGER NOT NULL,
        source_session_id INTEGER,
        FOREIGN KEY(source_session_id) REFERENCES sessions(id)
      )
    ''');
  }

  Future<void> _migrateToV3(Database db) async {
    final attemptsColumns = await db.rawQuery('PRAGMA table_info(attempts)');
    final existingColumns = attemptsColumns.map((row) => row['name']).toSet();

    if (!existingColumns.contains('target_note')) {
      await db.execute('ALTER TABLE attempts ADD COLUMN target_note TEXT');
    }
    if (!existingColumns.contains('target_octave')) {
      await db.execute('ALTER TABLE attempts ADD COLUMN target_octave INTEGER');
    }
    if (!existingColumns.contains('avg_error_cents')) {
      await db.execute('ALTER TABLE attempts ADD COLUMN avg_error_cents REAL');
    }
  }

  Future<void> _migrateToV4(Database db) async {
    final driftColumns = await db.rawQuery('PRAGMA table_info(drift_events)');
    final existingColumns = driftColumns.map((row) => row['name']).toSet();

    if (!existingColumns.contains('before_midi')) {
      await db.execute('ALTER TABLE drift_events ADD COLUMN before_midi INTEGER');
    }
    if (!existingColumns.contains('before_cents')) {
      await db.execute('ALTER TABLE drift_events ADD COLUMN before_cents REAL');
    }
    if (!existingColumns.contains('before_freq_hz')) {
      await db.execute('ALTER TABLE drift_events ADD COLUMN before_freq_hz REAL');
    }
    if (!existingColumns.contains('after_midi')) {
      await db.execute('ALTER TABLE drift_events ADD COLUMN after_midi INTEGER');
    }
    if (!existingColumns.contains('after_cents')) {
      await db.execute('ALTER TABLE drift_events ADD COLUMN after_cents REAL');
    }
    if (!existingColumns.contains('after_freq_hz')) {
      await db.execute('ALTER TABLE drift_events ADD COLUMN after_freq_hz REAL');
    }
    if (!existingColumns.contains('audio_snippet_uri')) {
      await db.execute('ALTER TABLE drift_events ADD COLUMN audio_snippet_uri TEXT');
    }
  }

  Future<int> recordSession({
    required String exerciseId,
    required String modeLabel,
    required int startedAtMs,
    required int endedAtMs,
    required double avgErrorCents,
    required double stabilityScore,
    required int driftCount,
  }) async {
    final db = await _database();
    return db.insert('sessions', {
      'exercise_id': exerciseId,
      'mode_label': modeLabel,
      'started_at_ms': startedAtMs,
      'ended_at_ms': endedAtMs,
      'avg_error_cents': avgErrorCents,
      'stability_score': stabilityScore,
      'drift_count': driftCount,
    });
  }

  Future<void> recordAttempt({
    required int sessionId,
    required String exerciseId,
    required String levelId,
    required bool assisted,
    required bool success,
    String? targetNote,
    int? targetOctave,
    double? avgErrorCents,
  }) async {
    final db = await _database();
    await db.insert('attempts', {
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'level_id': levelId,
      'assisted': assisted ? 1 : 0,
      'success': success ? 1 : 0,
      'target_note': targetNote,
      'target_octave': targetOctave,
      'avg_error_cents': avgErrorCents,
      'created_at_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> recordDriftEvents({
    required int sessionId,
    required List<DriftEventWrite> events,
  }) async {
    if (events.isEmpty) return;
    final db = await _database();
    final batch = db.batch();
    for (final event in events) {
      batch.insert('drift_events', {
        'session_id': sessionId,
        'event_index': event.eventIndex,
        'confirmed_at_ms': event.confirmedAtMs,
        'before_midi': event.beforeMidi,
        'before_cents': event.beforeCents,
        'before_freq_hz': event.beforeFreqHz,
        'after_midi': event.afterMidi,
        'after_cents': event.afterCents,
        'after_freq_hz': event.afterFreqHz,
        'audio_snippet_uri': event.audioSnippetUri,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> recordMastery({
    required String exerciseId,
    required String levelId,
    required int sourceSessionId,
  }) async {
    final db = await _database();
    await db.insert('mastery_history', {
      'exercise_id': exerciseId,
      'level_id': levelId,
      'mastered_at_ms': DateTime.now().millisecondsSinceEpoch,
      'source_session_id': sourceSessionId,
    });
  }

  Future<List<SessionRecord>> recentSessions({int limit = 20}) async {
    final db = await _database();
    final rows = await db.query('sessions', orderBy: 'ended_at_ms DESC', limit: limit);
    return rows.map(SessionRecord.fromMap).toList(growable: false);
  }

  Future<SessionRecord?> latestSession() async {
    final sessions = await recentSessions(limit: 1);
    return sessions.isEmpty ? null : sessions.first;
  }

  Future<TrendSnapshot> recentTrends({int lookbackSessions = 7}) async {
    final db = await _database();
    final result = await db.rawQuery(
      '''
      SELECT
        AVG(avg_error_cents) AS avg_error,
        AVG(stability_score) AS stability,
        AVG(drift_count) AS drift,
        COUNT(*) AS sample_size
      FROM (
        SELECT avg_error_cents, stability_score, drift_count
        FROM sessions
        ORDER BY ended_at_ms DESC
        LIMIT ?
      )
      ''',
      [lookbackSessions],
    );

    final row = result.first;
    final sampleSize = (row['sample_size'] as num?)?.toInt() ?? 0;
    return TrendSnapshot(
      avgErrorCents: ((row['avg_error'] as num?) ?? 0).toDouble(),
      stabilityScore: ((row['stability'] as num?) ?? 0).toDouble(),
      driftPerSession: ((row['drift'] as num?) ?? 0).toDouble(),
      sampleSize: sampleSize,
    );
  }

  Future<Map<String, int>> libraryCounts() async {
    final db = await _database();
    final tones = await db.rawQuery('SELECT COUNT(DISTINCT exercise_id) AS count FROM sessions');
    final mastery = await db.rawQuery('SELECT COUNT(*) AS count FROM mastery_history');
    final driftReplays = await db.rawQuery('SELECT COUNT(*) AS count FROM drift_events');
    return {
      'reference_tones': (tones.first['count'] as num?)?.toInt() ?? 0,
      'mastered_entries': (mastery.first['count'] as num?)?.toInt() ?? 0,
      'drift_replays': (driftReplays.first['count'] as num?)?.toInt() ?? 0,
    };
  }

  Future<Map<String, String>> settingsSummary() async {
    final db = await _database();
    final attemptsRows = await db.rawQuery('SELECT COUNT(*) AS total, SUM(assisted) AS assisted FROM attempts');
    final avgRows = await db.rawQuery('SELECT AVG(avg_error_cents) AS avg_error FROM sessions');
    final row = attemptsRows.first;
    final total = (row['total'] as num?)?.toInt() ?? 0;
    final assisted = (row['assisted'] as num?)?.toInt() ?? 0;
    final avgError = ((avgRows.first['avg_error'] as num?) ?? 0).toDouble();
    return {
      'detection_profile': avgError <= 20 ? 'Strict' : avgError <= 35 ? 'Standard' : 'Relaxed',
      'assist_ratio': total == 0 ? '0%' : '${((assisted / total) * 100).round()}%',
      'privacy': 'Local-only SQLite storage',
    };
  }

  Future<SessionRecord?> sessionById(int id) async {
    final db = await _database();
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : SessionRecord.fromMap(rows.first);
  }

  Future<List<TrendPoint>> trendSeries({int limit = 20}) async {
    final db = await _database();
    final rows = await db.query(
      'sessions',
      columns: ['ended_at_ms', 'avg_error_cents', 'stability_score', 'drift_count'],
      orderBy: 'ended_at_ms DESC',
      limit: limit,
    );
    // DESC+limit fetches the most recent N sessions; reverse restores chronological order for the chart.
    return rows
        .map(
          (row) => TrendPoint(
            endedAtMs: row['ended_at_ms'] as int,
            avgErrorCents: (row['avg_error_cents'] as num).toDouble(),
            stabilityScore: (row['stability_score'] as num).toDouble(),
            driftCount: (row['drift_count'] as num).toInt(),
          ),
        )
        .toList(growable: false)
        .reversed
        .toList(growable: false);
  }

  Future<List<WeaknessMapCell>> weaknessMap() async {
    final db = await _database();
    final rows = await db.rawQuery(
      '''
      SELECT
        target_note,
        target_octave,
        AVG(avg_error_cents) AS avg_error,
        COUNT(*) AS attempts
      FROM attempts
      WHERE target_note IS NOT NULL AND target_octave IS NOT NULL AND avg_error_cents IS NOT NULL
      GROUP BY target_note, target_octave
      ORDER BY target_octave ASC, target_note ASC
      ''',
    );
    return rows
        .map(
          (row) => WeaknessMapCell(
            note: row['target_note'] as String,
            octave: (row['target_octave'] as num).toInt(),
            avgErrorCents: (row['avg_error'] as num).toDouble(),
            attemptCount: (row['attempts'] as num).toInt(),
          ),
        )
        .toList(growable: false);
  }

  Future<List<DriftEventRecord>> driftEventsForSession(int sessionId) async {
    final db = await _database();
    final rows = await db.query(
      'drift_events',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'event_index ASC',
    );
    return rows
        .map(
          (row) => DriftEventRecord(
            id: row['id'] as int,
            eventIndex: (row['event_index'] as num).toInt(),
            confirmedAtMs: (row['confirmed_at_ms'] as num).toInt(),
            beforeMidi: (row['before_midi'] as num?)?.toInt(),
            beforeCents: (row['before_cents'] as num?)?.toDouble(),
            beforeFreqHz: (row['before_freq_hz'] as num?)?.toDouble(),
            afterMidi: (row['after_midi'] as num?)?.toInt(),
            afterCents: (row['after_cents'] as num?)?.toDouble(),
            afterFreqHz: (row['after_freq_hz'] as num?)?.toDouble(),
            audioSnippetUri: row['audio_snippet_uri'] as String?,
          ),
        )
        .toList(growable: false);
  }
}
