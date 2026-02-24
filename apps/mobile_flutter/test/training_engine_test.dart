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

  test('low confidence overrides state', () {
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
}
