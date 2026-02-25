# Pitch Translator

Pitch Translator is a mobile-first training system that maps real-time pitch to deterministic visual and numeric feedback, detects drift, and trains recovery.

This monorepo includes:

- Flutter app/UI and deterministic training logic
- Shared DSP/UI contracts
- C++ DSP core scaffold
- Native iOS/Android bridge scaffolding
- QA replay assets and test strategy

---

# Implementation status (current pass)

## ✅ Implemented and refactored

### Repository architecture and boundaries

- Flutter application in `apps/mobile_flutter`
- Shared contracts/constants in `packages/pt_contracts`
- DSP C++ module and smoke tests in `dsp`
- Native bridge placeholders in `native/ios` and `native/android`
- Product/spec docs in `specs`
- QA artifacts and traces in `qa`

### Deterministic training core

- Core state machine implemented:
  - `IDLE → COUNTDOWN → SEEKING_LOCK → LOCKED → DRIFT_CANDIDATE → DRIFT_CONFIRMED`
  - `ANY → LOW_CONFIDENCE` override
  - `PAUSED`, `COMPLETED`
- Confidence override and recovery thresholds match contract defaults.
- Vibrato-aware effective error windowing implemented.
- Deterministic visual channels implemented from frame+config:
  - effective error `E`
  - direction `D`
  - `xOffsetPx`
  - `deformPx`
  - saturation
  - halo
- Drift replay payload capture implemented via `DriftEvent(before, after)`.

### App navigation and primary UI flows

- Root 5-tab shell (`Home`, `Train`, `Analyze`, `Library`, `Settings`)
- Mode catalog and mode overview entry flow
- Exercise config screen with:
  - level and tolerance controls
  - randomization controls
  - reference/feedback toggles
  - target note+octave picker
  - timbre and reference volume controls
- LIVE_PITCH integration with selected exercise config
- Drift replay modal/sheet flow scaffolding from confirmed drifts
- Home quick monitor card upgraded to interactive launch into warm-up exercise

### Persistence and analytics

- SQLite persistence for sessions, attempts, drift events, mastery history
- Schema migrations implemented for expanded metrics and drift replay payloads
- Analyze trends and weakness-map data queries implemented
- Library/Settings display persisted aggregates
- Retention and mode/level percentile summaries implemented

### Progression system

- Full exercise taxonomy encoded (PF/DA/RP/GS/LT families)
- Unlock graph with prerequisites and level thresholds
- Assisted-mode fallback after failure streak
- Assisted attempts tracked separately from mastery credit
- Skill-decay refresh flags supported

### QA + deterministic replay (expanded this pass)

- Replay harness for DSP frame stream injection implemented
- JSONL trace parser implemented
- Replay harness now captures transition timeline metadata (`ReplayTransition`) for state-change assertions.
- Shared DSP frame test factory added to avoid duplicated test setup and improve consistency.
- QA replay tests now cover:
  - `QA-G-01` null-pitch low-confidence path
  - `QA-G-02` confidence override lock-break
  - `QA-PF-01` basic lock acquisition
  - `QA-PF-02` lock near-miss
  - `QA-DA-01` drift-candidate recovery
  - `QA-DA-02` drift-confirmed trigger precondition
  - `QA-VB-01` valid vibrato handling
  - `QA-VB-02` excessive vibrato treated as error
  - `QA-VD-01` cents→pixel mapping determinism
  - `QA-VD-02` deformation max at threshold
  - `QA-AN-01` average-error and stability metrics
  - `QA-AN-02` drift-count accuracy
  - `QA-PR-01` mode unlock gating
  - `QA-PR-02` level unlock gating
  - `QA-FM-01` pause/resume integrity (engine-level scope)

---

## 🚧 Remaining blockers before production release

1. **Native real-time microphone capture pipeline**
   - iOS AVAudioEngine measurement-mode path
   - Android Oboe/AAudio callback path
   - Real-time frame bridge parity with contract
   - Verified mic→UI latency budget and session stability

2. **Full QA matrix completion from `specs/qa.md`**
   - PF-03, DA-03, FM-02 scenarios
   - RP/GS/LT mode-level deterministic evaluators and QA fixtures
   - UI replay panel verification for drift-replay experience

3. **Replay media integration for real snippets**
   - Current drift replay uses deterministic payload snapshots
   - Real captured audio snippet persistence/playback is still pending

4. **Design-system completion and accessibility tuning**
   - Full tokenization sweep (spacing/typography/motion/color)
   - Accessibility audits and contrast checks across all surfaces

5. **DSP hardening for noisy production environments**
   - Improved voicing/pitch tracker robustness
   - Device-level calibration and false-drift suppression validation

---

## QA coverage snapshot

| QA area | Status | Current state |
| --- | --- | --- |
| Global sanity | ✅ covered | G-01 and G-02 are covered in replay tests |
| Pitch freezing | ⚠️ partial | PF-01 and PF-02 covered; PF-03 still pending |
| Drift awareness | ⚠️ partial | DA-01 and DA-02 covered; DA-03 still pending |
| Vibrato | ✅ covered | VB-01 and VB-02 covered |
| Relative/Group/Listening | ❌ pending | requires dedicated mode-level deterministic evaluators |
| Analytics | ✅ covered | AN-01 and AN-02 covered in QA matrix tests |
| Progression/unlock | ✅ covered | PR-01 and PR-02 mapped directly to QA tests |
| Visual determinism | ✅ covered | VD-01 and VD-02 covered |
| Failure modes | ⚠️ partial | FM-01 covered at engine level; FM-02 pending native route tests |

---

## Recommended next implementation order

1. Native audio I/O bridge completion (iOS + Android)
2. RP/GS/LT evaluator implementation + QA-ID fixtures
3. Drift replay audio snippet capture/playback integration
4. Design tokenization + accessibility closure
5. DSP hardening/device validation
6. Production burn-in and release checklist completion

---

## Repository structure

```text
/specs                        # Product, interaction, DSP/UI, QA specs
/apps
  /mobile_flutter             # Flutter app + training engine + analytics
/packages
  /pt_contracts               # Shared state/intent/constants contracts
/dsp                          # C++ DSP core + smoke tests
/native
  /ios                        # iOS bridge scaffolding
  /android                    # Android bridge scaffolding
/qa
  /traces                     # Example deterministic DSP trace fixtures
```

---

## Running checks locally

### Flutter tests

```bash
cd apps/mobile_flutter
flutter test
```

### Focused deterministic QA replay suite

```bash
cd apps/mobile_flutter
flutter test test/qa/replay_harness_test.dart
flutter test test/qa/qa_matrix_test.dart
```

### Progression and engine suites

```bash
cd apps/mobile_flutter
flutter test test/training_engine_test.dart
flutter test test/exercises/progression_engine_test.dart
```

### DSP smoke build/test

```bash
cmake -S dsp -B /tmp/pt-dsp-build
cmake --build /tmp/pt-dsp-build
/tmp/pt-dsp-build/pt_dsp_tests
```

> Note: Flutter/Dart CLI is not installed in this execution container, so Flutter tests must be run on a machine/CI runner with Flutter SDK available.

---

## Determinism contract (non-negotiable)

UI output must remain a pure function of:

1. Exercise configuration
2. Incoming DSP frame stream
3. Training-engine state machine

Do not add undocumented smoothing, hidden hysteresis, or platform-specific branching that changes visible outcomes for identical input traces.
