# Android Native Audio Plugin (Implemented)

This directory now contains concrete Android plugin source for native microphone capture + DSP dispatch:

- `src/main/kotlin/com/pitchtranslator/audio/PitchTranslatorAudioPlugin.kt`
- `src/main/kotlin/com/pitchtranslator/audio/NativeAaudioEngine.kt`
- `src/main/kotlin/com/pitchtranslator/audio/AppLifecycle.kt`
- `src/main/cpp/pt_audio_engine.cpp`
- `src/main/cpp/CMakeLists.txt`

## Implemented behavior

- `MethodChannel("pt/audio/control")`: `start`, `stop`
- `EventChannel("pt/audio/frames")`: emits **exact Flutter contract keys only**:
  - `timestamp_ms`, `freq_hz`, `midi_float`, `nearest_midi`, `cents_error`, `confidence`, `vibrato`
  - `vibrato`: `detected`, `rate_hz`, `depth_cents`
- Low-latency input path via `AAudio` callback in native C++ (`AAUDIO_PERFORMANCE_MODE_LOW_LATENCY`).
- PCM callback invokes `pt_dsp_process` directly in callback path.
- JNI callback publishes normalized payload map to Flutter.
- Audio focus handling (loss -> stop; resume path support).
- Route change callback (device add/remove -> stream restart).
- Activity pause/resume lifecycle stop/restart behavior.

## Integration notes

- Hook Kotlin sources into the Android Flutter plugin/app module.
- Wire `externalNativeBuild` to `src/main/cpp/CMakeLists.txt`.
- Ensure DSP headers/sources from `/dsp` are visible to the CMake target.

## Remaining ship-gate validation (device required)

Still required before Play Store release:

- 30+ minute burn-in on target devices with xrun/dropout counters.
- Mic→UI latency measurement: median ≤ 30ms, P95 ≤ 50ms.
- Phone call interruption + Bluetooth connect/disconnect validation matrix.
