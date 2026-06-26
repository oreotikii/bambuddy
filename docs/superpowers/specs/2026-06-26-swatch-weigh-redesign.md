# Swatch Screen Redesign + Weigh Screen Polish

**Date:** 2026-06-26  
**Files:** `swatch_screen.dart`, `weigh_screen.dart`, `assignment_repository.dart`

---

## Overview

Eight related changes grouped into two files. The swatch screen gets a visual overhaul (compact shade-card grid, richer special-effect rendering, multi-color bug fix, merged material groups, smarter same-color deduplication). The weigh screen moves the color picker to the spool disc, adds material-effect rendering to the disc, and removes the now-redundant `_SwatchColorRow` panel.

---

## A. Multi-color swatch bug fix — `swatch_screen.dart`

**Problem:** `_parseExtraColors` splits the `extra_colors` string but does not strip the `#` prefix before checking token length. A token like `"#e63946"` has length 7, failing the `length == 6` guard, so extra colors are silently dropped.

**Fix:** Add `.replaceAll('#', '')` before the length check in `_parseExtraColors`. Apply the same normalisation to `MobileSpoolDetail.extraColorHexes` getter for consistency (the weigh screen uses that getter).

---

## B. Galaxy / Starlight swatch improvement — `swatch_screen.dart`

**Problem:** `_drawGalaxy` draws 20 fixed white/purple dots regardless of the spool's actual color. Images of real galaxy/starlight filament show dense colored sparkles (80–120 particles) whose hue matches the filament.

**New `_drawGalaxy` behavior:**
- Seed: `math.Random(primaryColor.value)` (deterministic, same color = same pattern).
- Background: unchanged — very dark `0xFF0A0A0F`.
- Sparkle color: `primaryColor` brightened by pushing HSL lightness to ~0.72, full opacity.
- Layer 1 — ~90 small dots (0.4–1.2 px) in brightened primary.
- Layer 2 — ~20 medium dots (0.9–1.8 px) at lightness ~0.88 (near-white tinted by primary hue).
- Layer 3 — 5 "hot sparks" (1.4–2.4 px) near-white (`0xFFEEEEFF`).
- Placement: reject-sample to keep all particles inside the canvas bounds (rect for square chips, circle for the spool disc).

**Series detection:** Add `STARLIGHT` to `_detectSeries` alongside `GALAXY`.

---

## C. PLA+ and PLA PRO merge — `swatch_screen.dart`

PLA PRO is a premium PLA variant indistinguishable visually from PLA+. Users want a single combined section.

- Remove `'PLA PRO'` from `_kSpecialSeries`.
- Remove `'PLA PRO'` from `_kGroupOrder`.
- In `_normalizeGroup()`, before the base-material loop, add: `if (s == 'PLA PRO') return 'PLA+';`

---

## D. Flat tight-grid swatch layout — `swatch_screen.dart`

**Goal:** Replace the current Wrap-of-circles layout with a compact shade-card grid.

### Chip shape
`_SwatchPainter` switches from circle to rectangle:
- Clip: `Path()..addRect(rect)` instead of `addOval`.
- Fill: `canvas.drawRect(rect, ...)` instead of `drawOval`.
- Sector arcs: unchanged — `drawArc` with the same `Rect.fromCircle(center, radius)` origin; the rectangular clip creates the cropped-sector look.
- Galaxy star placement: bounds become the full rect (no circle reject; keep within `[0, size.width] × [0, size.height]`).
- Sheen overlay: `drawRect` instead of `drawOval`.
- **Remove** the outer circle border and inset highlight ring (both `drawCircle` calls at the end of `paint`). Border definition comes from adjacent chip colors.

### `_SwatchChip`
- Drops the `Column` + label + fixed width. Becomes: `GestureDetector → CustomPaint` filling the grid cell.
- Drops the count-badge overlay; total count is shown in the detail modal instead.

### `_MaterialSection` grid
- Replace per-band `Wrap(spacing: 8, runSpacing: 8)` with a single `GridView`:
  ```
  crossAxisCount: 8
  mainAxisSpacing: 0
  crossAxisSpacing: 0
  childAspectRatio: 1.0
  shrinkWrap: true
  physics: NeverScrollableScrollPhysics()
  ```
- Chips are fed to the grid in hue-band order (rainbow, light→dark per band), so the visual progression is preserved without needing explicit row dividers.
- The grid is wrapped in `ClipRRect(borderRadius: BorderRadius.circular(8))` for shade-card outer rounding.
- Section label + count badge above the grid: keep, but tighten bottom padding.
- Divider below each section: keep as-is.

---

## E. Same-color / different-brand deduplication — `swatch_screen.dart`

**Problem:** `_ColorChip` stores only the first spool's `brand` and `name`. When multiple brands share the same hex (e.g., Bambu "Jade White" and Polymaker "Pearl White" are both `#f0ede4`), the chip shows one name and the detail modal is confusing.

