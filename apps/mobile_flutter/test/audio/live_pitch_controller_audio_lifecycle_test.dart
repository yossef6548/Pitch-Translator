import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pitch_translator/application/live_session/live_session_coordinator.dart';
import 'package:pitch_translator/audio/native_audio_bridge.dart';
import 'package:pitch_translator/domain/exercises/exercise_catalog.dart';
import 'package:pitch_translator/presentation/live_pitch/live_pitch_controller.dart';
import 'package:pt_contracts/pt_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('no method channel start invoked when screen loads', () async {
    const frameChannel = EventChannel('pt/audio/frames/controller_init_test');
    const controlChannel = MethodChannel('pt/audio/control/controller_init_test');

    var startCallCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(controlChannel, (call) async {
          if (call.method == 'start') {
            startCallCount += 1;
          }
          return null;
        });

    final exercise = ExerciseCatalog.byId('PF_1');
    final coordinator = LiveSessionCoordinator(
      exercise: exercise,
      level: LevelId.l1,
      config: const ExerciseConfig(),
      bridge: NativeAudioBridge(
        frameChannel: frameChannel,
        controlChannel: controlChannel,
      ),
    );

    final controller = LivePitchController(
      exercise: exercise,
      level: LevelId.l1,
      config: const ExerciseConfig(),
      coordinator: coordinator,
    );

    await controller.init();

    expect(startCallCount, 0);

    controller.dispose();
  });
}
