# Pitch Translator

Pitch Translator is a mobile-first training system that maps real-time pitch to deterministic visual and numeric feedback, detects drift, and trains recovery.

This repository is a monorepo containing Flutter UI/state logic, shared contracts, C++ DSP, native bridge scaffolding, and QA trace assets.

---

## Current implementation status

### ✅ Implemented now

- **Monorepo layout + module boundaries**
  - Flutter app in `apps/mobile_flutter`
  - Shared Dart contracts in `packages/pt_contracts`
  - C++ DSP core in `dsp`
  - Native platform scaffolding in `native/ios` and `native/android`
  - QA traces/docs in `qa` and `specs`

- **Spec-aligned shared contracts/constants (Dart)**
  - `DspFrame`, `VibratoInfo`, serialization helpers
  - Live pitch state IDs and deterministic visual fields
  - Core constants synced to `specs/dsp-ui-binding.md`

- **Training Engine (first production-capable core)**
  - Implemented state machine:
    - `IDLE → COUNTDOWN → SEEKING_LOCK → LOCKED → DRIFT_CANDIDATE → DRIFT_CONFIRMED`
    - `ANY → LOW_CONFIDENCE` override
    - `PAUSED`, `COMPLETED`
  - Vibrato-aware effective error windowing
  - Deterministic visual math outputs (`E`, `D`, x-offset, saturation, halo)

- **LIVE_PITCH app scaffold**
  - Functional screen wiring to training engine
  - Target header, pitch line, shape/halo, cents readout, controls
  - Deterministic simulated frame stream for local iteration

- **C++ DSP baseline implementation**
  - Autocorrelation-based pitch estimate
  - MIDI / nearest MIDI / cents error computation
  - Confidence estimate
  - Basic vibrato heuristic outputs

- **Tests available in repo**
  - DSP smoke test for synthetic 440Hz signal
  - Flutter unit tests for core engine transitions

---

## 🚧 What’s still left before true “ship to users”

This section is intentionally explicit so the next developer can finish without reverse-engineering intent.

### 1) Native real-time audio I/O (required for shipping)

**What is missing**
- Flutter currently uses a simulated frame source, not real microphone audio.
- No production bridge for low-latency capture/playback and DSP feeding yet.

**How it must be done**
- **iOS (`native/ios`)**
  - Implement AVAudioEngine in measurement mode.
  - Configure play+record with low IO buffer size.
  - Capture mono float frames at configured hop size.
  - Feed frames to C++ DSP with zero allocations in callback.
  - Stream DSP outputs to Flutter via EventChannel or FFI stream bridge.
- **Android (`native/android`)**
  - Implement AAudio/Oboe low-latency callback path.
  - Same frame contract/hop-size semantics as iOS.
  - Feed identical DSP API and emit identical frame schema.
- **Acceptance criteria**
  - Mic→UI end-to-end latency <= 50ms max (target <= 30ms).
  - No dropouts/underruns in 10-minute continuous sessions.

### 2) Full UI surface from specs (required for shipping)

**What is missing**
- Only a functional LIVE_PITCH scaffold exists.
- Missing complete screens and flows from `specs/ui-ux.md` and `specs/interaction.md`.

**How it must be done**
- Implement top-level navigation: Home / Train / Analyze / Library / Settings.
- Implement `DRIFT_REPLAY` flow and automatic entry from `DRIFT_CONFIRMED` in Drift Awareness mode.
- Add all mandatory IDs and edge states (mic permission, noise warning, low confidence UI treatment, paused/completed overlays).
- Apply design-system tokens (color roles, typography, spacing, motion curves) instead of ad-hoc widget styling.

### 3) Exercise catalog + progression engine

**What is missing**
- Exercise configs are not yet derived from `specs/exercises.md` catalog.
- Unlocking/mastery/adaptive progression logic not implemented.

**How it must be done**
- Model mode/level/exercise IDs exactly as defined in specs.
- Encode tolerance + drift defaults per level (L1/L2/L3).
- Implement mastery metric calculations and thresholds.
- Add progression state persistence + unlock checks.

### 4) Persistence and analytics

**What is missing**
- No local DB for sessions, frame aggregates, drift events, mastery history.
- Analyze screens cannot be completed without this.

**How it must be done**
- Add SQLite schema for:
  - sessions
  - exercise attempts
  - drift events
  - per-session summary metrics
- Persist deterministic aggregates (not raw audio by default).
- Build query layer for trends, weakness map, and session detail timelines.

### 5) QA replay harness (required for deterministic sign-off)

**What is missing**
- `qa/` contains traces/spec docs but no complete executable assertion harness.

**How it must be done**
- Build a replay runner that injects JSONL frame streams.
- Assert:
  - exact state transitions
  - visual math values (`x_offset_px`, `E`, saturation, halo)
  - scoring/progression outcomes
- Encode scenario set from `specs/qa.md` as automated tests.
- Gate CI on replay pass/fail.

### 6) DSP hardening for noisy real devices

**What is missing**
- Current detector is baseline-quality; not yet robust enough for shipping environments.

**How it must be done**
- Add robust voicing and pitch tracking (e.g., YIN/MPM or equivalent hardened method).
- Improve confidence calibration across noisy/reverberant input.
- Strengthen vibrato detection and false-drift suppression.
- Validate against deterministic synthetic corpus + real recorded fixtures.

---

## Repo structure

```text
/specs                        # Authoritative product, interaction, DSP/UI, QA specs
/apps
  /mobile_flutter             # Flutter UI + training engine
/packages
  /pt_contracts               # Shared contracts/constants for DSP→UI data flow
/dsp                          # C++ DSP core + tests
/native
  /ios                        # iOS audio/bridge scaffolding
  /android                    # Android audio/bridge scaffolding
/qa
  /traces                     # Example DSP-frame traces
```

---

## Recommended next implementation order

1. **Native audio bridge (iOS + Android)** to replace simulation.
2. **QA replay harness** to lock deterministic behavior while iterating.
3. **Complete LIVE_PITCH + DRIFT_REPLAY** using design-system tokens.
4. **Exercise/progression engine + persistence**.
5. **Analyze/Library/Settings full implementation**.
6. **DSP hardening + performance tuning + device validation**.

---

## Determinism contract (do not violate)

UI output must be a pure function of:
1. Current exercise config,
2. Incoming DSP frame stream,
3. Training engine state machine.

Do not add undocumented smoothing, hidden hysteresis, or platform-specific branching that changes visible outcomes for identical frame input.
