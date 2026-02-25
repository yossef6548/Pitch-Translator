import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/training/training_engine.dart';
import 'package:pt_contracts/pt_contracts.dart';

import 'support/dsp_frame_factory.dart';

void main() {
  test('seeking lock enters locked after lock acquire time', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    engine.onDspFrame(dspFrame(0, cents: 5));
    engine.onDspFrame(dspFrame(150, cents: 5));
    engine.onDspFrame(dspFrame(320, cents: 5));

    expect(engine.state.id, LivePitchStateId.locked);
  });

  test('low confidence overrides state', () {
    final engine = TrainingEngine(config: const ExerciseConfig(countdownMs: 0));
    engine.onIntent(TrainingIntent.start);

    engine.onDspFrame(dspFrame(0, cents: 0));
    engine.onDspFrame(dspFrame(400, cents: 0));
    expect(engine.state.id, LivePitchStateId.locked);

    engine.onDspFrame(dspFrame(500, cents: null, confidence: 0.9));
    expect(engine.state.id, LivePitchStateId.lowConfidence);

    expect(engine.state.centsError, isNull);
    expect(engine.state.displayCents, '—');
  });

  test('drift confirmation captures drift replay event snapshots', () {
    final engine = TrainingEngine(
      config: const ExerciseConfig(
        countdownMs: 0,
        driftAwarenessMode: true,
        driftThresholdCents: 30,
      ),
    );
    engine.onIntent(TrainingIntent.start);

    engine.onDspFrame(dspFrame(0, cents: 4));
    engine.onDspFrame(dspFrame(180, cents: 3));
    engine.onDspFrame(dspFrame(360, cents: 2));
    engine.onDspFrame(dspFrame(980, cents: 38));
    engine.onDspFrame(dspFrame(1120, cents: 39));
    engine.onDspFrame(dspFrame(1300, cents: 40));

    expect(engine.lastDriftEvent, isNotNull);
    expect(engine.lastDriftEvent!.beforeMidi, 69);
    expect(engine.lastDriftEvent!.afterCents, 40);
  });
}
