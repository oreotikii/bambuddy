# CRAV3D Assist

Flutter client (`assignfilament`) for the SpoolBuddy filament-assignment
workflow: scan a printer → scan a spool → assign the spool to an AMS or
external slot on a Bambuddy instance.

This is the only product in this repo. For project scope, repo history, and the
authoritative REST contract, see the repo root:

- [`/README.md`](../../README.md) — project overview.
- [`/AGENTS.md`](../../AGENTS.md) — working guide for AI agents (read first).
- [`/docs/API.md`](../../docs/API.md) — REST contract the app consumes.

## Requirements

- Flutter, Dart SDK `^3.10.0`.

## Build & run

```bash
flutter pub get
flutter run                 # run on a connected device/emulator
```

### Baked configuration

The server URL is baked into the app. To override the default URL for staging or
another internal instance, put it in a gitignored `baked-config.json` and apply
it with `--dart-define-from-file`:

```bash
cp baked-config.example.json baked-config.json   # then fill in real values
tool/run.sh                 # flutter run  --dart-define-from-file=baked-config.json
tool/build.sh               # flutter build apk --release --dart-define-from-file=...
tool/build.sh ios           # flutter build ios --release --dart-define-from-file=...
```

`baked-config.json` is gitignored. Operators sign in with their Bambuddy
username and password; credentials are stored in platform secure storage for
silent token renewal (`lib/src/config/app_config.dart`).

In VS Code, the **"CRAV3D Assist (baked config)"** launch config applies the
file automatically. Individual `--dart-define=BAMBUDDY_*` flags also work inline.

## Verify

```bash
flutter analyze             # static analysis (must be clean)
flutter test                # unit tests
```

## Layout

```
lib/
  main.dart                 # entry; MaterialApp + AppModel, AppGate routing
  src/
    app/                    # app model, theme
    config/                 # build-time baked config
    core/                   # url validator, weigh math, API exception
    data/                   # api client (Bearer token), secure session store
    ui/                     # splash / login / lock / main screens
```

See [`/docs/API.md`](../../docs/API.md) for the endpoints this app calls.
