# QA Harness

This folder contains deterministic QA assets and guidance for validating `specs/qa.md` scenarios through DSP-frame replay.

## Deterministic QA components implemented

- `ReplayHarness` in Flutter domain (`apps/mobile_flutter/lib/qa/replay_harness.dart`) driving `TrainingEngine` from immutable `DspFrame` streams.
- JSONL trace parser (`ReplayHarness.parseJsonl`) for reusable trace fixtures in `qa/traces`.
- Transition timeline capture (`ReplayTransition`) for explicit state-change and timing assertions.
- Shared DSP frame test factory (`apps/mobile_flutter/test/support/dsp_frame_factory.dart`) to keep replay and engine tests consistent.
- Drift snippet recorder (`apps/mobile_flutter/lib/qa/drift_snippet_recorder.dart`) for rolling pre/post-drift frame persistence.

## Automated suite coverage

Latest pass updates included:

- Native audio bridge startup probing + fallback/fail-fast behavior is now explicitly regression-tested.
- Drift-awareness recovery behavior now matches QA-DA expectations (confirm persists until real recovery input).
- Locked-state visual rigidity (within tolerance) is enforced by QA matrix tests.
- Drift snippet replay file loading now uses bounded file IO to avoid unresolved async waits in edge-path tests.


- Replay tests (`test/qa/replay_harness_test.dart`):
  - QA-G-01, QA-G-02
  - QA-DA-01, QA-DA-02
  - QA-VB-01, QA-VB-02
  - QA-VD-01, QA-VD-02
- Matrix tests (`test/qa/qa_matrix_test.dart`):
  - QA-PF-01/02/03
  - QA-DA-03
  - QA-RP-01/02
  - QA-GS-01/02
  - QA-LT-01/02
  - QA-AN-01/02
  - QA-PR-01/02
  - QA-FM-01/02 (engine-level)
- Audio bridge tests (`test/audio/native_audio_bridge_test.dart`):
  - deterministic fallback in plugin-missing debug/test mode
  - strict failure path when fallback disabled
  - payload schema validation
  - default fallback policy lock for debug/test

## Release sign-off matrix vs `specs/qa.md`

| Section | Status | Notes |
| --- | --- | --- |
| Global sanity (`QA-G-*`) | ✅ covered | Deterministic replay assertions implemented. |
| Pitch Freezing (`QA-PF-*`) | ✅ covered | Core lock/failure paths validated. |
| Drift Awareness (`QA-DA-*`) | ✅ covered | Replay trigger + recovery timing verified. |
| Vibrato (`QA-VB-*`) | ✅ covered | Accepted vs rejected vibrato behavior covered. |
| Relative Pitch (`QA-RP-*`) | ✅ covered | Arithmetic correctness/failure scenarios covered. |
| Group Simulation (`QA-GS-*`) | ✅ covered | Lock/confusion deterministic outcomes covered. |
| Listening & Translation (`QA-LT-*`) | ✅ covered | Note+octave correctness checks covered. |
| Analytics (`QA-AN-*`) | ✅ covered | Metric correctness validated in matrix tests. |
| Progression (`QA-PR-*`) | ✅ covered | Unlock gating and mastery progression covered. |
| Visual determinism (`QA-VD-*`) | ✅ covered | Position/deformation deterministic values asserted. |
| Failure modes (`QA-FM-*`) | ⚠️ partial | Engine-layer deterministic coverage complete; device-native route/focus harness still required for final store release. |

## Commands to run QA checks

From repo root:

```bash
cd apps/mobile_flutter
flutter test test/audio/native_audio_bridge_test.dart
flutter test test/qa/replay_harness_test.dart
flutter test test/qa/qa_matrix_test.dart
flutter test test/qa/drift_snippet_recorder_test.dart
flutter test test/training_engine_test.dart
flutter test test/exercises/progression_engine_test.dart
```

## Trace authoring format

`qa/traces/*.jsonl` must contain one DSP frame JSON object per line:

```json
{"timestamp_ms":0,"freq_hz":null,"midi_float":null,"nearest_midi":null,"cents_error":null,"confidence":0.8,"vibrato":{"detected":false,"rate_hz":null,"depth_cents":null}}
```

Guidelines:

- Keep frame cadence near 5–10 ms.
- Assert deterministic exposed state (avoid visual-only approximations).
- Name fixtures with QA IDs where possible.
