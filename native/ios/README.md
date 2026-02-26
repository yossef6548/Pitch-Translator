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


## Validation progress in this pass

- Re-ran Flutter deterministic QA and full widget/unit suite successfully to confirm bridge-contract behavior remained stable from the Dart side.
- Re-ran DSP smoke build/tests to confirm C++ contract buildability.
- Confirmed no native implementation delta was introduced; checklist items below remain the exact app-store release blockers for native binaries.

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


## Progress update (current engineering pass)

### Completed in this pass

- [x] Hardened Flutter/native payload contract parsing in `NativeAudioBridge` so channel payload keys must exactly match `DspFrame.fromJson` expectations.
- [x] Added no-pitch normalization at bridge boundary (`NaN`/invalid numeric values are coerced to `null`; confidence is clamped to `[0,1]`).
- [x] Upgraded C++ DSP core from simple autocorrelation scaffold toward a YIN-style CMNDF estimator with sub-sample lag refinement and stability-weighted confidence.
- [x] Added regression coverage for payload-schema enforcement and no-pitch normalization in Flutter tests.

### Still blocked for ship gate (requires native platform code in this repo)

- [ ] Implement iOS microphone capture callback path and wire real mic PCM into `pt_dsp_process`.
- [ ] Emit native `EventChannel` frames from platform code and verify release-mode behavior on physical devices.
- [ ] Complete interruption/route/lifecycle recovery matrix with 30+ minute burn-in runs.
- [ ] Capture and document latency and XRuns measurements against median/P95 release targets.

### Release note

This repository now has stronger cross-layer contracts and DSP behavior, but it is **not app-store ship-ready** until the unchecked native platform implementation tasks above are completed and validated on-device.
