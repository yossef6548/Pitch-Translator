#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT_DIR"

fail=0

check_forbidden_imports() {
  local pattern="$1"
  local label="$2"
  if rg -n "$pattern" apps/mobile_flutter/lib/presentation; then
    echo "[FAIL] presentation layer imports forbidden dependency: $label"
    fail=1
  fi
}

# 1) channel strings must only be in plugin + bridge + tests/docs
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

# 2-4) no storage/platform imports in presentation layer
check_forbidden_imports "package:shared_preferences/shared_preferences.dart" "shared_preferences"
check_forbidden_imports "package:sqflite/|package:sqflite_common_ffi/" "sqflite"
check_forbidden_imports "MethodChannel|EventChannel" "platform channels"

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "[PASS] architecture guard checks succeeded"
