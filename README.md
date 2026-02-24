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

- **Training Engine (deterministic core + drift replay capture)**
  - Implemented state machine:
    - `IDLE → COUNTDOWN → SEEKING_LOCK → LOCKED → DRIFT_CANDIDATE → DRIFT_CONFIRMED`
    - `ANY → LOW_CONFIDENCE` override
    - `PAUSED`, `COMPLETED`
  - Vibrato-aware effective error windowing
  - Deterministic visual math outputs (`E`, `D`, x-offset, saturation, halo)
  - Drift replay payload capture via `DriftEvent` (`before` locked frame and `after` drift-confirm frame)

- **App shell and primary UI surfaces**
  - Implemented persistent root navigation tabs:
    - `Home`
    - `Train`
    - `Analyze`
    - `Library`
    - `Settings`
  - Implemented `TRAIN_CATALOG` grouping by mode with mode-overview entry flow
  - Implemented `MODE_<MODE>_OVERVIEW` screens with:
    - mode explanation
    - training bullet summaries
    - exercise list into `EXERCISE_CONFIG`
  - Implemented `EXERCISE_CONFIG` with key spec sections:
    - target randomization toggle
    - level selection (`L1/L2/L3`) synced to defaults
    - tolerance presets and custom slider
    - reference + feedback toggles
    - start action passing concrete config into `LIVE_PITCH`
  - Added initial `HOME_TODAY` cards (`FOCUS_CARD`, live quick monitor preview, progress snapshot, continue card)
  - Added Home Focus CTA launch into prefilled `EXERCISE_CONFIG`
  - Added `DRIFT_REPLAY` modal flow from live session when drift is confirmed in Drift Awareness exercises

- **LIVE_PITCH app scaffold**
  - Functional screen wiring to training engine
  - Target header, pitch line, shape/halo, cents readout, controls
  - Target header now binds to selected note/octave configuration and computed MIDI
  - Deterministic simulated frame stream for local iteration

- **Onboarding + calibration flow**
  - Added `RootFlow` with gated `ONBOARDING_CALIBRATION` flow prior to app shell access
  - Includes guided orientation pages and explicit mic/headphone readiness checks
  - Persisted onboarding completion with `shared_preferences` so first-run gating is not shown again after relaunch

- **Analyze/Library/Settings expansion**
  - Added Analyze internal tabs (`Sessions`, `Trends`, `Weakness Map`)
  - Added Session detail screen scaffolding with timeline/drift marker summary surfaces
  - Replaced static Library/Settings placeholder rows with SQLite-backed summaries derived from real session, attempt, drift, and mastery data

- **Exercise config advanced controls**
  - Added target note/octave modal picker
  - Added randomization min/max note selectors
  - Added reference timbre selector and reference volume slider
  - Propagated new config fields to LIVE_PITCH session summary and target header

- **C++ DSP baseline implementation**
  - Autocorrelation-based pitch estimate
  - MIDI / nearest MIDI / cents error computation
  - Confidence estimate
  - Basic vibrato heuristic outputs

- **Exercise catalog + progression core (full spec taxonomy)**
  - Authoritative mode IDs and level defaults encoded from `specs/exercises.md`
  - Full exercise catalog includes all currently defined IDs in spec:
    - PF: `PF_1..PF_4`
    - DA: `DA_1..DA_3`
    - RP: `RP_1..RP_5`
    - GS: `GS_1..GS_4`
    - LT: `LT_1..LT_3`
  - Unlock graph supports:
    - same-level prerequisite checks per exercise
    - mode-order progression (`PF → DA → RP → GS → LT`)
    - level unlock by prior-level mastery ratio (`L2=70%`, `L3=80%`)

- **Adaptive progression rules (spec section 10/12)**
  - Tracks per-exercise progress entries (`attempts`, `assisted_attempts`, `mastery_date`, `last_attempt_date`, `best_metrics`, failure streak)
  - Assisted mode trigger after 3 consecutive failures:
    - temporary tolerance widening `+5c`
    - duration scaling `0.8x`
  - Assisted completions are persisted but do not award mastery credit
  - Skill-decay refresh flag support for masteries older than 30 days


- **SQLite persistence + analytics query layer (expanded baseline)**
  - Expanded SQLite schema to include `sessions`, `attempts`, `drift_events`, and `mastery_history` with DB v2 migration support
  - Added runtime recording from `LIVE_PITCH` into session rows and linked attempt/drift/mastery records
  - Added aggregate summary APIs powering data-backed Library/Settings sections
  - Added trend aggregation API (`avg_error_cents`, `stability_score`, `drift/session`)

