# Swatch Screen — Special Series Visual Rendering

**Date:** 2026-06-25  
**Status:** Approved  
**Scope:** `apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart`

> **Amendment 2026-06-25:** Added 2D hue-matrix chip layout (rainbow vertically, light→dark horizontally) to replace the flat `Wrap` layout.

---

## Overview

Enhance the swatch screen to visually distinguish special filament series and split the material sections by series. The changes are self-contained within `swatch_screen.dart`.

**Series in scope:**
- **PLA SILK** — metallic sheen overlay (single and multi-color)
- **PLA METALLIC** — metallic sheen overlay (same treatment as SILK, softer stripe)
- **PLA GALAXY** — black base with seeded random star dots
- **Multi-color** — split pie sectors (any series)
- **PLA MATTE** — grouped separately, no special paint effect (not requested)

---

## 1. Data Layer

### 1.1 New enum

```dart
enum _SpoolSeries { standard, silk, metallic, galaxy, matte }
```

Inferred from the `material` string (uppercase comparison):
| Contains | Series |
|----------|--------|
| `SILK`   | `silk` |
| `METALLIC` | `metallic` |
| `GALAXY` | `galaxy` |
| `MATTE`  | `matte` |
| otherwise | `standard` |

### 1.2 Multi-color detection

Read `sp['extra_colors']` from the raw list response (`GET /spoolman/inventory/spools`). This is the same field exposed by `MobileSpoolDetail`. Split on `RegExp(r'[,;\s|]+')` to get individual hex tokens.

- Primary color: `sp['rgba']` (existing field)
- Extra colors: `sp['extra_colors']` → `List<String>` of hex tokens

**Important:** Multi-color spools in Spoolman have `rgba` = `""` (empty) and carry all colors in `extra_colors`. The current code skips spools with a null/empty hex. The new logic must handle this:

1. Parse `extra_colors` first.
2. If `rgba` is empty but `extraHexes` is non-empty, use `extraHexes[0]` as the primary hex and `extraHexes[1..]` as the remaining extras.
3. Only skip a spool if **both** `rgba` and `extra_colors` are absent/empty.

### 1.3 Chip grouping key for multi-color

Currently chips are grouped by primary hex (`byHex[s.hex]`). For multi-color spools the effective key must include all colors so that "Black-Gold" and a hypothetical "Black-Red" are not merged:

```
key = [primaryHex, ...extraHexes].join('+')   // e.g. "111111+d4af37"
```

Single-color spools use just their hex as the key (backward-compatible).

### 1.4 Model changes

`_SpoolEntry` gains:
```dart
final _SpoolSeries series;
final List<String> extraHexes; // empty for single-color
```

`_ColorChip` gains:
```dart
final _SpoolSeries series;
final List<String> extraHexes;
```

`_buildGroups` reads both new fields from each raw spool map.

---

## 2. Grouping

### 2.1 `_normalizeGroup` change

Current behaviour: collapses any material containing a base keyword (`PLA`, `PETG`, etc.) into that base string.

New behaviour: special series strings are **preserved exactly** as their own group labels. Base materials continue to be normalized.

Detection order (longer/more-specific first to prevent partial matches):
```
PLA GALAXY, PLA METALLIC, PLA SILK, PLA MATTE, PLA PRO,
PETG, PLA+, PLA,
ABS, ASA, TPU, PEEK, HIPS, PVA, PC, PA
```

If a material matches one of the special-series strings exactly (case-insensitive), it becomes its own label. Otherwise fall through to the existing base-material logic.

### 2.2 Section ordering

```dart
const _kGroupOrder = [
  'PLA+', 'PLA PRO', 'PLA',
  'PLA SILK', 'PLA METALLIC', 'PLA MATTE', 'PLA GALAXY',
  'PETG', 'ABS', 'ASA', 'TPU', 'PA', 'PC', 'PEEK', 'PVA', 'HIPS',
];
```

Groups not in the list sort alphabetically after the ordered entries.

---

## 3. Visual Rendering — `_SwatchPainter`

Replace the `Container` in `_SwatchChip` with a `CustomPaint(painter: _SwatchPainter(...))` sized 42×42. A `Stack` keeps the count badge `Text` widget on top.

### Constructor

```dart
_SwatchPainter({
  required Color primaryColor,
  required List<Color> extraColors,  // empty for single-color
  required _SpoolSeries series,
  required double radius,            // 21.0 for the 42px chip
})
```

