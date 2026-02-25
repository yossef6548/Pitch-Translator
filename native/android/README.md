# Android Native Audio Integration Plan

Status: **Native implementation pending; Flutter channel bridge contract is implemented**


## Current integration baseline (completed in Flutter layer)

- `apps/mobile_flutter/lib/audio/native_audio_bridge.dart` now defines production channel names:
  - frame stream: `pt/audio/frames`
  - control methods: `pt/audio/control` (`start`, `stop`)
- If native plugins are unavailable, bridge falls back to deterministic simulated frames for dev/QA continuity.
- `apps/mobile_flutter/test/audio/native_audio_bridge_test.dart` validates fallback and strict-mode failure behavior.

## Target stack

- Primary input/output path: `AAudio`
- Fallback abstraction: `Oboe` where required by device behavior
- C++ DSP invocation through C ABI (`dsp/include/pt_dsp/dsp_api.h`)
- Flutter bridge via `EventChannel` for `DspFrame` output

## Implementation checklist

- [ ] Create low-latency `AAudio` input stream with negotiated hardware sample rate.
- [ ] Add output stream path for reference tones/metronome cues.
- [ ] Implement fixed-size frame buffering from callback thread.
- [ ] Invoke DSP C ABI in callback-safe manner (no locks/allocations on hot path).
- [ ] Publish deterministic frame payloads to Flutter `EventChannel`.
- [ ] Handle Android lifecycle and focus changes:
  - [ ] audio focus loss/transient ducking
  - [ ] route change (wired/Bluetooth)
  - [ ] app background/foreground
- [ ] Add latency and stream health telemetry (XRuns, callback duration).
- [ ] Add integration tests for focus loss + route interruption.

## Acceptance criteria before release

- Stable capture across supported API levels/devices.
- Mic→UI latency median ≤ 30 ms and P95 ≤ 50 ms on target devices.
- No sustained callback underruns in normal operation.
- Frame contract parity with iOS implementation.
