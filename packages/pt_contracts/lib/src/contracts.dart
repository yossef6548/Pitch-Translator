import 'package:meta/meta.dart';

@immutable
class VibratoInfo {
  final bool detected;
  final double? rateHz;
  final double? depthCents;
  const VibratoInfo({required this.detected, this.rateHz, this.depthCents});
}

@immutable
class DspFrame {
  final int timestampMs;
  final double? freqHz;
  final double? midiFloat;
  final int? nearestMidi;
  final double? centsError;
  final double confidence;
  final VibratoInfo vibrato;

  const DspFrame({
    required this.timestampMs,
    required this.freqHz,
    required this.midiFloat,
    required this.nearestMidi,
    required this.centsError,
    required this.confidence,
    required this.vibrato,
  });

  // TODO: add deterministic serialization (json/binary) matching QA harness.
}
