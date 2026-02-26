import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/audio/native_audio_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeAudioBridge', () {
    test('defaults simulation fallback on for test/debug mode', () {
      final bridge = NativeAudioBridge();

      expect(bridge.enableSimulationFallback, isTrue);
    });

    test('falls back to deterministic simulation when plugins are missing', () async {
      final bridge = NativeAudioBridge(enableSimulationFallback: true);

      await bridge.start();
      final first = await bridge.frames().first;

      expect(first.timestampMs, greaterThan(0));
      expect(first.confidence, greaterThan(0));

      await bridge.dispose();
    });

    test('throws when fallback disabled and native plugin is unavailable', () async {
      final bridge = NativeAudioBridge(enableSimulationFallback: false);

      await expectLater(
        bridge.start(),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('frames throws when fallback disabled and native plugin is unavailable', () async {
      final bridge = NativeAudioBridge(enableSimulationFallback: false);

      await expectLater(
        bridge.frames().first,
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('_frameFromEvent rejects non-Map payloads with descriptive error', () {
      // Use a bridge with a mock EventChannel that emits a non-Map event.
      const channel = EventChannel('pt/audio/frames/test');

      // Set up a fake handler that sends a String (invalid payload).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        channel,
        _StringEventHandler('not-a-map'),
      );

      final bridge = NativeAudioBridge(
        frameChannel: channel,
        enableSimulationFallback: false,
      );

      expectLater(
        bridge.frames().first,
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('String'),
          ),
        ),
      );
    });
  });
}

/// A mock stream handler that emits a single event of the given value then closes.
class _StringEventHandler implements MockStreamHandler {
  _StringEventHandler(this._event);

  final Object _event;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    events.success(_event);
    events.endOfStream();
  }

  @override
  void onCancel(Object? arguments) {}
}
