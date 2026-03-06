import 'exercise_definition.dart';
import 'level_id.dart';
import 'mode_id.dart';
import 'progress_snapshot.dart';

class UnlockRules {
  static const double l2UnlockRatio = 0.70;
  static const double l3UnlockRatio = 0.80;

  static bool levelUnlocked(
    ProgressSnapshot snapshot,
    LevelId level,
    List<ExerciseDefinition> all,
  ) {
    switch (level) {
      case LevelId.l1:
        return true;
      case LevelId.l2:
        return _masteredRatio(snapshot, LevelId.l1, all) >= l2UnlockRatio;
      case LevelId.l3:
        return _masteredRatio(snapshot, LevelId.l2, all) >= l3UnlockRatio;
    }
  }

  static bool modeUnlocked(
    ProgressSnapshot snapshot,
    ModeId mode,
    LevelId level,
    List<ModeId> modeOrder,
    List<ExerciseDefinition> all,
  ) {
    final modeIndex = modeOrder.indexOf(mode);
    if (modeIndex <= 0) return true;

    final previousMode = modeOrder[modeIndex - 1];
    final previousModeExercises = all.where((e) => e.mode == previousMode);
    return previousModeExercises.every((e) => snapshot.isMastered(e.id, level));
  }

  static double _masteredRatio(
    ProgressSnapshot snapshot,
    LevelId level,
    List<ExerciseDefinition> all,
  ) {
    final masteredCount =
        all.where((exercise) => snapshot.isMastered(exercise.id, level)).length;
    if (all.isEmpty) return 0;
    return masteredCount / all.length;
  }
}
