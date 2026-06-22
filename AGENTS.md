# AGENTS.md — Bambuddy Assign (Flutter)

Guide for AI coding agents working in this repository. **Read this first.**

## Project scope & ownership

This repository owns and maintains exactly **one** thing:

> ✅ `apps/filament-assignment-flutter/` — the **Bambuddy Assign** Flutter app
> (package `assignfilament`), an internal iOS and Android client for the SpoolBuddy
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

## Repository history & remotes

This repo is a **trimmed fork of upstream Bambuddy**. On 2026-06-21 all upstream
server/web content (Python `backend/`, React `frontend/`, `static/` build,
`gcode_viewer/`, `spoolbuddy/`, `slicer-api/`, docker/python tooling, upstream
docs/meta) **and the deprecated Java Android app** were deleted and purged from
git history. That source is intentionally absent — `.git` is small by design —
and the REST contract the app depends on is captured in `docs/API.md`.

- **`origin`** → `github.com/oreotikii/bambuddy` (our fork). This is the **only**
  remote you may push or force-push to.
- **`upstream`** → `github.com/maziggy/bambuddy` (the original project).
  **Reference only — fetch only. Never push to `upstream`.**
- **History was rewritten once, so every commit hash changed.** Do **not**
  `merge`, `pull`, or `rebase` from `upstream` into this repo — it would
  re-introduce the removed, unrelated history. To adopt an upstream change, read
  it from upstream and reimplement it, or cherry-pick the specific diff by hand.
- Because of the rewrite, **any existing clone is stale**; contributors must
  re-clone. Publishing the rewritten branch requires
  `git push --force-with-lease origin main` (normal pushes are rejected).

## The Flutter app

- **Stack:** Flutter / Dart (`sdk: ^3.10.0`), Material. Key deps: `http`,
  `crypto`, `flutter_secure_storage`, `provider`, `mobile_scanner`.
- **Build/verify** (from `apps/filament-assignment-flutter/`):
  ```bash
  flutter pub get
  flutter run                     # run (optionally with --dart-define, below)
  flutter analyze                 # static analysis
  flutter test                    # unit tests
  ```
- **Configuration:** the server base URL is **baked** at build time. Operators
  sign in with Bambuddy username/password; credentials and the bearer token are
  stored locally in `flutter_secure_storage` (Android Keystore / iOS Keychain).
  The recommended pattern is a gitignored `baked-config.json` applied with
  `--dart-define-from-file` (there are `tool/run.sh` and `tool/build.sh`
  wrappers, and a VS Code "Bambuddy Assign (baked config)" launch config):
  ```bash
  cp baked-config.example.json baked-config.json   # fill in real values
  tool/run.sh        # == flutter run  --dart-define-from-file=baked-config.json
  tool/build.sh      # == flutter build apk --release --dart-define-from-file=...
  tool/build.sh ios  # == flutter build ios --release --dart-define-from-file=...
  ```
  See `lib/src/config/app_config.dart` and `baked-config.example.json`.
- **App structure** under `apps/filament-assignment-flutter/lib/`:
  - `main.dart` — entry; `MaterialApp` + `provider` `AppModel`, routes via an
    `AppGate` (splash → login → locked → main).
  - `src/data/api_client.dart` — async HTTP client for `/api/v1`; attaches
    `Authorization: Bearer <token>`; 401 refreshes by re-login once.
  - `src/data/session_store.dart` — secure storage of username, password, and
    the cached access token.
  - `src/core/` — `url_validator.dart`, `weigh_math.dart`, `api_exception.dart`.
  - `src/app/`, `src/ui/` — theme, app model, screens.
- **API reference:** [`docs/API.md`](docs/API.md). Read it before touching any
  network call. The endpoints actually used: `auth/login`,
  `mobile-assignment/{resolve-printer,resolve-spool,printer-slots,assign}`,
  `printers/`, `spoolman/inventory/{spools,spools/{id},spools/{id}/weigh,slot-assignments/all}`.

## Security

- Secrets (username/password/access token) live in `flutter_secure_storage`; the
  base URL is baked via `--dart-define-from-file=baked-config.json`. **Never commit** the real
  `baked-config.json`, `local.properties`, `*.keystore`, `*.jks`,
  `key.properties`, or `.env*` (all gitignored — only `baked-config.example.json`
  is tracked).
- **Never echo secret values into output or transcripts.** If a secret was
  exposed in a transcript, recommend rotating the affected Bambuddy account
  credentials.

## Working conventions

- Before declaring a change done: run `flutter analyze` (clean) and
  `flutter test`.
- Match the existing Dart style (effective_dart / flutter_lints); no comments
  unless asked.
- Update `docs/API.md` whenever you change which endpoints the app calls or the
  shapes it depends on.
- Only stage/commit when explicitly asked.
