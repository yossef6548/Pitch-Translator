import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/qa/replay_harness.dart';
import 'package:pitch_translator/training/training_engine.dart';
import 'package:pt_contracts/pt_contracts.dart';

DspFrame frame(int ts, {double? cents = 0, double confidence = 0.9}) => DspFrame(
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
    final frames = List.generate(20, (i) => frame(i * 10, cents: null, confidence: 0.8));
    final result = harness.runFrames(frames);

    expect(result.finalState.id, LivePitchStateId.lowConfidence);
    expect(result.finalState.saturation, PtConstants.lowConfidenceSaturation);
    expect(result.finalState.errorReadoutVisible, isFalse);
  });

  test('QA-DA-01 drift candidate recovery returns to locked', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0, driftAwarenessMode: true));
    engine.onIntent(TrainingIntent.start);

    final frames = <DspFrame>[
      frame(0, cents: 5),
      frame(150, cents: 4),
      frame(320, cents: 3),
      frame(900, cents: 31),
      frame(1020, cents: 31),
      frame(1120, cents: 10),
    ];

    final result = ReplayHarness(engine).runFrames(frames);
    expect(result.visited(LivePitchStateId.driftCandidate), isTrue);
    expect(result.finalState.id, LivePitchStateId.locked);
  });

  test('replay parser loads jsonl traces', () {
    final trace = File('../../qa/traces/sample_trace.jsonl').readAsStringSync();
    final frames = ReplayHarness.parseJsonl(trace);
    expect(frames.length, 2);
    expect(frames.first.hasUsablePitch, isFalse);
    expect(frames.last.nearestMidi, 69);
  });
}
