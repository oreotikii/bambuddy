# Bambuddy REST API — Mobile / Flutter Client Reference

This document captures the **REST API surface that the Bambuddy Assign Flutter
app** (`apps/filament-assignment-flutter/`) depends on. It is the authoritative
contract reference now that the upstream Python backend has been removed from
this repo. The app is a client only; the Bambuddy server is deployed separately.

It was derived from the backend route handlers (`mobile_assignment.py`,
`spoolman_inventory.py`, `printers`, `auth`) and the previous Android client's
concrete call sites.

## Conventions

- **Base path:** every endpoint is prefixed with `/api/v1`. The client builds
  URLs as `{base_url}/api/v1{path}` where `base_url` is the user-configured
  Bambuddy instance URL (no trailing slash, no query/fragment — see
  `UrlValidator`).
- **Auth:** every request carries `X-API-Key: <key>`. The key is provisioned in
  Bambuddy → Settings → API Keys and stored locally by the app (or baked into
  the build via `--dart-define=BAMBUDDY_API_KEY`).
- **Headers:** `Accept: application/json`; `Content-Type: application/json` on
  requests with a body.
- **Transport:** 12 s connect/read timeout; redirects are **not** followed.
- **Auth errors:** HTTP `401` / `403` are treated as "unauthorized" and surface
  a re-auth / reconfigure prompt in the app. All other non-2xx raise a generic
  API error carrying the status code and raw body.
