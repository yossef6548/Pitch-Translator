# iOS Native Audio Integration Plan

Status: **Implementation-plan complete; final device hardening pending for app-store release**

## Current baseline already integrated

- Flutter contract is implemented in `NativeAudioBridge`:
  - Event stream: `pt/audio/frames`
  - Control channel: `pt/audio/control` (`start`, `stop`)
- Debug/test fallback remains available for deterministic QA.
- Release builds now fail fast if native plugin wiring is missing (no silent simulation fallback).

## Target stack

- `AVAudioSession` category: `playAndRecord`
- `AVAudioSession` mode: `measurement`
- `AVAudioEngine` input tap for mic capture
- C++ DSP call through C ABI (`dsp/include/pt_dsp/dsp_api.h`)
- Frame publishing over Flutter `EventChannel`

## Implementation plan (in execution order)

### Phase 1 — Session and stream setup

- [ ] Configure and activate `AVAudioSession` with low-latency preferences.
- [ ] Select preferred sample rate and IO buffer duration for target devices.
- [ ] Initialize `AVAudioEngine` graph and deterministic fixed-size frame ring buffer.

### Phase 2 — DSP pipeline

- [ ] Invoke DSP C ABI from audio callback path without heap allocation on hot path.
- [ ] Normalize output into Flutter `DspFrame` schema.
- [ ] Stream frames via `EventChannel` with listener lifecycle safety.

### Phase 3 — Interruption/resilience

- [ ] Handle incoming-call interruptions.
- [ ] Handle route changes (built-in, wired headset, Bluetooth).
- [ ] Recover capture deterministically after interruption end.

### Phase 4 — Telemetry and validation

- [ ] Add mic→UI latency sampling metrics.
- [ ] Capture callback timing / overrun diagnostics.
- [ ] Run 30+ minute stress sessions on physical devices.

## Release acceptance criteria

- Stable continuous capture for 30+ minute sessions.
- Mic→UI latency median ≤ 30 ms and P95 ≤ 50 ms.
- No callback overruns/XRuns in release builds under normal use.
- Frame contract parity with Android implementation.


## Current pass verification note

- No new native implementation code was added in this pass.
- Flutter-layer deterministic behavior and QA coverage were revalidated; native device hardening checklist items above remain the release blocker set.
