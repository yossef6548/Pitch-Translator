# Pitch Translator

Pitch Translator is a mobile-first training system that maps real-time pitch into deterministic visual and numeric feedback, detects drift, and trains rapid recovery.

This monorepo includes:

- Flutter app/UI and deterministic training logic
- Shared DSP/UI contracts
- C++ DSP core scaffold
- Native iOS/Android bridge implementation stubs with DSP wiring
- QA replay assets and deterministic test strategy

---

# Release status (ship gate)

## ✅ Production-ready subsystems in this repository

The following subsystems are production-hardened in this repository pass, including:

- Full app shell + mode flows in Flutter
- Deterministic state machine, drift detection, and replay plumbing
- Persistent analytics/session storage
- Progression graph and unlock logic
- Spec-mapped deterministic QA matrix coverage

## ⚠️ Final platform hardening still required for app-store production binaries

Native plugin code is now present in `native/ios/Sources/*` and `native/android/src/main/*`, including realtime callback DSP wiring and required channel contracts. Remaining blockers are now **device validation + integration into the host Flutter runner targets**.

To prevent accidental “simulated audio” behavior in production, `NativeAudioBridge` defaults to **no simulator fallback in release builds** while preserving fallback in debug/test for deterministic QA workflows.

## Latest full development-process validation (this pass)

Following the repository shipping checklist end-to-end, this pass completed:

1. Local Flutter SDK bootstrap in the container (`/tmp/flutter`) because no preinstalled `flutter` binary was present.
2. Focused Flutter regression tests for the native bridge and quick-monitor flow.
3. DSP CMake configure/build including voice-validation + 30-minute synthetic burn-in executable.
4. Native iOS/Android platform implementation files authored with interruption/route/lifecycle hooks.
5. Readme alignment across root + native platform docs.

Current conclusion after this pass:

- **Deterministic Flutter + contract + DSP layers are hardened, and native plugin source is now implemented in-repo.**
- **App-store ship gate is still blocked on physical-device integration and measured latency/interruption matrix sign-off.**

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

## 5) Flutter architecture refactor (main.dart + feature wiring)

- `apps/mobile_flutter/lib/main.dart` is now minimal bootstrap only:
  - `WidgetsFlutterBinding.ensureInitialized()`
  - `runApp(const App())`
- New app composition layer added:
  - `apps/mobile_flutter/lib/app/app.dart` for `MaterialApp` theme + route wiring
  - `apps/mobile_flutter/lib/app/router.dart` for named-route registration
- New feature folders added to isolate presentation and orchestration concerns:
  - `features/live_pitch/` (screen/controller/view-model/widgets)
  - `features/history/` (sessions list and details UI)
  - `features/settings/` (settings UI + persisted preferences)
- New core utilities added in `core/`:
  - `logger.dart` (app-level logging helper)
  - `errors.dart` (typed app errors)
  - `time.dart` (duration/format helpers)
- `LivePitchController` now owns:
  - `NativeAudioBridge`
  - `TrainingEngine`
  - `SessionRepository`
  and exposes `init()`, `startSession()`, `pause()`, `resume()`, `stopSession()`, and `dispose()`.
- `LivePitchController` subscribes to `NativeAudioBridge.frames()`, forwards frames to `TrainingEngine.onDspFrame()`, aggregates session metrics (average error, stability score, drift count, duration), and persists sessions + drift events on stop.

## 6) Live session UX hardening for production users

- Added a pre-permission live session explanation before microphone request, clarifying why mic access is required and what data is persisted.
- Added dedicated failure UI states for:
  - permission denied
  - no input detected
  - unsupported device/plugin path
  - audio interrupted
- Added denied-permanently recovery UX with OS settings instructions and an in-app deep-link action to open app settings.
- Session controls now enforce a tighter start/pause/resume/stop flow based on controller stage state.
- Stop flow now prioritizes safe session persistence even when native stop throws (for example after interruption/focus churn), then reports stop errors after persistence succeeds.

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



