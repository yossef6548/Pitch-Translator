import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/exercises/exercise_catalog.dart';
import 'package:pitch_translator/exercises/progression_engine.dart';

void main() {
  test('level defaults match spec values', () {
    expect(levelDefaults[LevelId.l1]!.toleranceCents, 35);
    expect(levelDefaults[LevelId.l2]!.driftThresholdCents, 30);
    expect(levelDefaults[LevelId.l3]!.toleranceCents, 10);
  });

  test('unlock chain requires prior mastery in same level', () {
    const empty = ProgressSnapshot();
    expect(ExerciseCatalog.byId('PF_1').unlockRule(empty, LevelId.l2), isTrue);
    expect(ExerciseCatalog.byId('PF_2').unlockRule(empty, LevelId.l2), isFalse);

    const withPf1 = ProgressSnapshot(mastered: {'PF_1:l2'});
    expect(ExerciseCatalog.byId('PF_2').unlockRule(withPf1, LevelId.l2), isTrue);
    expect(ExerciseCatalog.byId('DA_1').unlockRule(withPf1, LevelId.l2), isFalse);
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
}
