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
- Config (base URL / API key / PIN) is stored in `flutter_secure_storage` or
  baked via `--dart-define=BAMBUDDY_*`. Never commit/echo secrets; rotate any
  exposed API key in Bambuddy → Settings → API Keys.

See `/AGENTS.md` for the full guide.
