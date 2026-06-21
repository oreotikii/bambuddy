# AGENTS.md — Bambuddy Assign (Flutter)

Guide for AI coding agents working in this repository. **Read this first.**

## Project scope & ownership

This repository owns and maintains exactly **one** thing:

> ✅ `apps/filament-assignment-flutter/` — the **Bambuddy Assign** Flutter app
> (package `assignfilament`), an internal client for the SpoolBuddy
> filament-assignment workflow.

Everything else in the repo is **reference material**, not the product:

- `docs/API.md` — the **authoritative REST contract** the app consumes. The
  Bambuddy server is deployed **separately**; its source is **not** in this repo.
- `docs/ams_slot_printer_matrix.txt` — static AMS slot ↔ printer reference.
- `DESIGN.md`, `PRODUCT.md` — brand / visual-design language for the UI. These
  describe the *design system*, not Flutter implementation specs.
- `LICENSE` — legal.

### Rules that prevent scope mistakes

- **"The app / the UI / redesign / make it consistent" always means the Flutter
  app** at `apps/filament-assignment-flutter/`. There is no web app and no
  Python backend in this repo.
- **Do not invent server endpoints.** When a feature needs new API surface,
  derive the contract from a running Bambuddy instance
  (`GET /openapi.json`) and document it in `docs/API.md` before coding the
  client.
- The app must stay **compatible with the standard Bambuddy REST API** (same
  endpoints, same SpoolBuddy/filament-assignment workflow). It is an
  **independent internal tool** following this company's own process, not a
  wrapper around any web UI.

## The Flutter app

- **Stack:** Flutter / Dart (`sdk: ^3.10.0`), Material. Key deps: `http`,
  `crypto`, `flutter_secure_storage`, `provider`.
- **Build/verify** (from `apps/filament-assignment-flutter/`):
  ```bash
  flutter pub get
  flutter run                     # run (optionally with --dart-define, below)
  flutter analyze                 # static analysis
  flutter test                    # unit tests
  ```
- **Configuration:** base URL + API key + optional PIN. Either stored locally
  (`flutter_secure_storage`, Android Keystore) or **baked** at build time:
  ```bash
  flutter run \
    --dart-define=BAMBUDDY_BASE_URL=https://bambuddy.local \
    --dart-define=BAMBUDDY_API_KEY=bb_... \
    --dart-define=BAMBUDDY_PIN=1234
  ```
  Empty define = "not baked"; the app prompts the operator instead. See
  `lib/src/config/app_config.dart`.
- **App structure** under `apps/filament-assignment-flutter/lib/`:
  - `main.dart` — entry; `MaterialApp` + `provider` `AppModel`, routes via an
    `AppGate` (splash → setup → pin → main).
  - `src/data/api_client.dart` — async HTTP client for `/api/v1`; attaches
    `X-API-Key`; 401/403 → `ApiException.isUnauthorized`.
  - `src/data/session_store.dart` — secure storage of base URL, API key, and the
    PIN (stored as a salted SHA-256 hash).
  - `src/core/` — `url_validator.dart`, `weigh_math.dart`, `api_exception.dart`.
  - `src/app/`, `src/ui/` — theme, app model, screens.
- **API reference:** [`docs/API.md`](docs/API.md). Read it before touching any
  network call. The endpoints actually used: `auth/status`,
  `mobile-assignment/{resolve-printer,resolve-spool,printer-slots,assign}`,
  `printers/`, `spoolman/inventory/{spools,spools/{id}/weigh,slot-assignments/all}`.

## Security

- Secrets (API key, base URL, PIN) live in `flutter_secure_storage` or are baked
  via `--dart-define`. **Never commit** `local.properties`, `*.keystore`,
  `*.jks`, `key.properties`, or `.env*` (all gitignored).
- **Never echo secret values into output or transcripts.** If a secret was
  exposed in a transcript, recommend rotating the API key in Bambuddy → Settings
  → API Keys.
- The PIN is stored only as a salted SHA-256 hash; never store or log the raw
  digits.

## Working conventions

- Before declaring a change done: run `flutter analyze` (clean) and
  `flutter test`.
- Match the existing Dart style (effective_dart / flutter_lints); no comments
  unless asked.
- Update `docs/API.md` whenever you change which endpoints the app calls or the
  shapes it depends on.
- Only stage/commit when explicitly asked.
