import 'exercise_catalog.dart';
import 'progression_engine.dart';

class MasteryEvaluator {
  const MasteryEvaluator();

  bool evaluate({
    required LevelId level,
    required SessionMetrics metrics,
    required bool assisted,
  }) {
    if (assisted) return false;
    final threshold = masteryThresholds[level]!;
    return metrics.avgError <= threshold.avgErrorMax &&
        metrics.stability <= threshold.stabilityMax &&
        metrics.lockRatio >= threshold.lockRatioMin &&
        metrics.driftCount <= threshold.driftCountMax;
  }
}
