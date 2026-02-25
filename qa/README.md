# QA Harness

This folder contains deterministic QA assets and guidance for validating `specs/qa.md` scenarios through DSP-frame replay.

## What is implemented

- Deterministic `ReplayHarness` in Flutter domain (`apps/mobile_flutter/lib/qa/replay_harness.dart`) that drives `TrainingEngine` from immutable `DspFrame` streams.
- JSONL trace parser (`ReplayHarness.parseJsonl`) for reusable trace fixtures under `qa/traces`.
- Transition timeline capture (`ReplayTransition`) so tests can assert exact state changes and timing windows, not only final state.
- Shared DSP test-frame factory (`apps/mobile_flutter/test/support/dsp_frame_factory.dart`) to keep replay and engine tests consistent and maintainable.
- Replay-style tests under `apps/mobile_flutter/test/qa/replay_harness_test.dart` for deterministic behavior:
  - low-confidence null-pitch handling (QA-G-01)
  - confidence override (QA-G-02)
  - drift-candidate recovery (QA-DA-01)
  - drift confirmation/replay trigger precondition (QA-DA-02)
  - vibrato acceptance/rejection paths (QA-VB-01 / QA-VB-02)
  - visual determinism scalars (QA-VD-01 / QA-VD-02)
- QA matrix tests under `apps/mobile_flutter/test/qa/qa_matrix_test.dart` covering:
  - PF lock/near-miss/silent-hold failure scenarios (QA-PF-01 / QA-PF-02 / QA-PF-03)
  - DA recovery-time success criteria (QA-DA-03)
  - RP arithmetic correctness/failure (QA-RP-01 / QA-RP-02)
  - GS lock and confusion outcomes (QA-GS-01 / QA-GS-02)
  - LT note and octave validation (QA-LT-01 / QA-LT-02)
  - analytics metric correctness (QA-AN-01 / QA-AN-02)
  - progression unlock gating (QA-PR-01 / QA-PR-02)
  - lifecycle and route interruption behavior (QA-FM-01 / QA-FM-02 at engine-level)

## Coverage status vs `specs/qa.md`

| Section | Status | Notes |
| --- | --- | --- |
| Global sanity (`QA-G-*`) | ✅ covered | G-01/G-02 implemented in replay tests. |
| Pitch Freezing (`QA-PF-*`) | ✅ covered | PF-01/PF-02/PF-03 validated deterministically. |
| Drift Awareness (`QA-DA-*`) | ✅ covered | DA-01/DA-02/DA-03 covered including recovery timing. |
| Vibrato (`QA-VB-*`) | ✅ covered | VB-01/VB-02 deterministic behavior covered. |
| Relative Pitch (`QA-RP-*`) | ✅ covered | RP evaluator + QA matrix cases in place. |
| Group Simulation (`QA-GS-*`) | ✅ covered | Deterministic lock/confusion evaluator tests in place. |
| Listening & Translation (`QA-LT-*`) | ✅ covered | Deterministic note+octave evaluator tests in place. |
| Analytics validation (`QA-AN-*`) | ✅ covered | AN-01/AN-02 validated by deterministic unit tests. |
| Progression/unlock (`QA-PR-*`) | ✅ covered | PR-01/PR-02 mapped explicitly in QA matrix tests. |
| Visual determinism (`QA-VD-*`) | ✅ covered | Pixel mapping and deformation max assertions implemented. |
| Failure modes (`QA-FM-*`) | ⚠️ partial | FM-01/FM-02 covered in engine domain; native route harness remains pending. |

## How to run QA checks

From repo root:

```bash
cd apps/mobile_flutter
flutter test test/qa/replay_harness_test.dart
flutter test test/qa/qa_matrix_test.dart
flutter test test/training_engine_test.dart
flutter test test/exercises/progression_engine_test.dart
```

> If Flutter SDK is unavailable in your environment, run these in CI or on a local machine with Flutter installed.

## Trace authoring format

`qa/traces/*.jsonl` should contain one DSP frame JSON object per line:

```json
{"timestamp_ms":0,"freq_hz":null,"midi_float":null,"nearest_midi":null,"cents_error":null,"confidence":0.8,"vibrato":{"detected":false,"rate_hz":null,"depth_cents":null}}
```

Guidelines:

- Keep frame cadence at ~5–10ms for realistic replay timing.
- Avoid post-processing in UI tests; assert raw deterministic values exposed by `LivePitchUiState`.
- Name fixtures by QA ID where possible (e.g., `qa_g_02_confidence_override.jsonl`).
