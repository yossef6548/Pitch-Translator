# native/ios

This directory is **documentation + validation guidance only**.

## Source-of-truth policy

- Runtime Flutter plugin/native bridge implementation does **not** live here.
- iOS plugin source-of-truth is only `packages/pt_audio_plugin/ios/...`.
- Do not add Swift/ObjC++ plugin classes or duplicate channel handlers under `native/ios`.

## What may live here

- Device validation checklists.
- Integration notes.
- Release hardening docs.

If you need to change runtime iOS plugin behavior, edit `packages/pt_audio_plugin`.
