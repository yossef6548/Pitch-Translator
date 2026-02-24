import 'dart:async';
import 'dart:math';

import 'package:pt_contracts/pt_contracts.dart';

/// Deterministic simulated audio bridge for development and QA replay.
class NativeAudioBridge {
  Stream<DspFrame> frames() {
    const period = Duration(milliseconds: 50);
    var tMs = 0;
    return Stream.periodic(period, (_) {
      tMs += 50;
      final phase = tMs / 1000.0;

      if (tMs < 1200) {
        return DspFrame(
          timestampMs: tMs,
          freqHz: 440,
          midiFloat: 69,
          nearestMidi: 69,
          centsError: 5 * sin(phase * 2),
          confidence: 0.9,
          vibrato: const VibratoInfo(detected: false),
        );
      }

      if (tMs < 1600) {
        return DspFrame(
          timestampMs: tMs,
          freqHz: 440,
          midiFloat: 69,
          nearestMidi: 69,
          centsError: 38,
          confidence: 0.9,
          vibrato: const VibratoInfo(detected: false),
        );
      }

      if (tMs < 2100) {
        return DspFrame(
          timestampMs: tMs,
          freqHz: null,
          midiFloat: null,
          nearestMidi: null,
          centsError: null,
          confidence: 0.55,
          vibrato: const VibratoInfo(detected: false),
        );
      }

      return DspFrame(
        timestampMs: tMs,
        freqHz: 440,
        midiFloat: 69,
        nearestMidi: 69,
        centsError: 12 * sin(phase * 3),
        confidence: 0.85,
        vibrato: const VibratoInfo(detected: true, rateHz: 5.5, depthCents: 18),
      );
    });
  }

  Future<void> start() async {}

  Future<void> stop() async {}
}
