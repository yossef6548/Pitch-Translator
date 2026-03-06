import 'level_id.dart';

class MasteryThreshold {
  final double avgErrorMax;
  final double stabilityMax;
  final double lockRatioMin;
  final int driftCountMax;

  const MasteryThreshold({
    required this.avgErrorMax,
    required this.stabilityMax,
    required this.lockRatioMin,
    required this.driftCountMax,
  });
}

const Map<LevelId, MasteryThreshold> masteryThresholds = {
  LevelId.l1: MasteryThreshold(
    avgErrorMax: 25,
    stabilityMax: 18,
    lockRatioMin: 0.60,
    driftCountMax: 4,
  ),
  LevelId.l2: MasteryThreshold(
    avgErrorMax: 15,
    stabilityMax: 10,
    lockRatioMin: 0.75,
    driftCountMax: 2,
  ),
  LevelId.l3: MasteryThreshold(
    avgErrorMax: 8,
    stabilityMax: 5,
    lockRatioMin: 0.85,
    driftCountMax: 1,
  ),
};
