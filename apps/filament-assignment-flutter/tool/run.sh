#!/usr/bin/env bash
# Run the app on a connected device/emulator with baked secrets applied
# automatically (no retyping). Requires baked-config.json (gitignored).
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f baked-config.json ]; then
  echo "baked-config.json not found. Copy baked-config.example.json -> baked-config.json and fill it in." >&2
  exit 1
fi

flutter run --dart-define-from-file=baked-config.json "$@"
