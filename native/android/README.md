# Android Native Audio Plugin

This module provides the Android side of the Flutter native audio bridge and now includes:

- Kotlin plugin implementation (`PitchTranslatorAudioPlugin`, `NativeAaudioEngine`, lifecycle hooks)
- Native AAudio + DSP bridge (`src/main/cpp/pt_audio_engine.cpp`)
- CMake wiring to compile shared DSP sources (`src/main/cpp/CMakeLists.txt`)
- Android manifest permission declaration (`src/main/AndroidManifest.xml`)
- Library Gradle template (`build.gradle.kts`) for host integration

## Contract compliance

Frames emitted to Flutter use the strict map shape expected by `DspFrame.fromJson`:

- Top-level keys: `timestamp_ms`, `freq_hz`, `midi_float`, `nearest_midi`, `cents_error`, `confidence`, `vibrato`
- Vibrato keys: `detected`, `rate_hz`, `depth_cents`
- JNI bridge sanitizes/clamps all DSP scalars (finite checks + confidence clamp + no-pitch normalization) before Kotlin/Dart map emission.
- No-pitch frames emit nullables directly (`freq_hz`, `midi_float`, `nearest_midi`, `cents_error`, vibrato rate/depth) with confidence clamped to `[0,1]` natively.

## Realtime safety model

- AAudio callback performs DSP processing and pushes frames into a lock-free single-producer/single-consumer ring.
- JNI → Flutter map emission is done on a background emitter thread (not from the realtime callback).
- Ring buffer overflow now increments a dropped-frame counter and logs periodically to aid on-device diagnostics.
- This removes JVM attach and Flutter channel calls from callback context.

## Permission + lifecycle behavior

- Declares `android.permission.RECORD_AUDIO` in manifest.
- Requests runtime `RECORD_AUDIO` permission on `start` when needed.
- Start/stop are idempotent.
- On pause/focus loss: capture stops and remembers restart intent.
- On resume/route-change (device add/remove): capture restarts only when previously active and permission still granted.
- Device route change restarts are debounced (~300ms) to prevent restart storms during churn.
- Audio focus-loss handling now guards against focus/start-stop loops by separating focus-driven and manual stop flows.

## Host-app integration checklist (required before shipping)

1. Add this module as a plugin/library dependency from the Flutter Android host app.
2. Ensure `externalNativeBuild.cmake.path` points to `native/android/src/main/cpp/CMakeLists.txt`.
3. Confirm `AndroidManifest.xml` merge contains `RECORD_AUDIO` (`android.permission.RECORD_AUDIO` is declared in this module manifest).
4. Verify permission prompt + denial handling in app UX, and ensure the in-app disclosure states microphone use is required for live pitch detection.
5. Validate phone-call interruption, Bluetooth connect/disconnect, wired headset plug/unplug, and background/foreground transitions on physical devices.

## Remaining release blockers (device-only)

- 30+ minute continuous capture on representative hardware.
- Mic→UI latency measurement with median ≤30ms, P95 ≤50ms.
- Full interruption and route churn matrix sign-off.

## CI integration

Android quality gates are automated in `.github/workflows/ci.yml`:

1. Configure/build native bridge via CMake (`native/android/src/main/cpp`).
2. Build Flutter debug APK from `apps/mobile_flutter`.

This ensures native bridge sources continue compiling and the app can assemble in CI before merge.


## Emulator verification notes

This repository can be built/tested for Android in CI, but running the Flutter app on an emulator additionally requires a local Android SDK + AVD image.

Minimum commands (Linux example):

```bash
# after installing Android cmdline-tools and setting ANDROID_SDK_ROOT
sdkmanager --licenses
sdkmanager "platform-tools" "platforms;android-35" "system-images;android-35;google_apis;x86_64"
avdmanager create avd -n pt_api35 -k "system-images;android-35;google_apis;x86_64"
emulator -avd pt_api35 -no-audio -no-snapshot

cd apps/mobile_flutter
flutter run -d emulator-5554
```

If `flutter emulators` reports no sources or `flutter doctor` reports missing Android SDK, install/provision the SDK first, then re-run.