### 3.1 Standard

Fill the circle with `primaryColor`. Draw the border on top. No special overlay.

### 3.2 Multi-color (2+ colors)

All colors = `[primaryColor, ...extraColors]`.

- **2 colors**: two 180° arc sectors, split left/right (start angles: π/2 and 3π/2 using `canvas.drawArc` with `useCenter: true`).
- **3+ colors**: N equal sectors of `360°/N` each, starting from the top (−π/2).

Draw border ring on top of sectors.

If the spool is both multi-color AND silk/metallic, the sheen overlay (§3.3) is applied after sectors are drawn.

### 3.3 Silk sheen

After filling the base color(s):

```
LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Colors.transparent,
    Colors.white.withValues(alpha: 0.45),
    Colors.transparent,
  ],
  stops: [0.25, 0.50, 0.75],
)
```

Paint this gradient over the circle using `BlendMode.screen`, clipped to the circle path. This produces a bright diagonal sheen.

### 3.4 Metallic sheen

Identical to silk but with `alpha: 0.28` and `stops: [0.20, 0.50, 0.80]` (wider, softer stripe).

### 3.5 Galaxy

1. Fill circle with `Color(0xFF0A0A0F)` (near-black with slight blue tint).
2. Seed a `math.Random` with the integer value of the primary color hex so stars are deterministic per spool.
3. Paint 20 star dots:
   - 16 white/cream (`Color(0xFFE8E8FF)`) at radius 0.8–1.6px
   - 4 pale lavender (`Color(0xFFCCBBFF)`) at radius 1.2–2.2px
   - Positions: random `(x, y)` within the circle (reject-sample outside radius)
4. Draw border on top.

---

## 4. Chip Layout — Hue Matrix

Replace the `Wrap` inside `_MaterialSection` with a **2D color matrix**:
- **Vertical axis (rows):** hue bands in rainbow order
- **Horizontal axis (within each row):** lightness, light on the left → dark on the right

### 4.1 Hue bands

Nine named bands plus a neutral catch-all, keyed by HSV hue angle:

| Band | Hue range | Notes |
|------|-----------|-------|
| Red | 330°–360° and 0°–20° | wraps around 0° |
| Orange | 20°–50° | |
| Yellow | 50°–80° | |
| Green | 80°–160° | |
| Teal | 160°–200° | |
| Blue | 200°–260° | |
| Purple | 260°–300° | |
| Pink | 300°–330° | |
| Neutral | any hue, HSV saturation < 15% | greys, whites, blacks |

Neutral is checked first (before hue range) so that near-white and near-black colours with an incidental hue tint don't pollute the colour rows.

### 4.2 Row ordering

Rows appear in the order: Red → Orange → Yellow → Green → Teal → Blue → Purple → Pink → Neutral. Empty bands are skipped entirely.

### 4.3 Within-row sort: light → dark

Sort chips inside each row by **HSL lightness descending** (highest L first = lightest on the left). For multi-color chips, compute lightness from the primary color only.

### 4.4 Layout widget

```
Column(
  children: [
    for (final band in nonEmptyBands)
      Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            for (final chip in band.chips)
              Padding(padding: EdgeInsets.only(right: 8), child: _SwatchChip(...)),
          ],
        ),
      ),
  ],
)
```

No horizontal scrolling — the row wraps are removed. If a single row exceeds the screen width (unlikely given chip sizes), a `SingleChildScrollView` can be added per row, but this is not expected in practice.

### 4.5 Flat-sort removal

The `..sort(_byHue)` call on each group's chip list in `_buildGroups` is removed. Sorting is now entirely handled by `_buildHueBands` at render time inside `_MaterialSection`.

---

## 5. Detail Modal

For multi-color chips, replace the single `Color hex` row with multiple rows:
- `Color 1` — `#primaryHex`
- `Color 2` — `#extraHex1`
- etc.

(Single-color chips unchanged.)

---

## 6. File Scope

All changes are within `apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart`. No new files, no new dependencies.

---

## 7. Out of Scope

- Backend changes — the design assumes `extra_colors` is already present in the list endpoint response. If it turns out to be absent, fall back gracefully (treat as single-color) and note as a follow-up.
- PLA MATTE special paint effect — grouped separately but rendered the same as standard.
- Any other screen (assign, weigh, home) — untouched.
