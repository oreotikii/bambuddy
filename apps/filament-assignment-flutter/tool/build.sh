#!/usr/bin/env bash
# Build a release app with baked secrets applied automatically (no retyping).
# Requires baked-config.json (gitignored).
#
# Usage:
#   tool/build.sh              # Android APK (default)
#   tool/build.sh apk          # Android APK
#   tool/build.sh ios          # iOS app archive build
#   tool/build.sh ios --no-codesign
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f baked-config.json ]; then
  echo "baked-config.json not found. Copy baked-config.example.json -> baked-config.json and fill it in." >&2
  exit 1
fi

target="apk"
if [ "$#" -gt 0 ]; then
  case "$1" in
    android|apk)
      target="apk"
      shift
      ;;
    ios)
      target="ios"
      shift
      ;;
  esac
fi

flutter build "$target" --release --dart-define-from-file=baked-config.json "$@"
