import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/training/dsp_ui_binder.dart';
import 'package:pt_contracts/pt_contracts.dart';

import '../support/dsp_frame_factory.dart';

void main() {
  test('x offset uses provided layout width W', () {
    const w = 240.0;
    final binding = bindDspToUi(
      frame: dspFrame(0, cents: 50),
      effectiveError: 50,
      state: LivePitchStateId.seekingLock,
      config: const ExerciseConfig(countdownMs: 0),
      semitoneWidthPxW: w,
    );

    expect(binding.xOffsetPx, closeTo(0.5 * w, 0.0001));
  });

  test('binder converts cents error to pixel offset', () {
    final positive = bindDspToUi(
      frame: dspFrame(0, cents: 50),
      effectiveError: 50,
      state: LivePitchStateId.seekingLock,
      config: const ExerciseConfig(),
      semitoneWidthPxW: 200,
    );

    final negative = bindDspToUi(
      frame: dspFrame(0, cents: -50),
      effectiveError: -50,
      state: LivePitchStateId.seekingLock,
      config: const ExerciseConfig(),
      semitoneWidthPxW: 200,
    );

    expect(positive.xOffsetPx, 100);
    expect(negative.xOffsetPx, -100);
  });

  test('low confidence state suppresses readout', () {
    final binding = bindDspToUi(
      frame: dspFrame(0, cents: null, confidence: 0.8),
      effectiveError: null,
      state: LivePitchStateId.lowConfidence,
      config: const ExerciseConfig(countdownMs: 0),
      semitoneWidthPxW: 200,
    );

    expect(binding.errorReadoutVisible, isFalse);
    expect(binding.displayCents, '—');
  });
}
