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
- No-pitch frames emit nullables directly (`freq_hz`, `midi_float`, `nearest_midi`, `cents_error`, vibrato rate/depth) and clamp confidence to `[0,1]` natively.

## Realtime safety model

- AAudio callback performs DSP processing and pushes frames into a lock-free single-producer/single-consumer ring.
- JNI → Flutter map emission is done on a background emitter thread (not from the realtime callback).
- This removes JVM attach and Flutter channel calls from callback context.

## Permission + lifecycle behavior

- Declares `android.permission.RECORD_AUDIO` in manifest.
- Requests runtime `RECORD_AUDIO` permission on `start` when needed.
- Start/stop are idempotent.
- On pause/focus loss: capture stops and remembers restart intent.
- On resume/route-change (device add/remove): capture restarts only when previously active and permission still granted.

## Host-app integration checklist (required before shipping)

1. Add this module as a plugin/library dependency from the Flutter Android host app.
2. Ensure `externalNativeBuild.cmake.path` points to `native/android/src/main/cpp/CMakeLists.txt`.
3. Confirm `AndroidManifest.xml` merge contains `RECORD_AUDIO`.
4. Verify permission prompt + denial handling in app UX.
5. Validate phone-call interruption, Bluetooth connect/disconnect, wired headset plug/unplug, and background/foreground transitions on physical devices.

## Remaining release blockers (device-only)

- 30+ minute continuous capture on representative hardware.
- Mic→UI latency measurement with median ≤30ms, P95 ≤50ms.
- Full interruption and route churn matrix sign-off.