- **Deterministic QA replay harness**
  - Reusable `ReplayHarness` that executes recorded `DspFrame` streams against `TrainingEngine`
  - JSONL parser for loading traces from `qa/traces`
  - Automated QA-style tests covering null-pitch low-confidence behavior, drift-candidate recovery, and drift replay event capture

---

## 🚧 Remaining work before production ship

### 1) Native real-time audio I/O (required for shipping)

**Current state**
- Flutter currently uses a deterministic simulation source (`NativeAudioBridge.frames()`), not microphone capture.

**Still required**
- **iOS (`native/ios`)**
  - AVAudioEngine measurement-mode capture
  - low-latency play/record setup
  - callback-safe frame transfer into C++ DSP
  - frame transport bridge into Flutter
- **Android (`native/android`)**
  - Oboe/AAudio low-latency callback path
  - identical hop/frame semantics as iOS
  - same DSP entrypoint and frame schema
- **Acceptance criteria**
  - Mic→UI latency <= 50ms max (target <= 30ms)
  - 10-minute session stability with no underruns/dropouts

### 2) Full UI completion against specs

**Current state**
- Root app navigation, train catalog, and mode-overview flows are implemented.
- First-run onboarding + audio calibration checklist flow is now implemented before app-shell entry.
- Analyze/Library/Settings now include spec-aligned section structure and navigable Analyze tabs with session detail drill-in.
- Analyze trends now render persisted metric sparklines (avg cents error, stability score, drift count) from SQLite-backed session history.
- Analyze weakness map now renders a persisted pitch-class × octave heatmap (error magnitude intensity) generated from attempt-level note/octave/error captures.
- Session detail now includes an in-session timeline strip with drift markers plus marker rows that open replay-ready previews.
- Exercise config includes advanced options: target note/octave picker modal, randomization range selectors, timbre selector, and reference volume slider.
- Live pitch target header now reflects configured target note/octave and MIDI.

**Still required**
- Add native audio snippet attachment and true replay playback when tapping Session Detail drift markers
- Apply full design token system (typography scale, spacing roles, motion curves, accessibility palettes)
- Implement complete quick-monitor passive mic preview widget on HOME_TODAY card

### 3) Persistence and analytics

**Current state**
- Onboarding gate completion is now persisted across launches via local key-value storage.
- Runtime LIVE_PITCH session summaries are now persisted locally and surfaced in Home/Analyze.

**Still required**
- Extend aggregation set with per-mode/per-level percentile and longitudinal retention analytics

### 4) QA replay harness expansion + CI gating

**Current state**
- Harness + parser + baseline scenarios are implemented.

**Still required**
- Extend scenario matrix to full `specs/qa.md`
- Add strict visual scalar assertions for every deterministic output channel
- Wire replay suite into CI required checks

### 5) DSP hardening for noisy devices

**Current state**
- Detector is baseline-quality and useful for internal integration.

**Still required**
- Robust voicing and advanced pitch-tracking strategy (YIN/MPM-class)
- Confidence calibration for reverberant/noisy environments
- Stronger false-drift suppression under expressive singing
- Validation with synthetic corpus + real device fixture set

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

1. **Native audio bridge (iOS + Android)** to replace simulation and validate latency budget.
2. **Complete Analyze replay media integration** (attach audio snippets to drift markers and enable tap-to-play replay in Session Detail).
3. **Expand QA replay scenarios to full spec coverage and enforce in CI**.
4. **Apply complete design system tokenization and accessibility tuning across all screens**.
5. **DSP hardening + performance tuning + device validation**.
6. **Final production burn-in and release checklist across iOS/Android targets**.

---

## New implementation details (this iteration)

### App architecture / navigation

- `apps/mobile_flutter/lib/main.dart`
  - Replaced single-screen app entry with a root `AppShell` and persistent 5-tab navigation (`Home`, `Train`, `Analyze`, `Library`, `Settings`).
  - Added `TRAIN_CATALOG` grouping exercises by mode and launching per-mode overviews.
  - Added `MODE_<MODE>_OVERVIEW` and `EXERCISE_CONFIG` flows to align with interaction/ui specs.
  - Added config handoff from `EXERCISE_CONFIG` into `LIVE_PITCH` so training runs against explicit user-selected tolerances and feedback/session toggles (randomize target, reference tone, numeric overlay, shape warping, color flood, haptics).
  - Added baseline `HOME_TODAY` card stack aligned with spec component IDs.
  - Added Focus-card route directly into configurable exercise setup.
  - Added automatic `DRIFT_REPLAY` modal after drift confirmation in drift-awareness exercises.


