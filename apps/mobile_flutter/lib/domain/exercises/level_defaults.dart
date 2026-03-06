import 'level_id.dart';

class LevelDefaults {
  final double toleranceCents;
  final double driftThresholdCents;

  const LevelDefaults({
    required this.toleranceCents,
    required this.driftThresholdCents,
  });
}

const Map<LevelId, LevelDefaults> levelDefaults = {
  LevelId.l1: LevelDefaults(toleranceCents: 35, driftThresholdCents: 45),
  LevelId.l2: LevelDefaults(toleranceCents: 20, driftThresholdCents: 30),
  LevelId.l3: LevelDefaults(toleranceCents: 10, driftThresholdCents: 20),
};
