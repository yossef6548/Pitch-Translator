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
- Native bridge scaffolding and implementation checklists in `native/ios` and `native/android`
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
- Drift telemetry upgraded with deterministic counters/metrics:
  - confirmed drift event count (`confirmedDriftCount`)
  - average recovery time after drift confirmation (`averageRecoveryTimeMs`)
- Drift snippet persistence integrated in Flutter session flow:
  - rolling DSP frame history buffer retained during active exercise
  - per-drift JSON snippet captured under local app storage (`drift_snippets`)
  - persisted snippet path linked into `drift_events.audio_snippet_uri` for replay/library analytics

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
- Native audio bridge upgraded to prefer platform `EventChannel`/`MethodChannel` transport (`pt/audio/frames`, `pt/audio/control`) with deterministic simulator fallback in plugin-missing/dev environments
- Drift replay modal/sheet flow now loads persisted snippet frames, supports frame-aware replay telemetry, and is accessible from both Session Detail and Library surfaces
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

### Mode-level deterministic evaluators (new this pass)

- Added deterministic evaluators to cover remaining QA specification domains:
  - `RelativePitchEvaluator` for arithmetic pitch prompts (`RP_*`)
  - `GroupSimulationEvaluator` for lock-ratio/drift/confusion analysis (`GS_*`)
  - `ListeningTranslationEvaluator` for note+octave correctness (`LT_*`)
- Evaluators are intentionally stateless/pure for deterministic replay and unit testability.

### QA + deterministic replay (expanded this pass)

- Replay harness for DSP frame stream injection implemented
- Flutter toolchain bootstrapped in-container for ongoing work:
  - Flutter `3.41.2` (stable)
  - Dart `3.11.0`
  - global commands available via `/usr/local/bin/flutter` and `/usr/local/bin/dart`
- JSONL trace parser implemented
- Replay harness captures transition timeline metadata (`ReplayTransition`) for state-change assertions.
- Shared DSP frame test factory added to avoid duplicated test setup and improve consistency.
- QA matrix/replay coverage now includes:
  - `QA-G-01`, `QA-G-02`
  - `QA-PF-01`, `QA-PF-02`, `QA-PF-03`
  - `QA-DA-01`, `QA-DA-02`, `QA-DA-03`
  - `QA-VB-01`, `QA-VB-02`
  - `QA-RP-01`, `QA-RP-02`
  - `QA-GS-01`, `QA-GS-02`
  - `QA-LT-01`, `QA-LT-02`
  - `QA-VD-01`, `QA-VD-02`
  - `QA-AN-01`, `QA-AN-02`
  - `QA-PR-01`, `QA-PR-02`
  - `QA-FM-01`, `QA-FM-02` (engine-level route interruption simulation)

---

## 🚧 Remaining blockers before production release

1. **Native real-time microphone capture pipeline completion**
   - ✅ Flutter side channel contract and start/stop control path implemented (`NativeAudioBridge`)
   - iOS AVAudioEngine measurement-mode path implementation still pending
   - Android Oboe/AAudio callback implementation still pending
   - Verified mic→UI latency budget and session stability on physical devices still pending

2. **Native integration QA and performance burn-in**
   - Move FM-02 from engine simulation to device-level route-interruption harness
   - Add end-to-end mic route-change and audio-focus-loss tests
   - Add device-matrix latency profiling and long-session stability checks

3. **Design-system completion and accessibility tuning**
   - Full tokenization sweep (spacing/typography/motion/color)
   - Accessibility audits and contrast checks across all surfaces

4. **DSP hardening for noisy production environments**
   - Improved voicing/pitch tracker robustness
   - Device-level calibration and false-drift suppression validation

---

## QA coverage snapshot

| QA area | Status | Current state |
| --- | --- | --- |
| Global sanity | ✅ covered | G-01 and G-02 are covered in replay tests |
| Pitch freezing | ✅ covered | PF-01/PF-02/PF-03 covered in deterministic engine tests |
| Drift awareness | ✅ covered | DA-01/DA-02/DA-03 covered including recovery-time assertion |
| Vibrato | ✅ covered | VB-01 and VB-02 covered |
| Relative/Group/Listening | ✅ covered | RP/GS/LT evaluators and QA matrix scenarios implemented |
| Analytics | ✅ covered | AN-01 and AN-02 covered in QA matrix tests |
| Progression/unlock | ✅ covered | PR-01 and PR-02 mapped directly to QA tests |
| Visual determinism | ✅ covered | VD-01 and VD-02 covered |
| Failure modes | ⚠️ partial | FM-01 and FM-02 covered at engine layer; Flutter channel fallback path covered, but native route harness is still pending |
| Drift snippet persistence | ✅ covered | Drift confirmation persists rolling JSON snippets, and replay controls can load these snippets from Session Detail and Library views |

---

## Recommended next implementation order

1. Native iOS/Android audio callback implementations behind the now-defined Flutter channel contract
2. Native integration/performance QA matrix execution on physical device matrix
3. Design tokenization + accessibility closure
4. DSP hardening/device validation
5. Production burn-in and release checklist completion

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

> Environment note: Flutter SDK is installed in this container at `/opt/flutter`, with persistent symlinks in `/usr/local/bin/flutter` and `/usr/local/bin/dart` for future tasks.

---

## Determinism contract (non-negotiable)

UI output must remain a pure function of:

1. Exercise configuration
2. Incoming DSP frame stream
3. Training-engine state machine

Do not add undocumented smoothing, hidden hysteresis, or platform-specific branching that changes visible outcomes for identical input traces.
