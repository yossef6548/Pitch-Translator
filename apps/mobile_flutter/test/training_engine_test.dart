import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/training/training_engine.dart';
import 'package:pt_contracts/pt_contracts.dart';

DspFrame frame(int ts, {double? cents = 0, double confidence = 0.9}) {
  return DspFrame(
    timestampMs: ts,
    freqHz: cents == null ? null : 440,
    midiFloat: cents == null ? null : 69,
    nearestMidi: cents == null ? null : 69,
    centsError: cents,
    confidence: confidence,
    vibrato: const VibratoInfo(detected: false),
  );
}

void main() {
  test('seeking lock enters locked after lock acquire time', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    engine.onDspFrame(frame(0, cents: 5));
    engine.onDspFrame(frame(150, cents: 5));
    engine.onDspFrame(frame(320, cents: 5));

    expect(engine.state.id, LivePitchStateId.locked);
  });

  test('low confidence overrides state and clears readout', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    engine.onDspFrame(frame(0, cents: 0));
    engine.onDspFrame(frame(400, cents: 0));
    expect(engine.state.id, LivePitchStateId.locked);

    engine.onDspFrame(frame(500, cents: null, confidence: 0.9));
    expect(engine.state.id, LivePitchStateId.lowConfidence);
    expect(engine.state.centsError, isNull);
    expect(engine.state.displayCents, '—');
  });

  test('requires recovery confidence to exit low confidence', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    engine.onDspFrame(frame(0, cents: 0));
    engine.onDspFrame(frame(400, cents: 0));
    expect(engine.state.id, LivePitchStateId.locked);

    engine.onDspFrame(frame(450, cents: null, confidence: 0.9));
    expect(engine.state.id, LivePitchStateId.lowConfidence);

    engine.onDspFrame(frame(500, cents: 2, confidence: 0.62));
    expect(engine.state.id, LivePitchStateId.lowConfidence);

    engine.onDspFrame(frame(550, cents: 2, confidence: 0.66));
    expect(engine.state.id, isNot(LivePitchStateId.lowConfidence));
  });

  test('drift confirm requires contiguous threshold violation in candidate state', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    engine.onDspFrame(frame(0, cents: 0));
    engine.onDspFrame(frame(350, cents: 0));
    expect(engine.state.id, LivePitchStateId.locked);

    engine.onDspFrame(frame(900, cents: 40));
    engine.onDspFrame(frame(1110, cents: 40));
    expect(engine.state.id, LivePitchStateId.driftCandidate);

    engine.onDspFrame(frame(1160, cents: 25));
    expect(engine.state.id, LivePitchStateId.driftCandidate);

    engine.onDspFrame(frame(1210, cents: 40));
    engine.onDspFrame(frame(1260, cents: 40));
    expect(engine.state.id, LivePitchStateId.driftCandidate);

    engine.onDspFrame(frame(1460, cents: 40));
    expect(engine.state.id, LivePitchStateId.driftConfirmed);
  });
}
