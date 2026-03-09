#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

fail=0

PRESENTATION_DIR="apps/mobile_flutter/lib/presentation"
PLUGIN_DIR="packages/pt_audio_plugin"

check_forbidden_imports() {
  local pattern="$1"
  local label="$2"
  if [[ ! -d "$PRESENTATION_DIR" ]]; then
    echo "[FAIL] presentation layer directory '$PRESENTATION_DIR' does not exist"
    fail=1
    return
  fi
  if rg -n "$pattern" "$PRESENTATION_DIR"; then
    echo "[FAIL] presentation layer imports forbidden dependency: $label"
    fail=1
  fi
}

# no placeholder host projects
for placeholder in apps/mobile_flutter/android/README.md apps/mobile_flutter/ios/README.md; do
  if [[ -f "$placeholder" ]]; then
    echo "[FAIL] placeholder host project file exists: $placeholder"
    fail=1
  fi
done

# plugin channel strings must only be in plugin, bridge, tests/docs, and guard itself
if rg -n "pt/audio/control|pt/audio/frames" \
  --glob '!packages/pt_audio_plugin/**' \
  --glob '!apps/mobile_flutter/lib/audio/native_audio_bridge.dart' \
  --glob '!apps/mobile_flutter/test/**' \
  --glob '!README.md' \
  --glob '!packages/pt_audio_plugin/README.md' \
  --glob '!qa/scripts/architecture_guard.sh' \
  .; then
  echo "[FAIL] duplicate plugin channel contract found outside approved files"
  fail=1
fi

# plugin implementation should stay in packages/pt_audio_plugin
if rg -n "PitchTranslatorAudioPlugin|NativeAaudioEngine|pt_audio_engine" \
  --glob '!packages/pt_audio_plugin/**' \
  --glob '!**/build/**' \
  --glob '!**/README.md' \
  --glob '!qa/scripts/architecture_guard.sh' \
  .; then
  echo "[FAIL] plugin implementation appears outside packages/pt_audio_plugin"
  fail=1
fi

check_forbidden_imports "package:shared_preferences/shared_preferences.dart" "shared_preferences"
check_forbidden_imports "package:sqflite/|package:sqflite_common_ffi/" "sqflite"
check_forbidden_imports "package:permission_handler/permission_handler.dart" "permission_handler"
check_forbidden_imports "MethodChannel|EventChannel" "platform channels"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "[PASS] architecture guard checks succeeded"
