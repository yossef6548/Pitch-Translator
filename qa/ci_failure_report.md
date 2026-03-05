# CI failure report: Android APK and iOS builds

## What was reproduced locally

### Android job (`flutter build apk --release`)
Local reproduction in `apps/mobile_flutter` fails with:

```
[!] Your app is using an unsupported Gradle project.
```

The repo's Flutter app folder currently has only Dart sources/tests and no `android/` platform project checked in. Without `android/`, Flutter cannot run `flutter build apk`.

### iOS job (`flutter build ios --release --no-codesign`)
The workflow attempts a native iOS build, but there is no `ios/` platform project in `apps/mobile_flutter`. On CI this will fail for the same reason: no generated iOS host project exists to build.

## Why CI fails

The CI workflow directly runs native build steps:

- Android: `flutter build apk --release`
- iOS: `flutter build ios --release --no-codesign`

Those commands require `apps/mobile_flutter/android` and `apps/mobile_flutter/ios` to exist.

## Recommended fixes

Pick one of these approaches:

1. **Commit generated host projects**
   - Run `flutter create .` from `apps/mobile_flutter`.
   - Keep/merge generated `android/` and `ios/` directories.
   - Re-run CI.

2. **Generate host projects during CI before building**
   - Add a step before build commands:
     - `flutter create --platforms=android,ios .`
   - Then run build commands.

3. **If native builds are not required yet, gate jobs**
   - Temporarily skip Android/iOS jobs until platform folders are intentionally introduced.

## Additional observation

`flutter test` currently fails on unresolved test references (e.g., `ExerciseConfigScreen`, `DriftReplaySheet`, `LibraryScreen`). The existing CI already excludes selected tests in the Flutter test job, which is consistent with this current state.
