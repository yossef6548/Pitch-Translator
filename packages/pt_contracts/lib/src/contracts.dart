import 'package:meta/meta.dart';

@immutable
class VibratoInfo {
  final bool detected;
  final double? rateHz;
  final double? depthCents;

  const VibratoInfo({required this.detected, this.rateHz, this.depthCents});

  bool get isQualified =>
      detected &&
      rateHz != null &&
      depthCents != null &&
      rateHz!.isFinite &&
      depthCents!.isFinite;

  factory VibratoInfo.fromJson(Map<String, dynamic> json) {
    return VibratoInfo(
      detected: json['detected'] as bool? ?? false,
      rateHz: (json['rate_hz'] as num?)?.toDouble(),
      depthCents: (json['depth_cents'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'detected': detected,
        'rate_hz': rateHz,
        'depth_cents': depthCents,
      };
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

  bool get hasUsablePitch =>
      freqHz != null && centsError != null && nearestMidi != null;

  factory DspFrame.fromJson(Map<String, dynamic> json) {
    return DspFrame(
      timestampMs: json['timestamp_ms'] as int,
      freqHz: (json['freq_hz'] as num?)?.toDouble(),
      midiFloat: (json['midi_float'] as num?)?.toDouble(),
      nearestMidi: json['nearest_midi'] as int?,
      centsError: (json['cents_error'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
      vibrato: VibratoInfo.fromJson(json['vibrato'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp_ms': timestampMs,
        'freq_hz': freqHz,
        'midi_float': midiFloat,
        'nearest_midi': nearestMidi,
        'cents_error': centsError,
        'confidence': confidence,
        'vibrato': vibrato.toJson(),
      };
}
