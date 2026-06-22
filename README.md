# Bambuddy Assign (Flutter)

**Bambuddy Assign** is the internal Flutter app for the SpoolBuddy
filament-assignment workflow: it lets an operator scan a printer, scan a spool,
and assign that spool to an AMS or external-spool slot on a Bambuddy instance.

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

### Baked configuration

A build bakes the Bambuddy base URL so a single build targets the correct
internal instance. The recommended way to override the default URL is a
gitignored `baked-config.json` applied with `--dart-define-from-file`:

```bash
cd apps/filament-assignment-flutter
cp baked-config.example.json baked-config.json   # then fill in real values
flutter run   --dart-define-from-file=baked-config.json
```

Wrappers inside the app apply the file automatically (and fail fast if it's
missing):

```bash
tool/run.sh      # == flutter run --dart-define-from-file=baked-config.json
tool/build.sh        # == flutter build apk --release --dart-define-from-file=...
tool/build.sh ios    # == flutter build ios --release --dart-define-from-file=...
```

In VS Code, the **"Bambuddy Assign (baked config)"** launch config applies the
file automatically. You can also pass `--dart-define=BAMBUDDY_BASE_URL=...`
inline if you prefer.

### Analyze & test

```bash
flutter analyze
flutter test
```

## Security

- The Bambuddy username, password, and bearer token are stored in
  `flutter_secure_storage` (Android Keystore / iOS Keychain). The base URL is
  baked at build time via `--dart-define-from-file=baked-config.json` (wrappers:
  `tool/run.sh`, `tool/build.sh`).
- `baked-config.json`, `**/local.properties`, `*.keystore`, `*.jks`,
  `key.properties`, and `.env*` are gitignored (only `baked-config.example.json`
  is tracked). Treat stored credentials like passwords; if one is exposed,
  rotate the affected Bambuddy account credentials.

## License

See [`LICENSE`](LICENSE).
