import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pt_contracts/pt_contracts.dart';

/// Audio bridge that prefers native EventChannel streaming and falls back to a
/// deterministic simulator when native integration is unavailable.
class NativeAudioBridge {
  NativeAudioBridge({
    EventChannel? frameChannel,
    MethodChannel? controlChannel,
    bool? enableSimulationFallback,
  }) : _frameChannel =
           frameChannel ?? const EventChannel(_defaultFrameChannelName),
       _controlChannel =
           controlChannel ?? const MethodChannel(_defaultControlChannelName),
       enableSimulationFallback = enableSimulationFallback ?? !kReleaseMode;

  static const String _defaultFrameChannelName = 'pt/audio/frames';
  static const String _defaultControlChannelName = 'pt/audio/control';

  final EventChannel _frameChannel;
  final MethodChannel _controlChannel;

  /// In release builds the default is false so production binaries fail fast if
  /// native streaming is missing. Debug/profile builds default to true for QA.
  final bool enableSimulationFallback;

  Stream<DspFrame>? _cachedStream;
  StreamSubscription<DspFrame>? _cachedSubscription;

  Stream<DspFrame> frames() {
    if (_cachedStream == null) {
      final controller = StreamController<DspFrame>.broadcast();
      _cachedSubscription = _createFrameStream().listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      _cachedStream = controller.stream;
    }
    return _cachedStream!;
  }

  Future<void> dispose() async {
    await _cachedSubscription?.cancel();
    _cachedSubscription = null;
    _cachedStream = null;
  }

  Future<void> start() async {
    try {
      await _controlChannel.invokeMethod<void>('start');
    } on MissingPluginException {
      if (!enableSimulationFallback) {
        rethrow;
      }
    }
  }

  Future<void> stop() async {
    try {
      await _controlChannel.invokeMethod<void>('stop');
    } on MissingPluginException {
      if (!enableSimulationFallback) {
        rethrow;
      }
    }
  }

  Stream<DspFrame> _createFrameStream() async* {
    if (enableSimulationFallback) {
      try {
        await _controlChannel.invokeMethod<void>('start');
        yield* _nativeFrameStream();
      } on MissingPluginException {
        yield* _simulatedFrames();
      }
      return;
    }

    await _controlChannel.invokeMethod<void>('start');
    yield* _nativeFrameStream();
  }

  Stream<DspFrame> _nativeFrameStream() {
    // No initialization parameters are required by the native audio frame stream.
    return _frameChannel
        .receiveBroadcastStream(null)
        .map((dynamic event) => _frameFromEvent(event));
  }

  DspFrame _frameFromEvent(dynamic event) {
    if (event is! Map) {
      throw FormatException(
        'Native audio frame must be a JSON map payload, received: ${event.runtimeType}',
      );
    }

    final normalized = <String, dynamic>{
      for (final entry in event.entries) entry.key.toString(): entry.value,
    };

    const expectedKeys = {
      'timestamp_ms',
      'freq_hz',
      'midi_float',
      'nearest_midi',
      'cents_error',
      'confidence',
      'vibrato',
    };
    if (normalized.keys.length != expectedKeys.length ||
        !normalized.keys.every(expectedKeys.contains)) {
      throw FormatException(
        'Invalid native audio frame payload keys. Expected '
        '${expectedKeys.toList()} but received ${normalized.keys.toList()}.',
      );
    }

    normalized['freq_hz'] = _finiteOrNull(normalized['freq_hz']);
    normalized['midi_float'] = _finiteOrNull(normalized['midi_float']);
    normalized['cents_error'] = _finiteOrNull(normalized['cents_error']);
    normalized['confidence'] = _finiteOrZero(normalized['confidence']);

    final nearestMidi = normalized['nearest_midi'];
    if (nearestMidi is int && nearestMidi < 0) {
      normalized['nearest_midi'] = null;
    }

    final vibrato = normalized['vibrato'];
    if (vibrato is Map) {
      final v = <String, dynamic>{
        for (final entry in vibrato.entries) entry.key.toString(): entry.value,
      };
      v['rate_hz'] = _finiteOrNull(v['rate_hz']);
      v['depth_cents'] = _finiteOrNull(v['depth_cents']);

      final detectedRaw = v['detected'];
      if (detectedRaw is bool) {
        // already valid
      } else if (detectedRaw == null) {
        v['detected'] = false;
      } else if (detectedRaw is num) {
        v['detected'] = detectedRaw != 0;
      } else if (detectedRaw is String) {
        final lower = detectedRaw.toLowerCase();
        v['detected'] = lower == 'true' || lower == '1';
      } else {
        v['detected'] = false;
      }
      normalized['vibrato'] = v;
    }

    try {
      return DspFrame.fromJson(normalized);
    } on FormatException catch (e) {
      // Provide more helpful context if the payload schema is invalid or keys are unexpected.
      throw FormatException(
        'Invalid native audio frame payload. Received keys: '
        '${normalized.keys.toList()} (${e.message})',
      );
    }
  }

  double? _finiteOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final d = value.toDouble();
      return d.isFinite ? d : null;
    }
    return null;
  }

  double _finiteOrZero(dynamic value) {
    if (value is num) {
      final d = value.toDouble();
      if (d.isFinite) return d.clamp(0.0, 1.0);
    }
    return 0.0;
  }

  Stream<DspFrame> _simulatedFrames() {
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
}
