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
      version: 1,
      onCreate: (db, version) async {
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
      },
    );

    return _db!;
  }

  Future<void> recordSession({
    required String exerciseId,
    required String modeLabel,
    required int startedAtMs,
    required int endedAtMs,
    required double avgErrorCents,
    required double stabilityScore,
    required int driftCount,
  }) async {
    final db = await _database();
    await db.insert('sessions', {
      'exercise_id': exerciseId,
      'mode_label': modeLabel,
      'started_at_ms': startedAtMs,
      'ended_at_ms': endedAtMs,
      'avg_error_cents': avgErrorCents,
      'stability_score': stabilityScore,
      'drift_count': driftCount,
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

  Future<SessionRecord?> sessionById(int id) async {
    final db = await _database();
    final rows = await db.query('sessions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : SessionRecord.fromMap(rows.first);
  }
}
