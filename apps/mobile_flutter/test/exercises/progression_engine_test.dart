import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/exercises/exercise_catalog.dart';
import 'package:pitch_translator/exercises/progression_engine.dart';

void main() {
  test('level defaults match spec values', () {
    expect(levelDefaults[LevelId.l1]!.toleranceCents, 35);
    expect(levelDefaults[LevelId.l2]!.driftThresholdCents, 30);
    expect(levelDefaults[LevelId.l3]!.toleranceCents, 10);
  });

  test('catalog includes all spec exercises', () {
    final ids = ExerciseCatalog.all.map((e) => e.id).toSet();
    expect(ids.length, 19);
    expect(ids.containsAll(['RP_5', 'GS_4', 'LT_3']), isTrue);
  });

  test('unlock chain requires prior mastery in same level', () {
    const empty = ProgressSnapshot();
    expect(ExerciseCatalog.byId('PF_1').unlockRule(empty, LevelId.l2), isTrue);
    expect(ExerciseCatalog.byId('PF_2').unlockRule(empty, LevelId.l2), isFalse);

    const withPf1 = ProgressSnapshot(mastered: {'PF_1:l2'});
    expect(ExerciseCatalog.byId('PF_2').unlockRule(withPf1, LevelId.l2), isTrue);
    expect(ExerciseCatalog.byId('DA_1').unlockRule(withPf1, LevelId.l2), isFalse);
  });

  test('mode unlock follows mode order dependency', () {
    const empty = ProgressSnapshot();
    expect(ExerciseCatalog.modeUnlocked(empty, ModeId.modePf, LevelId.l1), isTrue);
    expect(ExerciseCatalog.modeUnlocked(empty, ModeId.modeDa, LevelId.l1), isFalse);

    final pfMastered = ExerciseCatalog.all
        .where((e) => e.mode == ModeId.modePf)
        .map((exercise) => '${exercise.id}:${LevelId.l1.name}')
        .toSet();
    final snapshot = ProgressSnapshot(mastered: pfMastered);

    expect(ExerciseCatalog.modeUnlocked(snapshot, ModeId.modeDa, LevelId.l1), isTrue);
    expect(ExerciseCatalog.modeUnlocked(snapshot, ModeId.modeRp, LevelId.l1), isFalse);
  });

  test('session metrics uses signed errors for stability', () {
    final builder = SessionMetricsBuilder()
      ..addEffectiveError(-10)
      ..addEffectiveError(10)
      ..addActiveTimeMs(1000, locked: true);

    final metrics = builder.build();

    expect(metrics.avgError, closeTo(10, 0.0001));
    expect(metrics.stability, closeTo(10, 0.0001));
  });

  test('level unlock requires prior-level mastery ratio', () {
    const empty = ProgressSnapshot();
    expect(ExerciseCatalog.levelUnlocked(empty, LevelId.l2), isFalse);
    expect(ExerciseCatalog.unlocked(empty, LevelId.l2), isEmpty);

    final l1Mastered = ExerciseCatalog.all
        .take(14)
        .map((exercise) => '${exercise.id}:${LevelId.l1.name}')
        .toSet();
    final l2Snapshot = ProgressSnapshot(mastered: l1Mastered);

    expect(ExerciseCatalog.levelUnlocked(l2Snapshot, LevelId.l2), isTrue);

    final l2MasteredForL3 = ExerciseCatalog.all
        .take(16)
        .map((exercise) => '${exercise.id}:${LevelId.l2.name}')
        .toSet();
    final l3Locked = ProgressSnapshot(mastered: l2MasteredForL3.take(15).toSet());
    final l3Unlocked = ProgressSnapshot(mastered: l2MasteredForL3);

    expect(ExerciseCatalog.levelUnlocked(l3Locked, LevelId.l3), isFalse);
    expect(ExerciseCatalog.levelUnlocked(l3Unlocked, LevelId.l3), isTrue);
  });

  test('mastery scoring gates progression updates', () {
    final progression = ProgressionEngine();
    const initial = ProgressSnapshot();

    const pass = SessionMetrics(avgError: 12, stability: 8, lockRatio: 0.8, driftCount: 1);
    final updated = progression.applyResult(
      snapshot: initial,
      exerciseId: 'PF_1',
      level: LevelId.l2,
      metrics: pass,
    );
    expect(updated.isMastered('PF_1', LevelId.l2), isTrue);

    const fail = SessionMetrics(avgError: 25, stability: 8, lockRatio: 0.8, driftCount: 1);
    final unchanged = progression.applyResult(
      snapshot: updated,
      exerciseId: 'PF_2',
      level: LevelId.l2,
      metrics: fail,
    );
    expect(unchanged.isMastered('PF_2', LevelId.l2), isFalse);
  });

  test('assisted attempts are tracked and do not grant mastery', () {
    final progression = ProgressionEngine();
    const initial = ProgressSnapshot();
    const pass = SessionMetrics(avgError: 5, stability: 2, lockRatio: 0.95, driftCount: 0);

    final unchanged = progression.applyResult(
      snapshot: initial,
      exerciseId: 'PF_1',
      level: LevelId.l1,
      metrics: pass,
      assisted: true,
      attemptedAt: DateTime.utc(2026, 1, 1),
    );

    expect(unchanged.isMastered('PF_1', LevelId.l1), isFalse);
    final progress = progression.progressFor('PF_1', LevelId.l1);
    expect(progress.assistedAttempts, 1);
    expect(progress.attempts, 1);
    expect(progress.masteryDate, isNull);
  });

  test('assist profile activates after 3 consecutive failures', () {
    final progression = ProgressionEngine();
    const initial = ProgressSnapshot();
    const fail = SessionMetrics(avgError: 50, stability: 30, lockRatio: 0.1, driftCount: 8);

    var snapshot = initial;
    for (var i = 0; i < 3; i++) {
      snapshot = progression.applyResult(
        snapshot: snapshot,
        exerciseId: 'PF_2',
        level: LevelId.l2,
        metrics: fail,
      );
    }

    final assist = progression.assistFor('PF_2', LevelId.l2);
    expect(assist.toleranceDeltaCents, 5);
    expect(assist.durationScale, 0.8);
  });

  test('assisted pass resets failure streak to avoid permanent assist', () {
    final progression = ProgressionEngine();
    const initial = ProgressSnapshot();
    const fail = SessionMetrics(avgError: 50, stability: 30, lockRatio: 0.1, driftCount: 8);
    const assistedPass = SessionMetrics(avgError: 5, stability: 2, lockRatio: 0.95, driftCount: 0);

    var snapshot = initial;
    for (var i = 0; i < 3; i++) {
      snapshot = progression.applyResult(
        snapshot: snapshot,
        exerciseId: 'PF_2',
        level: LevelId.l2,
        metrics: fail,
      );
    }
    expect(progression.assistFor('PF_2', LevelId.l2).durationScale, 0.8);

    snapshot = progression.applyResult(
      snapshot: snapshot,
      exerciseId: 'PF_2',
      level: LevelId.l2,
      metrics: assistedPass,
      assisted: true,
    );

    expect(snapshot.isMastered('PF_2', LevelId.l2), isFalse);
    expect(progression.progressFor('PF_2', LevelId.l2).consecutiveFailures, 0);
    expect(progression.assistFor('PF_2', LevelId.l2), AssistAdjustment.none);
  });

  test('skill decay refresh needed after 30 days from mastery', () {
    final progression = ProgressionEngine();
    const initial = ProgressSnapshot();
    const pass = SessionMetrics(avgError: 4, stability: 2, lockRatio: 0.95, driftCount: 0);
    final mastered = progression.applyResult(
      snapshot: initial,
      exerciseId: 'PF_3',
      level: LevelId.l1,
      metrics: pass,
      attemptedAt: DateTime.utc(2026, 1, 1),
    );
    expect(mastered.isMastered('PF_3', LevelId.l1), isTrue);

    expect(progression.needsRefresh('PF_3', LevelId.l1, DateTime.utc(2026, 1, 15)), isFalse);
    expect(progression.needsRefresh('PF_3', LevelId.l1, DateTime.utc(2026, 2, 2)), isTrue);
  });
}
