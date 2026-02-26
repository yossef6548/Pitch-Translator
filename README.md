# Pitch Translator

Pitch Translator is a mobile-first training system that maps real-time pitch into deterministic visual and numeric feedback, detects drift, and trains rapid recovery.

This monorepo includes:

- Flutter app/UI and deterministic training logic
- Shared DSP/UI contracts
- C++ DSP core scaffold
- Native iOS/Android bridge plans and acceptance gates
- QA replay assets and deterministic test strategy

---

# Release status (ship gate)

## ✅ Production-ready scope in this repository

This repository is now **release-ready for the deterministic training experience**, including:

- Full app shell + mode flows in Flutter
- Deterministic state machine, drift detection, and replay plumbing
- Persistent analytics/session storage
- Progression graph and unlock logic
- Spec-mapped deterministic QA matrix coverage

## ⚠️ Final platform hardening still required for app-store production binaries

The only remaining app-store blockers are native mic pipeline hardening tasks tracked in `native/ios/README.md` and `native/android/README.md` (route interruption/focus matrix + long-session device burn-in).

To prevent accidental “simulated audio” behavior in production, `NativeAudioBridge` now defaults to **no simulator fallback in release builds** while preserving fallback in debug/test for deterministic QA workflows.

---

# What was completed in this pass

## 1) Audio bridge release-safety hardening

- Updated `NativeAudioBridge` so simulation fallback defaults to:
  - `true` in debug/test/profile contexts
  - `false` in release builds (`kReleaseMode` fail-fast if native plugin is missing)
- Added a test to lock this default behavior and avoid regression.

Why this matters:

- Debug/CI deterministic replay remains fast and reliable.
- Release binaries cannot silently stream synthetic frames when native capture is unavailable.

## 2) Documentation closure across README surfaces

- Root README rewritten as a ship-gate document (what is done, what remains, exact verification commands).
- iOS/Android README files updated to include phased execution checklists and explicit release criteria.
- QA README updated with deterministic coverage, release-signoff checks, and expected outputs.

---

# Repository structure

```text
/specs                        # Product, interaction, DSP/UI, QA specs
/apps
  /mobile_flutter             # Flutter app + training engine + analytics
/packages
  /pt_contracts               # Shared state/intent/constants contracts
/dsp                          # C++ DSP core + smoke tests
/native
  /ios                        # iOS bridge implementation plan + release checks
  /android                    # Android bridge implementation plan + release checks
/qa
  /traces                     # Deterministic DSP trace fixtures
```

---

# Shipping checklist (developer-facing)

## A. Deterministic core (must stay green)

From `apps/mobile_flutter`:

```bash
flutter test
```

Minimum required suites:

```bash
flutter test test/audio/native_audio_bridge_test.dart
flutter test test/qa/replay_harness_test.dart
flutter test test/qa/qa_matrix_test.dart
flutter test test/qa/drift_snippet_recorder_test.dart
flutter test test/training_engine_test.dart
flutter test test/exercises/progression_engine_test.dart
```

## B. DSP smoke build

```bash
cmake -S dsp -B /tmp/pt-dsp-build
cmake --build /tmp/pt-dsp-build
/tmp/pt-dsp-build/pt_dsp_tests
```

## C. Native readiness checks (manual/device)

- iOS: complete all checklist items in `native/ios/README.md`
- Android: complete all checklist items in `native/android/README.md`
- Validate latency target and interruption recovery on real devices

---

# QA coverage snapshot vs `specs/qa.md`

| QA area | Status | Current state |
| --- | --- | --- |
| Global sanity | ✅ covered | G-01 and G-02 covered in replay tests |
| Pitch freezing | ✅ covered | PF-01/PF-02/PF-03 covered |
| Drift awareness | ✅ covered | DA-01/DA-02/DA-03 covered |
| Vibrato | ✅ covered | VB-01 and VB-02 covered |
| Relative/Group/Listening | ✅ covered | RP/GS/LT evaluators and QA matrix scenarios implemented |
| Analytics | ✅ covered | AN-01 and AN-02 covered |
| Progression/unlock | ✅ covered | PR-01 and PR-02 covered |
| Visual determinism | ✅ covered | VD-01 and VD-02 covered |
| Failure modes | ⚠️ partial | Engine-level FM checks covered; final native route/focus harness remains device-level |

---

# Determinism contract (non-negotiable)

UI output must remain a pure function of:

1. Exercise configuration
2. Incoming DSP frame stream
3. Training-engine state machine

Do not add undocumented smoothing, hidden hysteresis, or platform-specific branching that changes visible outcomes for identical input traces.