- **Errors:** failures return a JSON `detail` object of the shape
  `{ "ok": false, "code": "<CODE>", "message": "...", ... }`. See
  [Error codes](#error-codes).

## Inventory mode

The workflow follows Bambuddy's active inventory mode, resolved server-side
from the instance settings:

| Mode        | Spools resolved from        | Assignments stored in                 |
| ----------- | --------------------------- | ------------------------------------- |
| `local`     | Bambuddy local inventory    | `spool_assignment`                    |
| `spoolman`  | Spoolman server             | `spoolman_slot_assignments`           |

Every spool/slot response includes `inventory_mode` so the client knows which
backend it is operating against.

## AMS / slot addressing

- `ams_id` **0–25** → AMS unit `A`–`Z`.
- `ams_id` **128–191** → AMS HT units.
- `ams_id` **255** → external spool holder (`slot` 0 = the single ext tray).
- `slot` / `tray_id` → **0–3** (the tray index within the unit). The assign
  request accepts either `slot` or `tray_id` (alias).

## QR / code formats

Both printer and spool may be entered by scanning a QR or typing. The codes are
parsed server-side (`resolve-printer` / `resolve-spool`).

**Printer codes**

```
printer:p1s-03
bambuddy-printer:p1s-03
p1s-03
printer:00M09A123456789            (serial number)
```

A numeric value is matched as the printer `id`; otherwise the value is matched
case-insensitively against the printer name or serial number. Zero matches →
`PRINTER_NOT_FOUND`; more than one match → `PRINTER_AMBIGUOUS`.

**Spool codes**

```
spoolman:42
bambuddy-spool:42
spool:42
42
```

The numeric tail is the spool id (local inventory id or Spoolman spool id,
depending on `inventory_mode`).

## Endpoints

### `GET /auth/status`

Instance validation / health probe used during setup. Returns the instance
auth configuration (whether auth is enabled, etc.). A 2xx means the base URL is
a reachable Bambuddy instance.

### `GET /mobile-assignment/resolve-printer?code=<code>`

Resolve a scanned/typed printer code to a printer summary.

**200** — `{ "ok": true, "printer": MobilePrinter }`

`MobilePrinter`

```json
{
  "id": 3,
  "name": "p1s-03",
  "serial_number": "00M09A123456789",
  "model": "P1S",
  "location": null,
  "connected": true,
  "status": "IDLE"
}
```

Errors: `400` (bad code), `404` `PRINTER_NOT_FOUND`, `409` `PRINTER_AMBIGUOUS`.

### `GET /mobile-assignment/resolve-spool?code=<code>`

Resolve a scanned/typed spool code to a spool summary (in the active inventory
mode). Includes the spool's current assignment, if any.

**200** — `{ "ok": true, "spool": MobileSpool }`

`MobileSpool`

```json
{
  "id": 42,
  "inventory_mode": "spoolman",
  "external_spoolman_id": 42,
  "material": "PLA",
  "brand": "Polymaker",
  "vendor": "Polymaker",
  "color_name": "Black",
  "rgba": "000000",
  "remaining_grams": 870.5,
  "label_weight": 1000.0,
  "weight_used": 129.5,
  "current_location": "p1s-03 - AMS A Slot 2",
  "storage_location": "Shelf 1",
  "current_assignment": {
    "printer_id": 3,
    "printer_name": "p1s-03",
    "ams_id": 0,
    "slot": 1,
    "spool_id": 42
  }
}
```

`remaining_grams = max(0, label_weight - weight_used)`. `current_assignment` is
`null` when the spool is not assigned anywhere.

Errors: `400` (bad code), `404` `SPOOL_NOT_FOUND`, `400` `SPOOL_ARCHIVED`,
`502` (Spoolman returned malformed data).

### `GET /mobile-assignment/printer-slots?printer_id=<id>`

List the assignable AMS / external-spool slots for a printer, derived from its
live status, merged with current assignments.

**200** — `MobileSlotsResponse`

```json
{
  "ok": true,
  "printer": { /* MobilePrinter */ },
  "inventory_mode": "spoolman",
  "slots": [ /* MobileSlot[] */ ]
}
```

`MobileSlot`

```json
{
  "printer_id": 3,
  "ams_id": 0,
  "slot": 1,
  "tray_id": 1,
  "label": "A2",
  "unit_name": "AMS A",
  "is_external": false,
  "is_ams_ht": false,
  "occupied": true,
  "physical_occupied": true,
  "assigned_spool_id": 42,
  "assigned_source": "spoolman",
  "current_material": "PLA",
  "current_color": "000000",
  "current_color_name": "Black",
  "state": 0
}
```

- `physical_occupied` — the printer reports filament physically loaded.
- `occupied` — physically loaded **or** assigned in inventory.
- `assigned_spool_id` / `assigned_source` — the inventory assignment, if any.

Errors: `404` `PRINTER_NOT_FOUND`.

### `POST /mobile-assignment/assign`

Assign a spool to a printer slot. Body `MobileAssignRequest`:

```json
{
  "printer_id": 3,
  "spool_id": 42,
  "ams_id": 0,
  "slot": 1,
  "replace_existing": false,
  "move_existing": false
}
```

- `ams_id` ∈ 0–255, `slot` ∈ 0–3 (max 3).
- `replace_existing` — confirm overwriting an existing assignment on the target
  slot (`TARGET_SLOT_OCCUPIED`).
- `move_existing` — confirm moving the spool from another slot
  (`SPOOL_ALREADY_ASSIGNED`). When true, the server first removes the spool's
  other assignments.

**200** — `MobileAssignResponse`

```json
{
  "ok": true,
  "assignment": {
    "printer_id": 3,
    "printer_name": "p1s-03",
    "ams_id": 0,
    "slot": 1,
    "tray_id": 1,
    "slot_label": "A2",
    "spool_id": 42,
    "inventory_mode": "spoolman",
    "location": "p1s-03 - AMS A Slot 2",
    "material": "PLA",
    "color": "000000",
    "configured": null,
    "pending_config": null
  },
  "warnings": [
    "Material mismatch: slot reports PETG, selected spool is PLA."
  ]
}
```

`configured` / `pending_config` are populated only in `local` mode (whether the
slicer config has been pushed / is pending). `warnings` is a list of human
strings (slot physically occupied but unassigned, material mismatch, color
mismatch) — always inspect and surface these to the operator.

Errors: `404` `PRINTER_NOT_FOUND` / `SPOOL_NOT_FOUND` / `TARGET_SLOT_NOT_FOUND`,
`409` `TARGET_SLOT_OCCUPIED` / `SPOOL_ALREADY_ASSIGNED` (confirmable).

### `GET /printers/`

Printer list used by the home/status screen. Returns the printers and their
live status (connected, state). Used to render printer status before the
operator scans a code.

### Spoolman inventory (Spoolman mode)

- `GET /spoolman/inventory/spools` — list spools.
- `GET /spoolman/inventory/spools/{id}` — single spool detail.
- `GET /spoolman/inventory/slot-assignments/all` — all current slot → spool
  assignments across printers.
- `GET /spoolman/status` — `{ enabled, connected, url }`; useful to show whether
  Spoolman is reachable.

### `PATCH /spoolman/inventory/spools/{id}/weigh`

Record a weighing. The client computes the remaining filament locally with
`WeighMath.remainingWeight(measured, tare) = max(0, measured - tare)` and submits
the measured/remaining values; the server applies the same formula and updates
`weight_used` / remaining. `measured` is the full scale reading, `tare` is the
empty-spool weight for that spool's material/brand.

### `POST /printers/{id}/clear-plate` (and equivalents)

Clear-plate / tray actions surfaced from the home screen. Sent as a POST with
no body.

## Error codes

| HTTP | `code`                  | Meaning                                                  | Confirmable via       |
| ---- | ----------------------- | -------------------------------------------------------- | --------------------- |
| 400  | _(various)_             | Malformed code / archived spool (`SPOOL_ARCHIVED`).      | —                     |
| 401  | —                       | Missing/invalid API key.                                 | —                     |
| 403  | —                       | API key lacks the required permission.                   | —                     |
| 404  | `PRINTER_NOT_FOUND`     | No printer matches the code/id.                          | —                     |
| 404  | `SPOOL_NOT_FOUND`       | No spool matches the code/id.                            | —                     |
| 404  | `TARGET_SLOT_NOT_FOUND` | The chosen AMS/slot is not available for this printer.   | —                     |
| 409  | `PRINTER_AMBIGUOUS`     | More than one printer matches; use id or serial.         | —                     |
| 409  | `TARGET_SLOT_OCCUPIED`  | Slot already has a spool assigned.                       | `replace_existing`    |
| 409  | `SPOOL_ALREADY_ASSIGNED`| Spool is assigned to another slot.                       | `move_existing`       |
| 502  | —                       | Spoolman upstream returned malformed data.               | —                     |

Confirmable `409` responses include `can_confirm: true` and a `confirm_field`
name; re-issue the same `POST /assign` with that boolean set to `true` to
proceed.

## Operator flow

1. Resolve a **printer** (`resolve-printer`), or pick one from `/printers/`.
2. Resolve a **spool** (`resolve-spool`).
3. Fetch the printer's **slots** (`printer-slots`).
4. Pick a target slot and **assign** (`assign`).
5. On a confirmable `409`, ask the operator and re-send with the matching
   confirm flag. Always surface any returned `warnings`.

## Notes

- The full upstream Bambuddy API is far larger (auth/MFA, library, firmware,
  cloud, labels, print log, etc.). This app intentionally consumes only the
  assignment workflow above plus basic printer/spool reads. If new features are
  needed, re-derive their contracts from a running Bambuddy instance
  (`GET /openapi.json` is served by the upstream server) rather than guessing.
- The app never handles Spoolman credentials directly; Spoolman is reachable
  only from the Bambuddy server, which proxies all `/spoolman/...` calls.
