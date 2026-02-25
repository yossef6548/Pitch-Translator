import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/qa/replay_harness.dart';
import 'package:pitch_translator/training/training_engine.dart';
import 'package:pt_contracts/pt_contracts.dart';

DspFrame frame(int ts, {double? cents = 0, double confidence = 0.9}) =>
    DspFrame(
      timestampMs: ts,
      freqHz: cents == null ? null : 440,
      midiFloat: cents == null ? null : 69,
      nearestMidi: cents == null ? null : 69,
      centsError: cents,
      confidence: confidence,
      vibrato: const VibratoInfo(detected: false),
    );

void main() {
  test('QA-G-01 null pitch handling enters low confidence', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    final harness = ReplayHarness(engine);
    final frames =
        List.generate(20, (i) => frame(i * 10, cents: null, confidence: 0.8));
    final result = harness.runFrames(frames);

    expect(result.finalState.id, LivePitchStateId.lowConfidence);
    expect(result.finalState.saturation, PtConstants.lowConfidenceSaturation);
    expect(result.finalState.errorReadoutVisible, isFalse);
  });

  test('QA-DA-01 drift candidate recovery returns to locked', () {
    final engine = TrainingEngine(
        config: const ExerciseConfig(countdownMs: 0, driftAwarenessMode: true));
    engine.onIntent(TrainingIntent.start);

    final frames = <DspFrame>[
      frame(0, cents: 5),
      frame(150, cents: 4),
      frame(320, cents: 3),
      frame(900, cents: 31),
      frame(960, cents: 31),
      frame(1030, cents: 10),
    ];

    final result = ReplayHarness(engine).runFrames(frames);
    expect(result.visited(LivePitchStateId.driftCandidate), isTrue);
    expect(result.finalState.id, LivePitchStateId.locked);
  });

  test('QA-G-02 confidence override breaks lock immediately', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    final harness = ReplayHarness(engine);
    final frames = <DspFrame>[
      frame(0, cents: 2, confidence: 0.92),
      frame(160, cents: 1, confidence: 0.92),
      frame(340, cents: 1, confidence: 0.92),
      frame(500, cents: 0, confidence: 0.55),
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

    DspFrame vibratoFrame(int ts, double cents) => DspFrame(
          timestampMs: ts,
          freqHz: 440,
          midiFloat: 69,
          nearestMidi: 69,
          centsError: cents,
          confidence: 0.9,
          vibrato: const VibratoInfo(detected: true, rateHz: 6, depthCents: 25),
        );

    final frames = <DspFrame>[
      vibratoFrame(0, -25),
      vibratoFrame(120, 25),
      vibratoFrame(240, -25),
      vibratoFrame(360, 25),
      vibratoFrame(820, -25),
      vibratoFrame(950, 25),
      vibratoFrame(1100, -25),
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

    DspFrame deepVibratoFrame(int ts, double cents) => DspFrame(
          timestampMs: ts,
          freqHz: 440,
          midiFloat: 69,
          nearestMidi: 69,
          centsError: cents,
          confidence: 0.9,
          vibrato: const VibratoInfo(detected: true, rateHz: 6, depthCents: 45),
        );

    final frames = <DspFrame>[
      frame(0, cents: 4),
      frame(160, cents: 3),
      frame(340, cents: 2),
      deepVibratoFrame(900, 40),
      deepVibratoFrame(1020, 40),
      deepVibratoFrame(1160, 40),
      deepVibratoFrame(1320, 40),
    ];

    final result = ReplayHarness(engine).runFrames(frames);
    expect(result.visited(LivePitchStateId.driftCandidate), isTrue);
    expect(result.finalState.id, LivePitchStateId.driftConfirmed);
  });

  test('QA-VD-01 cents to pixel mapping uses semitone width constant', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    final result = ReplayHarness(engine).runFrames([
      frame(0, cents: 50),
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
      frame(0, cents: driftThreshold),
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
