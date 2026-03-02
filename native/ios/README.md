# iOS Native Audio Plugin

This module provides the iOS side of the Flutter native audio bridge and now includes:

- Swift plugin implementation (`Sources/PitchTranslatorAudioPlugin.swift`)
- Objective-C++ DSP bridge (`Sources/PitchTranslatorDSPBridge.h/.mm`)
- Podspec template wiring DSP C++ sources into iOS builds (`PitchTranslatorAudioPlugin.podspec`)

## Contract compliance

Frames emitted to Flutter use the strict map shape expected by `DspFrame.fromJson`:

- Top-level keys: `timestamp_ms`, `freq_hz`, `midi_float`, `nearest_midi`, `cents_error`, `confidence`, `vibrato`
- Vibrato keys: `detected`, `rate_hz`, `depth_cents`
- No-pitch values are emitted natively as null-compatible values (`NSNull`) with confidence clamped to `[0,1]`.

## Permission + lifecycle behavior

- `start` now requests microphone permission through `AVAudioSession.requestRecordPermission` when needed.
- Start/stop are idempotent.
- Interruption begin stops capture and records resume intent.
- Interruption end, route changes, and foreground transitions only restart when capture was previously active.

## Host-app integration checklist (required before shipping)

1. Integrate this plugin into the Flutter iOS host target (CocoaPods via provided podspec or equivalent SPM packaging).
2. Ensure DSP headers/sources from `dsp/include` and `dsp/src` are linked into the target.
3. Add microphone usage description key(s) in the runner `Info.plist`:
   - `NSMicrophoneUsageDescription`
4. Validate permission prompt/denial UX and all lifecycle transitions on physical devices.

## Remaining release blockers (device-only)

- 30+ minute continuous capture on representative iOS hardware.
- Mic→UI latency measurement with median ≤30ms, P95 ≤50ms.
- Phone call interruption, Bluetooth route change, wired headset routing, and background/foreground matrix sign-off.
