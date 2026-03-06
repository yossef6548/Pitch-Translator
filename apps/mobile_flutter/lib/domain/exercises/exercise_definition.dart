import 'package:pt_contracts/pt_contracts.dart';

import 'level_defaults.dart';
import 'level_id.dart';
import 'mode_id.dart';
import 'progress_snapshot.dart';

typedef ExerciseUnlockRule = bool Function(ProgressSnapshot snapshot, LevelId level);

class ExerciseDefinition {
  final String id;
  final ModeId mode;
  final String name;
  final bool driftAwarenessMode;
  final ExerciseUnlockRule unlockRule;

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
