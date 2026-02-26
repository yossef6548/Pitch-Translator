# iOS Native Audio Plugin (Implemented)

This directory now contains concrete iOS plugin source for native microphone capture + DSP dispatch:

- `Sources/PitchTranslatorAudioPlugin.swift`
- `Sources/PitchTranslatorDSPBridge.h`
- `Sources/PitchTranslatorDSPBridge.mm`

## Implemented behavior

- `MethodChannel("pt/audio/control")`: `start`, `stop`
- `EventChannel("pt/audio/frames")`: emits **exact Flutter contract keys only**:
  - `timestamp_ms`, `freq_hz`, `midi_float`, `nearest_midi`, `cents_error`, `confidence`, `vibrato`
  - `vibrato`: `detected`, `rate_hz`, `depth_cents`
- `AVAudioSession` configured for low-latency mic input (`playAndRecord` + `measurement`).
- `AVAudioEngine` input tap forwards float PCM frames directly into `pt_dsp_process` through Objective-C++ bridge.
- No-pitch cleanup done natively (`NaN` → `null`, `nearest_midi < 0` → `null`, confidence clamped `[0..1]`).
- Interruption and route-change recovery hooks implemented.
- Foreground recovery hook implemented.

## Integration notes

- Add these files into the app's iOS runner/plugin target.
- Ensure bridging header/module map exposes `PitchTranslatorDSPBridge.h` to Swift.
- Link DSP sources (`dsp/include`, `dsp/src`) into the iOS build target.

## Remaining ship-gate validation (device required)

Still required before App Store release:

- Physical-device 30+ minute session with xrun/dropout instrumentation.
- Mic→UI latency measurement: median ≤ 30ms, P95 ≤ 50ms.
- Call interruption + Bluetooth route churn matrix verification on at least 2 device classes.
