# QA Harness

This folder contains deterministic QA assets and guidance for validating `specs/qa.md` scenarios through DSP-frame replay.

## What is implemented

- Deterministic `ReplayHarness` in Flutter domain (`apps/mobile_flutter/lib/qa/replay_harness.dart`) that drives `TrainingEngine` from immutable `DspFrame` streams.
- JSONL trace parser (`ReplayHarness.parseJsonl`) for reusable trace fixtures under `qa/traces`.
- Replay-style tests under `apps/mobile_flutter/test/qa/replay_harness_test.dart` for critical ship-blocking behavior:
  - low-confidence null-pitch handling (QA-G-01)
  - confidence override (QA-G-02)
  - drift-candidate recovery (QA-DA-01)
  - vibrato acceptance/rejection paths (QA-VB-01 / QA-VB-02)
  - visual determinism scalars (QA-VD-01 / QA-VD-02)

## Coverage status vs `specs/qa.md`

| Section | Status | Notes |
| --- | --- | --- |
| Global sanity (`QA-G-*`) | ✅ partial | G-01/G-02 covered by replay tests. |
| Pitch Freezing (`QA-PF-*`) | ⚠️ partial | Lock acquisition covered; near-miss and silent-hold failure need dedicated traces. |
| Drift Awareness (`QA-DA-*`) | ⚠️ partial | DA-01 covered; DA-02/DA-03 still require replay/timing assertions tied to UI replay flow. |
| Vibrato (`QA-VB-*`) | ✅ partial | VB-01/VB-02 deterministic engine behavior covered. |
| Relative Pitch / Group / Listening | ❌ pending | Requires additional exercise-mode logic not yet fully implemented in replay suite. |
| Analytics validation (`QA-AN-*`) | ⚠️ partial | Existing analytics queries exist, but QA-labeled deterministic fixtures are pending. |
| Progression/unlock (`QA-PR-*`) | ⚠️ partial | Progression unit tests exist separately; need direct QA-ID mapping. |
| Visual determinism (`QA-VD-*`) | ✅ partial | Pixel mapping and deformation max assertions implemented. |
| Failure modes (`QA-FM-*`) | ❌ pending | App lifecycle/audio-route integration tests pending (native + Flutter integration harness). |

## How to run QA checks

From repo root:

```bash
cd apps/mobile_flutter
flutter test test/qa/replay_harness_test.dart
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
