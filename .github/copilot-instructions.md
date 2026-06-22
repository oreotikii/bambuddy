# Bambuddy Assign (Flutter) — agent instructions

Full guide: **read `/AGENTS.md` first.**

## Critical scope (do not get this wrong)

This repo owns and maintains **only** the Flutter app at
`apps/filament-assignment-flutter/` (package `assignfilament`).

- ✅ "The app / the UI / redesign / make it consistent" = the **Flutter app**.
  There is no web app or Python backend in this repo.
- ✅ The REST contract the app consumes is documented in **`docs/API.md`** — read
  it before touching any network call. Do not invent endpoints; derive new
  contracts from a running Bambuddy instance (`GET /openapi.json`) and document
  them there.
- ✅ `DESIGN.md` / `PRODUCT.md` are brand/visual-design reference, not Flutter
  implementation specs.

## Quick facts

- **Stack:** Flutter / Dart (`^3.10.0`), Material. Deps: `http`, `crypto`,
  `flutter_secure_storage`, `provider`.
- **Build/run:** `cd apps/filament-assignment-flutter && flutter pub get && flutter run`
- **Verify:** `flutter analyze` (clean) and `flutter test`.
- The base URL is baked via `--dart-define-from-file=baked-config.json`
  (wrappers: `tool/run.sh`, `tool/build.sh`). Operators sign in with Bambuddy
  username/password; credentials and bearer tokens are stored in
  `flutter_secure_storage`. Never commit/echo secrets (real `baked-config.json`
  is gitignored); rotate any exposed Bambuddy account credentials.

See `/AGENTS.md` for the full guide.
