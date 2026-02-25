import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/exercises/exercise_catalog.dart';
import 'package:pitch_translator/exercises/progression_engine.dart';
import 'package:pitch_translator/training/training_engine.dart';
import 'package:pt_contracts/pt_contracts.dart';

import '../support/dsp_frame_factory.dart';

void main() {
  group('Pitch Freezing QA IDs', () {
    test('QA-PF-01 basic lock acquisition', () {
      final engine = TrainingEngine(
        config: const ExerciseConfig(
          countdownMs: 0,
          toleranceCents: 35,
        ),
      );
      engine.onIntent(TrainingIntent.start);

      engine.onDspFrame(dspFrame(0, cents: 5));
      engine.onDspFrame(dspFrame(160, cents: 5));
      engine.onDspFrame(dspFrame(320, cents: 5));

      expect(engine.state.id, LivePitchStateId.locked);
      expect(engine.state.deformPx, 0);
      expect(engine.state.haloIntensity, 1.0);
    });

    test('QA-PF-02 near miss never locks', () {
      final engine = TrainingEngine(
        config: const ExerciseConfig(
          countdownMs: 0,
          toleranceCents: 35,
        ),
      );
      engine.onIntent(TrainingIntent.start);

      engine.onDspFrame(dspFrame(0, cents: 33));
      engine.onDspFrame(dspFrame(100, cents: 37));
      engine.onDspFrame(dspFrame(210, cents: 33));
      engine.onDspFrame(dspFrame(320, cents: 37));
      engine.onDspFrame(dspFrame(430, cents: 33));
      engine.onDspFrame(dspFrame(540, cents: 37));

      expect(engine.state.id, LivePitchStateId.seekingLock);
      expect(engine.state.haloIntensity, greaterThan(0));
    });
  });

  group('Analytics QA IDs', () {
    test('QA-AN-01 AvgError and stability calculation', () {
      final builder = SessionMetricsBuilder()
        ..addEffectiveError(10)
        ..addEffectiveError(12)
        ..addEffectiveError(8)
        ..addEffectiveError(10);

      final metrics = builder.build();

      expect(metrics.avgError, closeTo(10, 0.0001));
      expect(metrics.stability, closeTo(1.4142, 0.0001));
    });

    test('QA-AN-02 DriftCount is exact', () {
      final builder = SessionMetricsBuilder()
        ..addEffectiveError(3)
        ..addActiveTimeMs(1000, locked: true)
        ..incrementDrift()
        ..incrementDrift()
        ..incrementDrift();

      final metrics = builder.build();
      expect(metrics.driftCount, 3);
    });
  });

  group('Progression QA IDs', () {
    test('QA-PR-01 mode unlock after PF mastery', () {
      final pfMastered = ExerciseCatalog.all
          .where((exercise) => exercise.mode == ModeId.modePf)
          .map((exercise) => '${exercise.id}:${LevelId.l1.name}')
          .toSet();

      final snapshot = ProgressSnapshot(mastered: pfMastered);
      expect(ExerciseCatalog.modeUnlocked(snapshot, ModeId.modeDa, LevelId.l1), isTrue);
    });

    test('QA-PR-02 L3 unlock requires 80 percent L2 mastery', () {
      final l2Mastered = ExerciseCatalog.all
          .take((ExerciseCatalog.all.length * 0.8).ceil())
          .map((exercise) => '${exercise.id}:${LevelId.l2.name}')
          .toSet();

      final snapshot = ProgressSnapshot(mastered: l2Mastered);
      expect(ExerciseCatalog.levelUnlocked(snapshot, LevelId.l3), isTrue);
    });
  });

  group('Failure-mode QA IDs', () {
    test('QA-FM-01 pause/resume preserves session state', () {
      final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
      engine.onIntent(TrainingIntent.start);
      engine.onDspFrame(dspFrame(0, cents: 2));
      engine.onDspFrame(dspFrame(170, cents: 2));
      engine.onDspFrame(dspFrame(340, cents: 2));
      expect(engine.state.id, LivePitchStateId.locked);

      engine.onIntent(TrainingIntent.pause);
      expect(engine.state.id, LivePitchStateId.paused);

      engine.onIntent(TrainingIntent.resume);
      expect(engine.state.id, LivePitchStateId.locked);
    });
  });
}
