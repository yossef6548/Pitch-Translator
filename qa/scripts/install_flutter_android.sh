#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-/opt/flutter}"
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
ANDROID_API="${ANDROID_API:-36}"
AVD_API="${AVD_API:-$ANDROID_API}"
AVD_NAME="${AVD_NAME:-PitchTranslatorAVD}"

if [[ ! -d "$FLUTTER_DIR" ]]; then
  git clone --depth 1 --single-branch -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"

mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
TMP_ZIP="/tmp/commandlinetools-linux-latest.zip"
if [[ ! -f "$TMP_ZIP" ]]; then
  curl --fail --show-error --location --retry 3 --retry-delay 5 -o "$TMP_ZIP" https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
fi
if [[ ! -d "$ANDROID_SDK_ROOT/cmdline-tools/latest" ]]; then
  pushd /tmp >/dev/null
  unzip -q -o "$TMP_ZIP"
  mv -f cmdline-tools "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  popd >/dev/null
fi

set +o pipefail
yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null
set -o pipefail
sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
  "platform-tools" \
  "platforms;android-${ANDROID_API}" \
  "build-tools;${ANDROID_API}.0.0" \
  "build-tools;28.0.3" \
  "emulator" \
  "system-images;android-${AVD_API};google_apis;x86_64"

if ! avdmanager list avd | grep -F -q -- "$AVD_NAME"; then
  echo no | avdmanager create avd -n "$AVD_NAME" -k "system-images;android-${AVD_API};google_apis;x86_64" -d pixel_6
fi

flutter doctor -v
