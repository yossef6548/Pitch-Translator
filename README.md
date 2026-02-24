# Pitch Translator
---

## What this repository is now

✅ **Done in this skeleton**
- Full **monorepo structure** for:
  - Flutter UI app (`/apps/mobile_flutter`)
  - Shared C++ DSP core (`/dsp`)
  - Native audio bridges (`/native/ios`, `/native/android`)
  - QA replay harness scaffolding (`/qa`)
- Deterministic **data contracts** and **module boundaries** as code placeholders
- Build placeholders:
  - CMake for DSP
  - Flutter + FFI wiring stubs
  - CI stubs (lint/build/test placeholders)

🚧 **Still to implement**
- DSP pitch detection + confidence + vibrato detection (C++)
- Native low-latency audio I/O:
  - iOS AVAudioEngine (measurement mode, play+record)
  - Android AAudio/Oboe
- Real training engine state machine in Flutter (per `interaction.md` + constants in `dsp-ui-binding.md`)
- UI rendering (LIVE_PITCH, DRIFT_REPLAY, Home/Train/Analyze/Library/Settings) per `ui-ux.md` + `design-system.md`
- Persistence (SQLite) + analytics computations
- QA harness:
  - DSP frame stream injection
  - Assertions for state transitions + visual math outputs
  - Golden traces from `qa.md`

---

## Repo structure

```text
/specs                        # Specification set (placeholders in this zip)
/apps
  /mobile_flutter             # Flutter app (UI + Training Engine)
/packages
  /pt_contracts               # Shared contracts (Dart) mirroring dsp-ui-binding.md structures
/dsp                          # Shared C++ DSP core (real-time safe)
/native
  /ios                        # iOS native audio + bridge
  /android                    # Android native audio + bridge
/qa
  /traces                     # Sample DSP-frame traces (jsonl)
  /harness                    # QA runner scaffolding
/.github/workflows            # CI placeholders
```

---

## How to start implementing (high-level)

1. Implement DSP core stubs in `/dsp` until you can output deterministic `DSPFrameOutput`.
2. Wire native audio to feed PCM frames into DSP and emit `DSPFrameOutput` to Flutter.
3. Implement the Training Engine reducer in Flutter using:
   - state names from `interaction.md`
   - constants and math from `dsp-ui-binding.md`
4. Implement LIVE_PITCH UI with deterministic bindings.
5. Implement QA harness to replay traces and verify outputs.

---

## Notes on determinism

- UI must be a pure function of:
  - current exercise config
  - the incoming DSP frame stream
  - the Training Engine state machine
- No “helpful” smoothing beyond what specs allow.
- Keep audio-thread work allocation-free and non-blocking.

---
