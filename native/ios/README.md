# iOS Native Audio Integration Plan

Status: **Scaffold only (not yet implemented)**

## Target stack

- `AVAudioSession` category: `playAndRecord`
- `AVAudioSession` mode: `measurement`
- `AVAudioEngine` input tap for mic capture
- C++ DSP invocation through C ABI (`dsp/include/pt_dsp/dsp_api.h`)
- Flutter bridge via `EventChannel` for `DspFrame` output

## Implementation checklist

- [ ] Configure and activate `AVAudioSession` with low-latency preferences.
- [ ] Build deterministic PCM frame bufferer (fixed frame size, no dynamic alloc in callback).
- [ ] Call DSP C ABI per frame from audio callback context.
- [ ] Marshal DSP frame output into Flutter contract shape.
- [ ] Stream frame events over `EventChannel` with backpressure protection.
- [ ] Handle interruptions/routes:
  - [ ] incoming call interruption
  - [ ] headset plug/unplug
  - [ ] Bluetooth route handoff
- [ ] Add telemetry for mic→UI end-to-end latency sampling.
- [ ] Add integration tests for route interruption + recovery.

## Acceptance criteria before release

- Stable continuous capture for 30+ minute sessions.
- Mic→UI latency median ≤ 30 ms and P95 ≤ 50 ms on target devices.
- No callback overruns/XRuns in release build under normal use.
- Frame contract parity with Android implementation.
