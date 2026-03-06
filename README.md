# Pitch Translator

Pitch Translator is organized around a **single native plugin implementation path**.

## Repository ownership model

- `apps/mobile_flutter` → product Flutter app.
- `apps/mobile_flutter/android` and `apps/mobile_flutter/ios` → committed Flutter host projects (tracked in-repo when generated in a Flutter-enabled environment).
- `packages/pt_audio_plugin` → **only** Flutter native bridge/plugin implementation.
- `packages/pt_contracts` → shared protocol/contracts/constants DTO surface only.
- `dsp` → portable C++ DSP.
- `native/` → documentation, checklists, and release validation guidance only (no plugin source-of-truth).

## Where real plugin code lives

The canonical plugin/native bridge code is only in:

- `packages/pt_audio_plugin/android/src/main/...`
- `packages/pt_audio_plugin/ios/...`

Any `native/android` and `native/ios` content is documentation/support material and must not contain a second runtime implementation.

## Build and validation

### Flutter app

From `apps/mobile_flutter`:

```bash
flutter pub get
flutter test
flutter build apk
flutter build ios --no-codesign
```

### DSP

From `dsp`:

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build
```

### Architecture guards

```bash
bash qa/scripts/architecture_guard.sh
```

This guard checks for forbidden presentation-layer imports and duplicate plugin channel strings outside approved paths.
