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

## Latest full development-process validation (this pass)

Following the repository shipping checklist end-to-end, this pass completed:

1. Local Flutter SDK bootstrap in the container (`/tmp/flutter`) because no preinstalled `flutter` binary was present.
2. Full Flutter test run across the mobile app package (`61` tests passing).
3. DSP CMake configure/build/test-smoke run with a clean temporary build directory.
4. Readme/spec alignment review for release status and remaining native hardening boundaries.

Current conclusion remains:

- **Deterministic training product in this repository is ship-ready.**
- **App-store production binaries still require native iOS/Android hardening checklist completion on real devices.**

---

# What was completed in this pass

## 1) Audio bridge hardening + deterministic plugin-absence behavior

- `NativeAudioBridge.frames()` now performs a native-start probe before frame subscription.
- If native plugins are absent and fallback is enabled, the stream immediately switches to deterministic simulation.
- If fallback is disabled, frame and control paths fail fast with `MissingPluginException`.
- Added/updated tests to lock method-channel probing behavior and payload validation.

Why this matters:

- Debug/CI deterministic replay remains fast and reliable.
- Release binaries cannot silently stream synthetic frames when native capture is unavailable.

## 2) Training-engine spec alignment fixes

- Drift-awareness flow now keeps `DRIFT_CONFIRMED` until incoming frames actually recover within tolerance, then returns to seeking-lock/relock progression.
- Locked state visuals are now rigid when effective error is within tolerance (centered X offset + no deformation), matching QA matrix expectations.
- Added bounded snippet-file IO behavior for drift replay snippet loading so unavailable files resolve deterministically instead of stalling asynchronous UI state.

## 3) Documentation closure across README surfaces

- Root README maintained as a ship-gate document (what is done, what remains, exact verification commands).
- QA README expanded with this pass's behavior fixes and verification guidance.
- iOS/Android READMEs remain the source of truth for remaining device hardening before app-store binaries.

## 4) Test-lab stabilization fixes completed in this pass

- Drift replay widget tests now use synchronous snippet-fixture writing so deterministic widget tests do not stall under Flutter's fake-async harness.
- Library loading now degrades safely to empty-state metrics if storage/database plumbing is unavailable (test or bootstrap edge environments), preserving screen availability.
- Full Flutter test suite and required QA-targeted suites were re-run successfully after these fixes.

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

Use a local Flutter SDK on PATH (or `/opt/flutter/bin/flutter` in CI/containerized environments).

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

### Container note

If `flutter` is missing on PATH in a clean environment, bootstrap and run tests with:

```bash
git clone https://github.com/flutter/flutter.git --depth 1 -b stable /tmp/flutter
/tmp/flutter/bin/flutter test
```

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
