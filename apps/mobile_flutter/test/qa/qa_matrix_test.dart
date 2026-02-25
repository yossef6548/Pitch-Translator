import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/exercises/exercise_catalog.dart';
import 'package:pitch_translator/exercises/progression_engine.dart';
import 'package:pitch_translator/training/mode_evaluators.dart';
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

    test('QA-PF-03 silent hold drift confirms and fails hold', () {
      final engine = TrainingEngine(
        config: const ExerciseConfig(
          countdownMs: 0,
          toleranceCents: 20,
          driftThresholdCents: 25,
          driftAwarenessMode: false,
        ),
      );
      engine.onIntent(TrainingIntent.start);

      engine.onDspFrame(dspFrame(0, cents: 3));
      engine.onDspFrame(dspFrame(180, cents: 2));
      engine.onDspFrame(dspFrame(360, cents: 1));

      engine.onDspFrame(dspFrame(920, cents: 28));
      engine.onDspFrame(dspFrame(1080, cents: 28));
      engine.onDspFrame(dspFrame(1220, cents: 28));
      engine.onDspFrame(dspFrame(1380, cents: 28));

      expect(engine.state.id, LivePitchStateId.driftConfirmed);
      expect(engine.confirmedDriftCount, 1);
    });
  });

  group('Drift Awareness QA IDs', () {
    test('QA-DA-03 recovery time under 2 seconds counts toward mastery', () {
      final engine = TrainingEngine(
        config: const ExerciseConfig(
          countdownMs: 0,
          toleranceCents: 20,
          driftThresholdCents: 30,
          driftAwarenessMode: true,
        ),
      );
      engine.onIntent(TrainingIntent.start);

      engine.onDspFrame(dspFrame(0, cents: 3));
      engine.onDspFrame(dspFrame(180, cents: 2));
      engine.onDspFrame(dspFrame(360, cents: 2));

      engine.onDspFrame(dspFrame(930, cents: 40));
      engine.onDspFrame(dspFrame(1080, cents: 40));
      engine.onDspFrame(dspFrame(1230, cents: 40));

      engine.onDspFrame(dspFrame(2520, cents: 6));
      engine.onDspFrame(dspFrame(2660, cents: 4));
      engine.onDspFrame(dspFrame(2870, cents: 2));

      expect(engine.state.id, LivePitchStateId.locked);
      expect(engine.averageRecoveryTimeMs, isNotNull);
      expect(engine.averageRecoveryTimeMs!, lessThanOrEqualTo(2000));
    });
  });

  group('Relative Pitch QA IDs', () {
    test('QA-RP-01 arithmetic correctness for +1 semitone', () {
      const evaluator = RelativePitchEvaluator();
      const prompt = RelativePitchPrompt(baseMidi: 60, operationSemitones: 1);
      final result = evaluator.evaluate(
        prompt: prompt,
        frame: dspFrame(0, nearestMidi: 61, cents: 6),
      );

      expect(result.targetMidi, 61);
      expect(result.isCorrect, isTrue);
    });

    test('QA-RP-02 arithmetic failure without partial credit', () {
      const evaluator = RelativePitchEvaluator();
      const prompt = RelativePitchPrompt(baseMidi: 60, operationSemitones: 1);
      final result = evaluator.evaluate(
        prompt: prompt,
        frame: dspFrame(0, nearestMidi: 62, cents: 0),
      );

      expect(result.targetMidi, 61);
      expect(result.isCorrect, isFalse);
    });
  });

  group('Group Simulation QA IDs', () {
    test('QA-GS-01 unison lock maintains at least 80 percent lock ratio', () {
      const evaluator = GroupSimulationEvaluator();
      final frames = <DspFrame>[
        dspFrame(0, nearestMidi: 60, cents: 5),
        dspFrame(250, nearestMidi: 60, cents: 4),
        dspFrame(500, nearestMidi: 60, cents: 3),
        dspFrame(750, nearestMidi: 60, cents: 6),
        dspFrame(1000, nearestMidi: 60, cents: 2),
      ];

      final result = evaluator.evaluate(
        frames: frames,
        anchorMidi: 60,
        toleranceCents: 20,
        driftThresholdCents: 30,
      );

      expect(result.lockRatio, greaterThanOrEqualTo(0.8));
      expect(result.driftEvents, 0);
    });

    test('QA-GS-02 chord confusion logs drift and fails mastery gate', () {
      const evaluator = GroupSimulationEvaluator();
      final frames = <DspFrame>[
        dspFrame(0, nearestMidi: 64, cents: 40),
        dspFrame(220, nearestMidi: 67, cents: 42),
        dspFrame(440, nearestMidi: 64, cents: 41),
      ];

      final result = evaluator.evaluate(
        frames: frames,
        anchorMidi: 60,
        toleranceCents: 20,
        driftThresholdCents: 30,
        confusionNotes: const {64, 67},
      );

      expect(result.confusionDetected, isTrue);
      expect(result.driftEvents, greaterThan(0));
      expect(result.lockRatio, lessThan(0.8));
    });
  });

  group('Listening Translation QA IDs', () {
    test('QA-LT-01 note identification succeeds on exact match', () {
      const evaluator = ListeningTranslationEvaluator();
      final correct = evaluator.evaluate(
        prompt: const ListeningPrompt(expectedNote: 'A', expectedOctave: 4),
        response:
            const ListeningResponse(selectedNote: 'A', selectedOctave: 4),
      );

      expect(correct, isTrue);
    });

    test('QA-LT-02 octave discrimination fails when octave mismatches', () {
      const evaluator = ListeningTranslationEvaluator();
      final correct = evaluator.evaluate(
        prompt: const ListeningPrompt(expectedNote: 'C', expectedOctave: 3),
        response:
            const ListeningResponse(selectedNote: 'C', selectedOctave: 4),
      );

      expect(correct, isFalse);
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
      expect(
          ExerciseCatalog.modeUnlocked(snapshot, ModeId.modeDa, LevelId.l1),
          isTrue);
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

    test('QA-FM-02 route interruption degrades then recovers lock state', () {
      final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
      engine.onIntent(TrainingIntent.start);
      engine.onDspFrame(dspFrame(0, cents: 2));
      engine.onDspFrame(dspFrame(170, cents: 2));
      engine.onDspFrame(dspFrame(340, cents: 2));
      expect(engine.state.id, LivePitchStateId.locked);

      engine.onDspFrame(dspFrame(500, cents: null, confidence: 0.9));
      expect(engine.state.id, LivePitchStateId.lowConfidence);

      engine.onDspFrame(dspFrame(760, cents: 3, confidence: 0.9));
      expect(engine.state.id, LivePitchStateId.locked);
    });
  });
}
