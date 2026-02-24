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

- **Training Engine (production-capable deterministic core)**
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

- **Exercise catalog + progression core (expanded to full spec taxonomy)**
  - Authoritative mode IDs and level defaults encoded from `specs/exercises.md`
  - Full exercise catalog now includes all currently defined IDs in spec:
    - PF: `PF_1..PF_4`
    - DA: `DA_1..DA_3`
    - RP: `RP_1..RP_5`
    - GS: `GS_1..GS_4`
    - LT: `LT_1..LT_3`
  - Unlock graph supports:
    - same-level prerequisite checks per exercise
    - mode-order progression (`PF → DA → RP → GS → LT`)
    - level unlock by prior-level mastery ratio (`L2=70%`, `L3=80%`)

- **Adaptive progression rules (implemented from spec section 10/12)**
  - Tracks per-exercise progress entries (`attempts`, `assisted_attempts`, `mastery_date`, `last_attempt_date`, `best_metrics`, failure streak)
  - Assisted mode trigger after 3 consecutive failures:
    - temporary tolerance widening `+5c`
    - duration scaling `0.8x`
  - Assisted completions are persisted but do not award mastery credit
  - Skill-decay refresh flag support for masteries older than 30 days

- **Deterministic QA replay harness**
  - Reusable `ReplayHarness` that executes recorded `DspFrame` streams against `TrainingEngine`
  - JSONL parser for loading traces from `qa/traces`
  - Automated QA-style tests covering null-pitch low-confidence behavior and drift-candidate recovery

---

## 🚧 What’s still left before true “ship to users”

This section is intentionally explicit so execution can continue without reverse-engineering intent.

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

### 3) Persistence and analytics

**What is missing**
- Progression supports in-memory state only.
- No local DB for sessions, frame aggregates, drift events, mastery history.
- Analyze screens cannot be completed without this.

**How it must be done**
- Add SQLite schema for:
  - sessions
  - exercise attempts
  - drift events
  - per-session summary metrics
  - mastery history entries
- Persist deterministic aggregates (not raw audio by default).
- Build query layer for trends, weakness map, and session detail timelines.

### 4) QA replay harness expansion (required for deterministic sign-off)

**Current status**
- Deterministic replay harness and fixture parser are in place.
- Scenario coverage currently includes low-confidence and drift recovery baselines.

**Still required before ship**
- Expand scenario matrix to full `specs/qa.md` coverage.
- Add strict assertions for all visual scalars (`x_offset_px`, saturation, halo, deformation).
- Integrate replay suite into CI gate.

### 5) DSP hardening for noisy real devices

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
2. **Complete LIVE_PITCH + DRIFT_REPLAY** using design-system tokens.
3. **Persist progression + session analytics in SQLite and expose query layer for Analyze**.
4. **Expand QA replay scenarios to full spec coverage and enforce in CI**.
5. **Analyze/Library/Settings full implementation**.
6. **DSP hardening + performance tuning + device validation**.

---

## New implementation details (this iteration)

### Exercise and progression domain

- `apps/mobile_flutter/lib/exercises/exercise_catalog.dart`
  - Expanded exercise registry to include full `MODE_RP`, `MODE_GS`, and `MODE_LT` lists from spec.
  - Added mode sequencing helper to enforce mode unlock order.
  - Updated unlock filtering to gate by both level unlock and mode unlock.

- `apps/mobile_flutter/lib/exercises/progression_engine.dart`
  - Added persistent in-memory progression records via `ExerciseProgress`.
  - Added assisted training support (`AssistAdjustment`) with configurable assist trigger.
  - Added skill decay refresh evaluation (`needsRefresh`) using 30-day window.
  - Updated `applyResult` to:
    - track attempts and assisted attempts
    - preserve and update best metrics
    - update failure streaks
    - deny mastery credit for assisted completions

### Tests expanded

- `apps/mobile_flutter/test/exercises/progression_engine_test.dart`
  - Added full-catalog coverage checks and mode unlock-order tests.
  - Added tests for assisted-attempt behavior and assist trigger after repeated failures.
  - Added skill-decay refresh test for >30-day mastery age.

---

## How to run checks locally

### Flutter domain tests

```bash
cd apps/mobile_flutter
flutter test
```

### DSP smoke build/check

```bash
cmake -S dsp -B /tmp/pt-dsp-build
cmake --build /tmp/pt-dsp-build
/tmp/pt-dsp-build/pt_dsp_tests
```

> Note: In this execution environment, Flutter/Dart CLI binaries may be unavailable; DSP checks remain runnable with standard CMake toolchains.

---

## Determinism contract (do not violate)

UI output must be a pure function of:
1. Current exercise config,
2. Incoming DSP frame stream,
3. Training engine state machine.

Do not add undocumented smoothing, hidden hysteresis, or platform-specific branching that changes visible outcomes for identical frame input.
