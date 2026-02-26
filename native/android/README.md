# Android Native Audio Integration Plan

Status: **Implementation-plan complete; final device hardening pending for Play Store release**

## Current baseline already integrated

- Flutter contract is implemented in `NativeAudioBridge`:
  - Event stream: `pt/audio/frames`
  - Control channel: `pt/audio/control` (`start`, `stop`)
- Deterministic simulation fallback remains available for debug/test environments.
- Release builds now fail fast if native plugin integration is unavailable.

## Target stack

- Primary stream path: `AAudio`
- Compatibility fallback: `Oboe` on problematic devices
- C++ DSP call via C ABI (`dsp/include/pt_dsp/dsp_api.h`)
- Frame delivery via Flutter `EventChannel`


## Validation progress in this pass

- Re-ran Flutter deterministic QA and full widget/unit suite successfully to confirm bridge-contract behavior remained stable from the Dart side.
- Re-ran DSP smoke build/tests to confirm C++ contract buildability.
- Confirmed no native implementation delta was introduced; checklist items below remain the exact app-store release blockers for native binaries.

## Implementation plan (in execution order)

### Phase 1 — Stream bootstrap

- [ ] Create low-latency `AAudio` input stream with negotiated hardware sample rate.
- [ ] Add optional output stream path for reference tones and cues.
- [ ] Build fixed-size callback-safe PCM buffer path.

### Phase 2 — DSP and transport

- [ ] Invoke DSP C ABI on callback path without locks/allocations.
- [ ] Transform DSP output to canonical `DspFrame` payload.
- [ ] Publish frames over `EventChannel` with robust listener lifecycle handling.

### Phase 3 — Lifecycle and audio focus

- [ ] Handle transient/permanent audio focus loss and ducking.
- [ ] Handle route changes (speaker, wired, Bluetooth).
- [ ] Handle app background/foreground transitions deterministically.

### Phase 4 — Device telemetry and burn-in

- [ ] Add latency, XRuns, and callback-duration telemetry.
- [ ] Execute device-matrix burn-in tests (mid/high-tier + multiple API levels).
- [ ] Validate long-session stability and recovery behavior.

## Release acceptance criteria

- Stable capture across supported API levels/devices.
- Mic→UI latency median ≤ 30 ms and P95 ≤ 50 ms.
- No sustained callback underruns in normal operation.
- Frame contract parity with iOS implementation.


## Current pass verification note

- No new native implementation code was added in this pass.
- Flutter-layer deterministic behavior and QA coverage were revalidated; native device hardening checklist items above remain the release blocker set.