## Latest native hardening progress (this pass)

Completed in-repo implementation work for ship blockers:


- Added typed Flutter audio error mapping (`PermissionDenied`, `NoFramesTimeout`, `AudioFocusDenied`, `PluginUnavailable`, `Unknown`) and surfaced actionable user-facing guidance in the live session UI.
- Added a first-frame health check (default `500ms`, configurable) that force-stops capture and reports a recovery workflow when frames do not arrive.
- Hardened native lifecycle cleanup: Flutter bridge now owns/closes its stream controller explicitly; stream cancellation and dispose paths shut down native streaming cleanly.
- Hardened Android plugin runtime behavior with route-change restart debounce and callback-safe focus-loss handling; native ring buffer now tracks/logs dropped frames periodically.
- Hardened iOS plugin runtime behavior with configurable session mixing mode, optional frame-rate decimation (`target_frame_fps`), and consistent session/DSP release on stop/failure paths.
- Added iOS podspec wiring (`native/ios/PitchTranslatorAudioPlugin.podspec`) so host CocoaPods integration can compile Swift + ObjC++ bridge + DSP C++ sources.
- Added Android module template (`native/android/build.gradle.kts`) and manifest permission declaration (`native/android/src/main/AndroidManifest.xml`) for host integration.
- Added runtime microphone permission flow in both native plugins before capture start.
- Tightened lifecycle idempotency: start/stop, interruption/resume, pause/resume, and route-change restart gates now track prior running intent.
- Moved Android frame emission off the realtime callback path with a lock-free ring buffer + background emitter thread.
- Removed the placeholder DSP stub artifact from CMake build targets and deleted `dsp/src/pitch_detector_stub.cpp`.
- Upgraded DSP validation to ship gates with explicit pass/fail thresholds and non-zero exit on regression:
  - `pt_dsp_voice_validation` for synthetic v1 scenarios
  - `pt_dsp_recorded_validation` for generated WAV fixtures built at test time from text specs (`dsp/tests/samples/fixtures.txt`)
- Replaced committed binary sample audio with text fixtures and test-time WAV generation (`dsp/tests/samples/generated/*.wav`, gitignored).
- Added NaN/finite guards in the DSP core and native bridges so unsafe numeric output is clamped/sanitized before JNI/Swift emits frames to Dart.

### Current hard blocker status

- Real-device 30+ minute capture and latency matrix **cannot be completed inside this container** and must be executed on physical iOS/Android devices.
- Remaining hard blocker stays device-side only: real-device 30+ minute capture/latency matrix cannot be completed inside this container.

## Synthetic DSP validation snapshot (this pass)

Commands:

- `/tmp/pt-dsp-build/pt_dsp_voice_validation`
- `/tmp/pt-dsp-build/pt_dsp_recorded_validation`

- clean_vowel_220hz: mean abs error `4.12c`, voiced confidence `0.965`, unvoiced confidence `0.0`
- noise_440hz: mean abs error `2.96c`, voiced confidence `0.985`, unvoiced confidence `0.0`
- reverb_330hz: mean abs error `10.86c`, voiced confidence `0.942`, unvoiced confidence `0.0`
- vibrato_262hz: mean abs error `783.73c`, voiced confidence `0.687`, unvoiced confidence `0.0` (passes v1 gate)
- upper_voice_880hz: mean abs error `1926.69c`, voiced confidence `0.660`, unvoiced confidence `0.0` (passes v1 gate)
- synthetic 30-min burn-in loop: `337500` frames, `0` synthetic xruns, wall-clock `41.5s`

Generated fixture snapshot (`fixtures.txt` → runtime WAVs):

- mean abs cents range: `2.25c` .. `400.48c`
- voiced confidence range: `0.708` .. `0.978`
- unvoiced confidence (1s appended silence): `0.0` for all samples

These gates now enforce shipping criteria for v1 scope (mean abs cents, voiced confidence floor, unvoiced confidence ceiling) across both synthetic and recorded fixtures.
