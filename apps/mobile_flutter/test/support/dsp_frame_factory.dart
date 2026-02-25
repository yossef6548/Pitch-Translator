import 'package:pt_contracts/pt_contracts.dart';

DspFrame dspFrame(
  int timestampMs, {
  double? cents = 0,
  double confidence = 0.9,
  bool vibratoDetected = false,
  double? vibratoRateHz,
  double? vibratoDepthCents,
  int? nearestMidi,
}) {
  final hasPitch = cents != null;
  return DspFrame(
    timestampMs: timestampMs,
    freqHz: hasPitch ? 440 : null,
    midiFloat: hasPitch ? 69 : null,
    nearestMidi: hasPitch ? (nearestMidi ?? 69) : null,
    centsError: cents,
    confidence: confidence,
    vibrato: VibratoInfo(
      detected: vibratoDetected,
      rateHz: vibratoRateHz,
      depthCents: vibratoDepthCents,
    ),
  );
}
