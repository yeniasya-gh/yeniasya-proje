#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFINES_FILE="${DEFINES_FILE:-$ROOT_DIR/tool/dart_defines.example.json}"

if [[ ! -f "$DEFINES_FILE" ]]; then
  echo "Missing defines file: $DEFINES_FILE" >&2
  echo "Create: $ROOT_DIR/tool/dart_defines.example.json" >&2
  exit 1
fi

cd "$ROOT_DIR"
flutter run --dart-define-from-file="$DEFINES_FILE" "$@"