### Exercise config serialization hardening

- `packages/pt_contracts/lib/src/state.dart`
  - Expanded `ExerciseConfig` to carry all user-selectable session options from `EXERCISE_CONFIG`:
    - `randomizeTargetWithinRange`
    - `referenceToneEnabled`
    - `showNumericOverlay`
    - `shapeWarpingEnabled`
    - `colorFloodEnabled`
    - `hapticsEnabled`
- `apps/mobile_flutter/lib/main.dart`
  - Fixed `Start Exercise` handoff so all exercise setup toggles are preserved when opening `LIVE_PITCH`.
  - Wired `showNumericOverlay` to `LIVE_PITCH` cents readout visibility to ensure session behavior reflects user selection.
  - Added a compact session-options status row in `LIVE_PITCH` for deterministic verification of the active run configuration.

### Onboarding persistence hardening

- `apps/mobile_flutter/lib/main.dart`
  - Added `shared_preferences`-backed onboarding completion storage (`onboarding_complete`) in `RootFlow`.
  - Added async boot hydration/loading state to avoid flashing onboarding before persisted state is read.
  - Added guarded preference-load fallback: if preference read throws, startup now safely defaults to first-run onboarding and clears the blocking loading spinner so users can still enter the app.
  - Persists completion before transitioning to `AppShell` so first-run gating behaves correctly across relaunches.


### Analyze charts + weakness analytics (this iteration)

- `apps/mobile_flutter/lib/analytics/session_repository.dart`
  - Introduced schema migration to DB v3 with attempt-level note/octave/error capture fields.
  - Added trend-series query API for chart rendering over recent sessions.
  - Added weakness-map aggregation query grouped by pitch class + octave.
  - Added drift-event query API for Session Detail marker drilldown.
- `apps/mobile_flutter/lib/main.dart`
  - Replaced Trends tab placeholders with rendered sparkline charts for avg error, stability, and drift count.
  - Replaced Weakness Map placeholder with color-intensity heatmap tiles sourced from persisted attempt aggregates.
  - Upgraded Session Detail with timeline visualization and drift marker list interactions.
  - Updated LIVE_PITCH persistence to record attempt target note/octave/error and precise drift event timestamps.

### Persistence + data-backed surfaces (this iteration)

- `apps/mobile_flutter/lib/analytics/session_repository.dart`
  - Upgraded local DB schema from version 1 to version 2 with forward migration support.
  - Added durable tables for `attempts`, `drift_events`, and `mastery_history` in addition to `sessions`.
  - Added write APIs for attempt rows, drift-event rows, and mastery history rows tied to session IDs.
  - Added aggregate query helpers used by UI surfaces: `libraryCounts()` and `settingsSummary()`.
- `apps/mobile_flutter/lib/main.dart`
  - `LIVE_PITCH` persistence now records a session row and linked attempt/drift/mastery entries at stop/dispose.
  - `LibraryScreen` now renders persisted counters (reference-tone coverage, mastery archive size, drift replay clip count).
  - `SettingsScreen` now renders data-derived summaries (detection profile heuristic, assisted attempt ratio, privacy/storage mode).

### Validation and tooling progress

- Added `apps/mobile_flutter/test/exercise_config_screen_test.dart` widget test to prevent regressions where setup selections are dropped at session start.
- Added `apps/mobile_flutter/test/root_flow_onboarding_test.dart` widget tests covering persisted onboarding skip and first-run completion persistence behavior.
- Added failure-path widget coverage proving `RootFlow` exits loading state and shows onboarding when `SharedPreferences` read fails.
- Flutter SDK/Dart CLI was not available in this container during this pass, so Flutter tests could not be re-run here.
- DSP smoke build commands remain runnable in this environment and were re-verified in this pass.

### Training engine drift replay capture

- `apps/mobile_flutter/lib/training/training_engine.dart`
  - Added `DriftEvent` model with before/after frame snapshots for replay UI.
  - Captures `lastDriftEvent` at drift confirmation boundary.
  - Tracks last locked frame to anchor replay "before" state deterministically.

### Tests expanded

- `apps/mobile_flutter/test/training_engine_test.dart`
  - Added test validating drift confirmation emits replay event snapshots with expected values.

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

> Note: Flutter/Dart were not present in this execution environment. Run Flutter checks on a machine/CI runner with Flutter SDK installed.

---

## Determinism contract (do not violate)

UI output must be a pure function of:
1. Current exercise config,
2. Incoming DSP frame stream,
3. Training engine state machine.

Do not add undocumented smoothing, hidden hysteresis, or platform-specific branching that changes visible outcomes for identical frame input.


