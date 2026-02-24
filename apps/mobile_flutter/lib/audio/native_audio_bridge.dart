import 'dart:async';
import 'package:flutter/services.dart';
import 'package:pt_contracts/pt_contracts.dart';

/// Native audio bridge placeholder:
/// - Starts mic capture
/// - Plays references
/// - Streams DSP frames to Flutter
class NativeAudioBridge {
  static const MethodChannel _channel = MethodChannel('pitch_translator/native_audio');

  Stream<DspFrame> frames() {
    // TODO: use EventChannel to receive JSON/binary-encoded frames
    return const Stream.empty();
  }

  Future<void> start() async {
    // TODO: start native audio + DSP
    await _channel.invokeMethod('start');
  }

  Future<void> stop() async {
    await _channel.invokeMethod('stop');
  }
}
