import 'package:pt_contracts/pt_contracts.dart';

enum ModeId { modePf, modeDa, modeRp, modeGs, modeLt }

enum LevelId { l1, l2, l3 }

class LevelDefaults {
  final double toleranceCents;
  final double driftThresholdCents;

  const LevelDefaults({required this.toleranceCents, required this.driftThresholdCents});
}

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

class ExerciseDefinition {
  final String id;
  final ModeId mode;
  final String name;
  final bool driftAwarenessMode;
  final bool Function(ProgressSnapshot snapshot, LevelId level) unlockRule;

  const ExerciseDefinition({
    required this.id,
    required this.mode,
    required this.name,
    required this.unlockRule,
    this.driftAwarenessMode = false,
  });

  ExerciseConfig configForLevel(LevelId level) {
    final defaults = levelDefaults[level]!;
    return ExerciseConfig(
      toleranceCents: defaults.toleranceCents,
      driftThresholdCents: defaults.driftThresholdCents,
      driftAwarenessMode: driftAwarenessMode,
      countdownMs: PtConstants.defaultCountdownMs,
    );
  }
}

const Map<LevelId, LevelDefaults> levelDefaults = {
  LevelId.l1: LevelDefaults(toleranceCents: 35, driftThresholdCents: 45),
  LevelId.l2: LevelDefaults(toleranceCents: 20, driftThresholdCents: 30),
  LevelId.l3: LevelDefaults(toleranceCents: 10, driftThresholdCents: 20),
};

const Map<LevelId, MasteryThreshold> masteryThresholds = {
  LevelId.l1: MasteryThreshold(avgErrorMax: 25, stabilityMax: 18, lockRatioMin: 0.60, driftCountMax: 4),
  LevelId.l2: MasteryThreshold(avgErrorMax: 15, stabilityMax: 10, lockRatioMin: 0.75, driftCountMax: 2),
  LevelId.l3: MasteryThreshold(avgErrorMax: 8, stabilityMax: 5, lockRatioMin: 0.85, driftCountMax: 1),
};

class ProgressSnapshot {
  final Set<String> mastered;

  const ProgressSnapshot({this.mastered = const {}});

  bool isMastered(String exerciseId, LevelId level) => mastered.contains(_key(exerciseId, level));

  static String _key(String id, LevelId level) => '$id:${level.name}';
}

class ExerciseCatalog {
  static final List<ExerciseDefinition> all = [
    ExerciseDefinition(id: 'PF_1', mode: ModeId.modePf, name: 'Single Pitch Hold (Referenced)', unlockRule: (_, __) => true),
    ExerciseDefinition(
      id: 'PF_2',
      mode: ModeId.modePf,
      name: 'Single Pitch Hold (Silent)',
      unlockRule: (s, l) => s.isMastered('PF_1', l),
    ),
    ExerciseDefinition(
      id: 'PF_3',
      mode: ModeId.modePf,
      name: 'Random Pitch Hold',
      unlockRule: (s, l) => s.isMastered('PF_2', l),
    ),
    ExerciseDefinition(
      id: 'PF_4',
      mode: ModeId.modePf,
      name: 'Fatigue Hold',
      unlockRule: (s, l) => s.isMastered('PF_3', l),
    ),
    ExerciseDefinition(
      id: 'DA_1',
      mode: ModeId.modeDa,
      name: 'Drift Detection',
      driftAwarenessMode: true,
      unlockRule: (s, l) => s.isMastered('PF_2', l),
    ),
    ExerciseDefinition(
      id: 'DA_2',
      mode: ModeId.modeDa,
      name: 'Drift Recovery',
      driftAwarenessMode: true,
      unlockRule: (s, l) => s.isMastered('DA_1', l),
    ),
    ExerciseDefinition(
      id: 'DA_3',
      mode: ModeId.modeDa,
      name: 'Drift Under Vibrato',
      driftAwarenessMode: true,
      unlockRule: (s, l) => s.isMastered('DA_2', l),
    ),
    ExerciseDefinition(
      id: 'RP_1',
      mode: ModeId.modeRp,
      name: '±1 Semitone',
      unlockRule: (s, l) => s.isMastered('PF_3', l),
    ),
    ExerciseDefinition(
      id: 'RP_2',
      mode: ModeId.modeRp,
      name: '±2, ±3 Semitones',
      unlockRule: (s, l) => s.isMastered('RP_1', l),
    ),
    ExerciseDefinition(
      id: 'RP_3',
      mode: ModeId.modeRp,
      name: 'Mixed Jumps',
      unlockRule: (s, l) => s.isMastered('RP_2', l),
    ),
  ];

  static ExerciseDefinition byId(String id) => all.firstWhere((e) => e.id == id);

  static List<ExerciseDefinition> unlocked(ProgressSnapshot snapshot, LevelId level) {
    return all.where((e) => e.unlockRule(snapshot, level)).toList(growable: false);
  }
}
