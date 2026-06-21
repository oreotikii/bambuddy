# Bambuddy Assign (Flutter)

**Bambuddy Assign** is the internal Flutter app for the SpoolBuddy
filament-assignment workflow: it lets an operator scan a printer, scan a spool,
and assign that spool to an AMS or external-sool slot on a Bambuddy instance.

This repository contains **only the Flutter client** (`apps/filament-assignment-flutter/`).
The Bambuddy server it talks to is deployed separately. The REST contract the
app depends on is documented in [`docs/API.md`](docs/API.md).

## What's in this repo

| Path                              | Purpose                                              |
| --------------------------------- | ---------------------------------------------------- |
| `apps/filament-assignment-flutter/` | The Flutter app (the product this repo owns).      |
| `docs/API.md`                     | REST API contract the app consumes (authoritative). |
| `docs/ams_slot_printer_matrix.txt` | Static AMS slot ↔ printer reference.               |
| `DESIGN.md`, `PRODUCT.md`         | Brand / visual-design reference for the UI.          |
| `AGENTS.md`                       | Working guide for AI coding agents.                  |

## Build & run

Requires Flutter (Dart SDK `^3.10.0`).

```bash
cd apps/filament-assignment-flutter
flutter pub get
flutter run
```

### Baked configuration (optional)

A build can bake the base URL, API key, and/or PIN so a single build works
across shared devices without first-run entry:

```bash
flutter run \
  --dart-define=BAMBUDDY_BASE_URL=https://bambuddy.local \
  --dart-define=BAMBUDDY_API_KEY=bb_... \
  --dart-define=BAMBUDDY_PIN=1234
```

When a value is omitted, the app asks the operator at first run. **Never commit
real secrets** — see [Security](#security).

### Analyze & test

```bash
flutter analyze
flutter test
```

## Security

- API keys, the base URL, and the PIN are stored in `flutter_secure_storage`
  (Android Keystore) — or baked at build time via `--dart-define`.
- `**/local.properties`, `*.keystore`, `*.jks`, `key.properties`, and `.env*`
  are gitignored. Treat the API key like a password; if one is exposed, rotate
  it in Bambuddy → Settings → API Keys.

## License

See [`LICENSE`](LICENSE).
