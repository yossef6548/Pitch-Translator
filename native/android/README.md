# native/android

This directory is **documentation + validation guidance only**.

## Source-of-truth policy

- Runtime Flutter plugin/native bridge implementation does **not** live here.
- Android plugin source-of-truth is only `packages/pt_audio_plugin/android/src/main/...`.
- Do not add `PitchTranslatorAudioPlugin`, channel wiring, or AAudio bridge classes under `native/android/src/main`.

## What may live here

- Device validation checklists.
- Integration notes.
- Release hardening docs.

If you need to change runtime Android plugin behavior, edit `packages/pt_audio_plugin`.