**Solution:** Merge by hex (one chip = one color) as now, but track all brand+name variants.

### New `_SpoolVariant`
```dart
class _SpoolVariant {
  const _SpoolVariant({required this.brand, required this.colorName, required this.spoolIds});
  final String? brand;
  final String? colorName;
  final List<int> spoolIds;
}
```

### `_ColorChip` changes
- Remove `name` and `brand` fields.
- Add `List<_SpoolVariant> variants` (guaranteed non-empty).
- Convenience getters:
  - `String? get primaryName => variants.first.colorName;`
  - `int get totalSpools => variants.fold(0, (n, v) => n + v.spoolIds.length);`

### `_buildGroups` changes
Within each hex-key group, sub-group entries by `'${brand ?? ""}::${colorName ?? ""}'` to produce the variant list.

### Detail modal
- Header: large swatch (using `_SwatchPainter` at 56×56) + total spool count + material label.
- Variant rows: for each `_SpoolVariant` show `brand ?? "Unknown brand"`, color name, spool IDs.
- Example:
  ```
  [swatch]  3 spools · PLA+
  
  Bambu Lab
    Jade White  ·  #1  #4
  
  Polymaker
    Pearl White  ·  #7
  ```
- Keep existing `_DetailRow` component; add a section header style for brand names.

---

## F. Color picker as edit icon on spool disc — `weigh_screen.dart`

**Goal:** Remove `_SwatchColorRow` from the "Update spool" panel; move color picking to a camera badge on the spool disc.

### `_SpoolCard` new params
```dart
final Color? pickedColor;
final VoidCallback? onPickColor;
final VoidCallback? onClearColor;
```

### Spool disc `Stack`
Wrap `_SpoolSideView` in a `Stack`:
- Bottom layer: `_SpoolSideView` with `color: pickedColor ?? _filamentColor(spool) ?? cs.primary` — the disc previews the picked color immediately.
- Top-right badge: `Positioned(top: 6, right: 6)` — a 28×28 `InkWell`-wrapped circle (`Color(0xFF18181B)` background, `Color(0xFF3F3F46)` border, `Icons.camera_alt_outlined` at 15px, color `Color(0xFF71717A)`). Tapping calls `onPickColor`.
- If `pickedColor != null`: a 20×20 clear button (`Icons.close` at 11px, `Color(0xFF71717A)`) at `Positioned(top: 6, left: 6)` — opposite corner from the camera badge, no overlap. Tapping calls `onClearColor`.

### `_SwatchColorRow` removal
- Remove the `_SwatchColorRow` widget from the "Update spool" panel's `Column`.
- Remove the `_SwatchColorRow` class definition.

### Call site in `WeighScreenState.build`
Pass `pickedColor: _pickedColor, onPickColor: _pickColorFromCamera, onClearColor: () => setState(() => _pickedColor = null)` to `_SpoolCard`.

---

## G. Material-effect rendering on the spool disc — `weigh_screen.dart`

The `_SpoolSidePainter` gets effect rendering on the wound-filament area. Effects are detected locally (no shared enum needed) from `detail?.effectType` first, then `spool.material`.

### Effect detection helper
```dart
String _spoolEffect(MobileSpoolDetail? detail, MobileSpool spool) {
  final s = '${detail?.effectType ?? ''}${spool.material ?? ''}'.toUpperCase();
  if (s.contains('GALAXY') || s.contains('STARLIGHT')) return 'galaxy';
  if (s.contains('SILK')) return 'silk';
  if (s.contains('METALLIC')) return 'metallic';
  return '';
}
```

### `_SpoolSideView` / `_SpoolSidePainter` new params
- `effect` (String, default `''`)
- `extraColors` (List\<Color\>, default `const []`) for multi-color

### Effect layers (all drawn on the wound-filament disc only, inside the existing `fillR` circle)
| Effect | Rendering |
|--------|-----------|
| `silk` | Diagonal linear gradient (`topLeft → bottomRight`, `transparent → white@40% → transparent`) with `BlendMode.screen` over the fill circle |
| `metallic` | Same gradient at `white@22%` — subtler sheen |
| `galaxy` | 15–20 sparkle dots in brightened `color` scattered within `fillR`; same reject-sample loop as swatch painter |
| multi-color (`extraColors.isNotEmpty`) | The fill circle uses a `SweepGradient` through all colors (primary + extras); fill level ring winding lines stay dark |

Fill-level visualization is unchanged — `fillR` is still computed from `fill.clamp(0,1)`. Effects layer on top of the fill without altering the radii logic.

### Multi-color source
`_SpoolCard` passes `extraColors: _filamentSwatches(spool, detail)` (already computed) and `effect: _spoolEffect(detail, spool)` to `_SpoolSideView`.

---

## Scope explicitly excluded
- No changes to the assign screen or other screens.
- No API changes — data model is read-only from this feature's perspective.
- No changes to the camera color picker flow itself.
- The weigh-screen spool disc does not show count badges or labels.
