import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/qa/replay_harness.dart';
import 'package:pitch_translator/training/training_engine.dart';
import 'package:pt_contracts/pt_contracts.dart';

import '../support/dsp_frame_factory.dart';

void main() {
  test('QA-G-01 null pitch handling enters low confidence', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    final harness = ReplayHarness(engine);
    final frames =
        List.generate(20, (i) => dspFrame(i * 10, cents: null, confidence: 0.8));
    final result = harness.runFrames(frames);

    expect(result.finalState.id, LivePitchStateId.lowConfidence);
    expect(result.finalState.saturation, PtConstants.lowConfidenceSaturation);
    expect(result.finalState.errorReadoutVisible, isFalse);
  });

  test('QA-DA-01 drift candidate recovery returns to locked', () {
    final engine = TrainingEngine(
      config: const ExerciseConfig(countdownMs: 0, driftAwarenessMode: true),
    );
    engine.onIntent(TrainingIntent.start);

    final frames = <DspFrame>[
      dspFrame(0, cents: 5),
      dspFrame(150, cents: 4),
      dspFrame(320, cents: 3),
      dspFrame(900, cents: 31),
      dspFrame(960, cents: 31),
      dspFrame(1030, cents: 10),
    ];

    final result = ReplayHarness(engine).runFrames(frames);
    expect(result.visited(LivePitchStateId.driftCandidate), isTrue);
    expect(result.finalState.id, LivePitchStateId.locked);
  });

  test('QA-DA-02 drift replay trigger enters drift confirmed', () {
    final engine = TrainingEngine(
      config: const ExerciseConfig(
        countdownMs: 0,
        driftAwarenessMode: false,
        driftThresholdCents: 30,
      ),
    );
    engine.onIntent(TrainingIntent.start);

    final frames = <DspFrame>[
      dspFrame(0, cents: 3),
      dspFrame(170, cents: 2),
      dspFrame(340, cents: 1),
      dspFrame(900, cents: 40),
      dspFrame(1030, cents: 40),
      dspFrame(1170, cents: 40),
      dspFrame(1300, cents: 40),
    ];

    final result = ReplayHarness(engine).runFrames(frames);

    expect(result.visited(LivePitchStateId.driftCandidate), isTrue);
    expect(result.finalState.id, LivePitchStateId.driftConfirmed);
    expect(result.firstTransitionTo(LivePitchStateId.driftConfirmed), isNotNull);
  });

  test('QA-G-02 confidence override breaks lock immediately', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    final harness = ReplayHarness(engine);
    final frames = <DspFrame>[
      dspFrame(0, cents: 2, confidence: 0.92),
      dspFrame(160, cents: 1, confidence: 0.92),
      dspFrame(340, cents: 1, confidence: 0.92),
      dspFrame(500, cents: 0, confidence: 0.55),
      dspFrame(600, cents: 0, confidence: 0.55),
      dspFrame(700, cents: 0, confidence: 0.55),
      dspFrame(800, cents: 0, confidence: 0.55),
      dspFrame(900, cents: 0, confidence: 0.55),
      dspFrame(1000, cents: 0, confidence: 0.55),
    ];
    final result = harness.runFrames(frames);

    expect(result.visited(LivePitchStateId.locked), isTrue);
    expect(result.finalState.id, LivePitchStateId.lowConfidence);
    expect(result.finalState.haloIntensity, 0);
    expect(result.finalState.errorReadoutVisible, isFalse);
  });

  test('QA-VB-01 valid vibrato keeps lock and averages effective error', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    final frames = <DspFrame>[
      dspFrame(0,
          cents: -25,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 25),
      dspFrame(120,
          cents: 25,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 25),
      dspFrame(240,
          cents: -25,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 25),
      dspFrame(360,
          cents: 25,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 25),
      dspFrame(820,
          cents: -25,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 25),
      dspFrame(950,
          cents: 25,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 25),
      dspFrame(1100,
          cents: -25,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 25),
    ];

    final result = ReplayHarness(engine).runFrames(frames);
    expect(result.visited(LivePitchStateId.locked), isTrue);
    expect(result.finalState.id, LivePitchStateId.locked);
    expect(result.finalState.effectiveError!.abs(), lessThanOrEqualTo(10));
  });

  test('QA-VB-02 excessive vibrato depth is treated as pitch error', () {
    final engine = TrainingEngine(
      config: const ExerciseConfig(
        countdownMs: 0,
        driftAwarenessMode: true,
        driftThresholdCents: 30,
      ),
    );
    engine.onIntent(TrainingIntent.start);

    final frames = <DspFrame>[
      dspFrame(0, cents: 4),
      dspFrame(160, cents: 3),
      dspFrame(340, cents: 2),
      dspFrame(900,
          cents: 40,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 45),
      dspFrame(1020,
          cents: 40,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 45),
      dspFrame(1160,
          cents: 40,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 45),
      dspFrame(1320,
          cents: 40,
          vibratoDetected: true,
          vibratoRateHz: 6,
          vibratoDepthCents: 45),
    ];

    final result = ReplayHarness(engine).runFrames(frames);
    expect(result.visited(LivePitchStateId.driftCandidate), isTrue);
    expect(result.finalState.id, LivePitchStateId.driftConfirmed);
  });

  test('QA-VD-01 cents to pixel mapping uses semitone width constant', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    final result = ReplayHarness(engine).runFrames([
      dspFrame(0, cents: 50),
    ]);

    expect(
      result.finalState.xOffsetPx,
      closeTo(0.5 * PtConstants.semitoneWidthPx, 0.0001),
    );
  });

  test('QA-VD-02 deformation hits max at drift threshold', () {
    const driftThreshold = 30.0;
    final engine = TrainingEngine(
      config: const ExerciseConfig(
        countdownMs: 0,
        driftThresholdCents: driftThreshold,
      ),
    );
    engine.onIntent(TrainingIntent.start);

    final result = ReplayHarness(engine).runFrames([
      dspFrame(0, cents: driftThreshold),
    ]);

    expect(result.finalState.deformPx, closeTo(PtConstants.maxDeformPx, 0.0001));
    expect(result.finalState.errorFactorE, closeTo(1.0, 0.0001));
  });

  test('replay parser loads jsonl traces', () {
    final trace = File('../../qa/traces/sample_trace.jsonl').readAsStringSync();
    final frames = ReplayHarness.parseJsonl(trace);
    expect(frames.length, 2);
    expect(frames.first.hasUsablePitch, isFalse);
    expect(frames.last.nearestMidi, 69);
  });
}
