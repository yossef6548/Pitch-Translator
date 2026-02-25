import 'dart:math' as math;

import 'package:pt_contracts/pt_contracts.dart';

DspFrame dspFrame(
  int timestampMs, {
  double? cents = 0,
  double confidence = 0.9,
  bool vibratoDetected = false,
  double? vibratoRateHz,
  double? vibratoDepthCents,
  int nearestMidi = 69,
}) {
  final hasPitch = cents != null;
  final double? midiFloat = hasPitch ? nearestMidi + cents / 100.0 : null;
  final double? freqHz = midiFloat != null
      ? 440.0 * math.pow(2.0, (midiFloat - 69.0) / 12.0)
      : null;
  return DspFrame(
    timestampMs: timestampMs,
    freqHz: freqHz,
    midiFloat: midiFloat,
    nearestMidi: hasPitch ? nearestMidi : null,
    centsError: cents,
    confidence: confidence,
    vibrato: VibratoInfo(
      detected: vibratoDetected,
      rateHz: vibratoRateHz,
      depthCents: vibratoDepthCents,
    ),
  );
}
