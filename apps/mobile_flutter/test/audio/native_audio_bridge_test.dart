import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/audio/native_audio_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeAudioBridge', () {
    test('falls back to deterministic simulation when plugins are missing', () async {
      final bridge = NativeAudioBridge(enableSimulationFallback: true);

      await bridge.start();
      final first = await bridge.frames().first;

      expect(first.timestampMs, greaterThan(0));
      expect(first.confidence, greaterThan(0));
    });

    test('throws when fallback disabled and native plugin is unavailable', () async {
      final bridge = NativeAudioBridge(enableSimulationFallback: false);

      expect(bridge.start(), throwsA(isA<MissingPluginException>()));
    });
  });
}
