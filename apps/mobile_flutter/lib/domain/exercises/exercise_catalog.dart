export 'exercise_definition.dart';
export 'level_defaults.dart';
export 'level_id.dart';
export 'mastery_thresholds.dart';
export 'mode_id.dart';
export 'progress_snapshot.dart';
export 'unlock_rules.dart';
export 'mastery_evaluator.dart';
export 'progression_engine.dart';

import 'exercise_definition.dart';
import 'level_id.dart';
import 'mode_id.dart';
import 'progress_snapshot.dart';
import 'unlock_rules.dart';

class ExerciseCatalog {
  static const List<ModeId> modeOrder = [
    ModeId.modePf,
    ModeId.modeDa,
    ModeId.modeRp,
    ModeId.modeGs,
    ModeId.modeLt,
  ];

  static final List<ExerciseDefinition> all = [
    ExerciseDefinition(id: 'PF_1', mode: ModeId.modePf, name: 'Single Pitch Hold (Referenced)', unlockRule: (_, __) => true),
    ExerciseDefinition(id: 'PF_2', mode: ModeId.modePf, name: 'Single Pitch Hold (Silent)', unlockRule: (s, l) => s.isMastered('PF_1', l)),
    ExerciseDefinition(id: 'PF_3', mode: ModeId.modePf, name: 'Random Pitch Hold', unlockRule: (s, l) => s.isMastered('PF_2', l)),
    ExerciseDefinition(id: 'PF_4', mode: ModeId.modePf, name: 'Fatigue Hold', unlockRule: (s, l) => s.isMastered('PF_3', l)),
    ExerciseDefinition(id: 'DA_1', mode: ModeId.modeDa, name: 'Drift Detection', driftAwarenessMode: true, unlockRule: (s, l) => s.isMastered('PF_2', l)),
    ExerciseDefinition(id: 'DA_2', mode: ModeId.modeDa, name: 'Drift Recovery', driftAwarenessMode: true, unlockRule: (s, l) => s.isMastered('DA_1', l)),
    ExerciseDefinition(id: 'DA_3', mode: ModeId.modeDa, name: 'Drift Under Vibrato', driftAwarenessMode: true, unlockRule: (s, l) => s.isMastered('DA_2', l)),
    ExerciseDefinition(id: 'RP_1', mode: ModeId.modeRp, name: '±1 Semitone', unlockRule: (s, l) => s.isMastered('PF_3', l)),
    ExerciseDefinition(id: 'RP_2', mode: ModeId.modeRp, name: '±2, ±3 Semitones', unlockRule: (s, l) => s.isMastered('RP_1', l)),
    ExerciseDefinition(id: 'RP_3', mode: ModeId.modeRp, name: 'Mixed Jumps', unlockRule: (s, l) => s.isMastered('RP_2', l)),
    ExerciseDefinition(id: 'RP_4', mode: ModeId.modeRp, name: 'Two-Step Arithmetic', unlockRule: (s, l) => s.isMastered('RP_3', l)),
    ExerciseDefinition(id: 'RP_5', mode: ModeId.modeRp, name: 'Silent Arithmetic', unlockRule: (s, l) => s.isMastered('RP_4', l)),
    ExerciseDefinition(id: 'GS_1', mode: ModeId.modeGs, name: 'Unison Lock', unlockRule: (s, l) => s.isMastered('PF_3', l)),
    ExerciseDefinition(id: 'GS_2', mode: ModeId.modeGs, name: 'Chord Anchor', unlockRule: (s, l) => s.isMastered('GS_1', l)),
    ExerciseDefinition(id: 'GS_3', mode: ModeId.modeGs, name: 'Moving Anchor', unlockRule: (s, l) => s.isMastered('GS_2', l)),
    ExerciseDefinition(id: 'GS_4', mode: ModeId.modeGs, name: 'Distraction Layer', unlockRule: (s, l) => s.isMastered('GS_3', l)),
    ExerciseDefinition(id: 'LT_1', mode: ModeId.modeLt, name: 'Note Identification', unlockRule: (s, l) => s.isMastered('PF_1', l)),
    ExerciseDefinition(id: 'LT_2', mode: ModeId.modeLt, name: 'Color & Shape Match', unlockRule: (s, l) => s.isMastered('LT_1', l)),
    ExerciseDefinition(id: 'LT_3', mode: ModeId.modeLt, name: 'Octave Discrimination', unlockRule: (s, l) => s.isMastered('LT_2', l)),
  ];

  static ExerciseDefinition byId(String id) => all.firstWhere((e) => e.id == id);

  static bool levelUnlocked(ProgressSnapshot snapshot, LevelId level) =>
      UnlockRules.levelUnlocked(snapshot, level, all);

  static bool modeUnlocked(ProgressSnapshot snapshot, ModeId mode, LevelId level) =>
      UnlockRules.modeUnlocked(snapshot, mode, level, modeOrder, all);

  static List<ExerciseDefinition> unlocked(ProgressSnapshot snapshot, LevelId level) {
    if (!levelUnlocked(snapshot, level)) return const [];
    return all
        .where((e) => modeUnlocked(snapshot, e.mode, level))
        .where((e) => e.unlockRule(snapshot, level))
        .toList(growable: false);
  }
}
