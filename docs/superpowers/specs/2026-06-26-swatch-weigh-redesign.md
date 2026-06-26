# Swatch Screen Redesign + Weigh Screen Polish

**Date:** 2026-06-26
**Files changed:** `swatch_screen.dart`, `weigh_screen.dart`, `assignment_repository.dart`
**Tests changed:** `swatch_screen_test.dart`

---

## Quick-reference change index

| ID | File | What changes |
|----|------|--------------|
| A | `swatch_screen.dart` + `assignment_repository.dart` | Strip `#` from extra-color hex tokens |
| B | `swatch_screen.dart` | Galaxy painter uses spool color; STARLIGHT detection |
| C | `swatch_screen.dart` | PLA PRO maps to PLA+ |
| D | `swatch_screen.dart` | Flat 8-column square tight grid, no chip labels |
| E | `swatch_screen.dart` | Same-color/different-brand variant tracking in detail modal |
| F | `weigh_screen.dart` | Color picker becomes camera badge on spool disc; remove `_SwatchColorRow` |
| G | `weigh_screen.dart` | Silk/metallic/galaxy/multi-color effects on spool disc |

Apply in order A → G. Each section gives the exact existing code to delete, the exact replacement, and the rationale.

---

## A. Fix `#`-prefixed extra-color hex parsing

### Root cause

Both parsers split the raw string then filter tokens by character length. A token like `"#e63946"` is 7 characters, failing the `length == 6` guard, so all `#`-prefixed extra colors are silently dropped.

### A1 — `swatch_screen.dart` › `_parseExtraColors`

**Locate** the function at the bottom of the file (currently last function before `_buildHueBands`):

```dart
// BEFORE
List<String> _parseExtraColors(dynamic raw) {
  if (raw is! String || raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'[,;\s|]+'))
      .map((t) => t.trim().toLowerCase())
      .where((t) => t.length == 6 || t.length == 8)
      .map((t) => t.length == 8 ? t.substring(0, 6) : t)
      .toList(growable: false);
}
```

```dart
// AFTER — add .replaceAll('#', '') inside the first .map()
List<String> _parseExtraColors(dynamic raw) {
  if (raw is! String || raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'[,;\s|]+'))
      .map((t) => t.trim().toLowerCase().replaceAll('#', ''))
      .where((t) => t.length == 6 || t.length == 8)
      .map((t) => t.length == 8 ? t.substring(0, 6) : t)
      .toList(growable: false);
}
```

### A2 — `assignment_repository.dart` › `MobileSpoolDetail.extraColorHexes`

**Locate** the getter inside the `MobileSpoolDetail` class:

```dart
// BEFORE
List<String> get extraColorHexes {
  final raw = extraColors;
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'[,;\s|]+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList(growable: false);
}
```

```dart
// AFTER — strip #, filter by length, trim 8-char tokens to 6
List<String> get extraColorHexes {
  final raw = extraColors;
  if (raw == null || raw.trim().isEmpty) return const [];
  return raw
      .split(RegExp(r'[,;\s|]+'))
      .map((t) => t.trim().replaceAll('#', ''))
      .where((t) => t.length == 6 || t.length == 8)
      .map((t) => t.length == 8 ? t.substring(0, 6) : t)
      .toList(growable: false);
}
```

---

## B. Galaxy painter — use spool primary color; detect STARLIGHT

### B1 — `swatch_screen.dart` › `_detectSeries`

**Locate** the function near the bottom of the file:

```dart
// BEFORE
_SpoolSeries _detectSeries(String? material) {
  final s = (material ?? '').toUpperCase();
  if (s.contains('SILK')) return _SpoolSeries.silk;
  if (s.contains('METALLIC')) return _SpoolSeries.metallic;
  if (s.contains('GALAXY')) return _SpoolSeries.galaxy;
  if (s.contains('MATTE')) return _SpoolSeries.matte;
  return _SpoolSeries.standard;
}
```

```dart
// AFTER — add STARLIGHT on the galaxy line
_SpoolSeries _detectSeries(String? material) {
  final s = (material ?? '').toUpperCase();
  if (s.contains('SILK')) return _SpoolSeries.silk;
  if (s.contains('METALLIC')) return _SpoolSeries.metallic;
  if (s.contains('GALAXY') || s.contains('STARLIGHT')) return _SpoolSeries.galaxy;
  if (s.contains('MATTE')) return _SpoolSeries.matte;
  return _SpoolSeries.standard;
}
```

### B2 — `swatch_screen.dart` › `_SwatchPainter._drawGalaxy`

The existing method draws 20 fixed white/purple dots. Replace it entirely.

**Before** (inside `_SwatchPainter`):

```dart
void _drawGalaxy(Canvas canvas, Offset center, double radius) {
  final rng = math.Random(primaryColor.value);

  void star(Color color, double minR, double maxR) {
    while (true) {
      final x = center.dx + (rng.nextDouble() * 2 - 1) * radius;
      final y = center.dy + (rng.nextDouble() * 2 - 1) * radius;
      if ((x - center.dx) * (x - center.dx) + (y - center.dy) * (y - center.dy) >
          radius * radius) continue;
      canvas.drawCircle(
        Offset(x, y),
        minR + rng.nextDouble() * (maxR - minR),
        Paint()..color = color,
      );
      break;
    }
  }

  for (var i = 0; i < 16; i++) star(const Color(0xFFE8E8FF), 0.8, 1.6);
  for (var i = 0; i < 4; i++) star(const Color(0xFFCCBBFF), 1.2, 2.2);
}
```

**After:**

```dart
void _drawGalaxy(Canvas canvas, Offset center, double radius) {
  final rng = math.Random(primaryColor.value);

  // Derive sparkle colors from the spool's primary color.
  // Clamp lightness up to 0.72 so dark colors still produce visible sparkles.
  final hsl = HSLColor.fromColor(primaryColor);
  final sparkle = hsl.withLightness(math.max(hsl.lightness, 0.72)).toColor();
  // Near-white tinted by the primary hue for mid-size dots.
  final tinted = hsl
      .withSaturation(hsl.saturation * 0.3)
      .withLightness(0.88)
      .toColor();

  // For square chips the canvas fills a rectangle; no circle reject-sample
  // needed — dots placed anywhere inside [0, size.width] × [0, size.height].
  void dot(Color color, double minR, double maxR) {
    final x = center.dx + (rng.nextDouble() * 2 - 1) * radius;
    final y = center.dy + (rng.nextDouble() * 2 - 1) * radius;
    canvas.drawCircle(
      Offset(x, y),
      minR + rng.nextDouble() * (maxR - minR),
      Paint()..color = color,
    );
  }

  // Layer 1 — dense small sparkles in brightened primary color.
  for (var i = 0; i < 90; i++) dot(sparkle, 0.4, 1.2);
  // Layer 2 — medium near-white tinted dots.
  for (var i = 0; i < 20; i++) dot(tinted, 0.9, 1.8);
  // Layer 3 — five bright "hot sparks" near pure white.
  for (var i = 0; i < 5; i++) dot(const Color(0xFFEEEEFF), 1.4, 2.4);
}
```

---

## C. Merge PLA PRO into PLA+

All three of these changes are in `swatch_screen.dart`.

### C1 — `_kSpecialSeries` constant

```dart
// BEFORE
const _kSpecialSeries = [
  'PLA GALAXY', 'PLA METALLIC', 'PLA SILK', 'PLA MATTE', 'PLA PRO',
];
```

```dart
// AFTER — remove 'PLA PRO'
const _kSpecialSeries = [
  'PLA GALAXY', 'PLA METALLIC', 'PLA SILK', 'PLA MATTE',
];
```

### C2 — `_kGroupOrder` constant

```dart
// BEFORE
const _kGroupOrder = [
  'PLA+', 'PLA PRO', 'PLA',
  'PLA SILK', 'PLA METALLIC', 'PLA MATTE', 'PLA GALAXY',
  'PETG', 'ABS', 'ASA', 'TPU', 'PA', 'PC', 'PEEK', 'PVA', 'HIPS',
];
```

```dart
// AFTER — remove 'PLA PRO'
const _kGroupOrder = [
  'PLA+', 'PLA',
  'PLA SILK', 'PLA METALLIC', 'PLA MATTE', 'PLA GALAXY',
  'PETG', 'ABS', 'ASA', 'TPU', 'PA', 'PC', 'PEEK', 'PVA', 'HIPS',
];
```

### C3 — `_normalizeGroup`

Insert the PLA PRO redirect **before** the existing `_kSpecialSeries` loop, as the first check after the empty guard:

```dart
// BEFORE
String _normalizeGroup(String? raw) {
  final s = (raw ?? '').trim().toUpperCase();
  if (s.isEmpty) return 'Other';
  // Exact match against special series first ...
  for (final series in _kSpecialSeries) {
    if (s == series) return series;
  }
  ...
}
```

```dart
// AFTER — add the PLA PRO → PLA+ redirect as the very first check
String _normalizeGroup(String? raw) {
  final s = (raw ?? '').trim().toUpperCase();
  if (s.isEmpty) return 'Other';
  if (s == 'PLA PRO') return 'PLA+';
  // Exact match against special series first ...
  for (final series in _kSpecialSeries) {
    if (s == series) return series;
  }
  ...
}
```

---

## D. Flat 8-column square tight grid

### D1 — `_SwatchPainter` — switch from circle to rectangle

**In `_SwatchPainter.paint()`**, replace the clip and fill shape calls. The method currently (summarised):

```dart
@override
void paint(Canvas canvas, Size size) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = size.width / 2;
  final rect = Rect.fromCircle(center: center, radius: radius);
  final clip = Path()..addOval(rect);         // ← change to addRect

  canvas.save();
  canvas.clipPath(clip);

  if (series == _SpoolSeries.galaxy) {
    canvas.drawOval(rect, Paint()..color = const Color(0xFF0A0A0F));  // ← drawRect
    _drawGalaxy(canvas, center, radius);
  } else if (allColors.length >= 2) {
    _drawSectors(canvas, center, radius, allColors);   // unchanged
  } else {
    canvas.drawOval(rect, Paint()..color = primaryColor);              // ← drawRect
  }

  if (series == _SpoolSeries.silk || series == _SpoolSeries.metallic) {
    _drawSheen(canvas, rect);
  }

  canvas.restore();

  // TWO drawCircle calls for border/highlight ring — DELETE BOTH
  canvas.drawCircle(center, radius - 0.75, Paint()...);
  canvas.drawCircle(center, radius - 1.75, Paint()...);
}
```

**Full replacement (complete method):**

```dart
@override
void paint(Canvas canvas, Size size) {
  final center = Offset(size.width / 2, size.height / 2);
  final radius = size.width / 2;
  final rect = Rect.fromLTWH(0, 0, size.width, size.height);
  final clip = Path()..addRect(rect);

  canvas.save();
  canvas.clipPath(clip);

  final allColors = [primaryColor, ...extraColors];

  if (series == _SpoolSeries.galaxy) {
    canvas.drawRect(rect, Paint()..color = const Color(0xFF0A0A0F));
    _drawGalaxy(canvas, center, radius);
  } else if (allColors.length >= 2) {
    _drawSectors(canvas, center, radius, allColors);
  } else {
    canvas.drawRect(rect, Paint()..color = primaryColor);
  }

  if (series == _SpoolSeries.silk || series == _SpoolSeries.metallic) {
    _drawSheen(canvas, rect);
  }

  canvas.restore();
  // No per-chip border. The grid container provides edge definition.
}
```

**In `_drawSheen()`**, change the final draw call:

```dart
// BEFORE
canvas.drawOval(rect, Paint()..shader = shader..blendMode = BlendMode.screen);

// AFTER
canvas.drawRect(rect, Paint()..shader = shader..blendMode = BlendMode.screen);
```

`_drawSectors()` is **unchanged** — `drawArc` draws into `Rect.fromCircle(center, radius)` which for equal width/height is the same rect; the rectangular clip crops the pie wedges naturally.

### D2 — `_SwatchChip` — drop Column, label, and fixed width

**Full replacement of the class:**

```dart
// BEFORE
class _SwatchChip extends StatelessWidget {
  const _SwatchChip({required this.chip, required this.onTap});

  final _ColorChip chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(chip.hex);
    final extraColors = chip.extraHexes
        .map((h) => _hexToColor(h) ?? const Color(0xFF3F3F46))
        .toList();
    final name = chip.name?.trim() ?? '';
    final count = chip.spoolIds.length;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(42, 42),
                  painter: _SwatchPainter(
                    primaryColor: color ?? const Color(0xFF3F3F46),
                    extraColors: extraColors,
                    series: chip.series,
                  ),
                ),
                if (count > 1)
                  Text('$count', ...),
              ],
            ),
            if (name.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(name, ...),
            ],
          ],
        ),
      ),
    );
  }
}
```

```dart
// AFTER — just the gesture + paint; no Column, no label, no count badge, no fixed size
class _SwatchChip extends StatelessWidget {
  const _SwatchChip({required this.chip, required this.onTap});

  final _ColorChip chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(chip.hex);
    final extraColors = chip.extraHexes
        .map((h) => _hexToColor(h) ?? const Color(0xFF3F3F46))
        .toList();

    return GestureDetector(
      key: ValueKey('swatch-${chip.hex}'),
      onTap: onTap,
      child: CustomPaint(
        painter: _SwatchPainter(
          primaryColor: color ?? const Color(0xFF3F3F46),
          extraColors: extraColors,
          series: chip.series,
        ),
      ),
    );
  }
}
```

`CustomPaint` without an explicit `size` expands to fill the grid cell. The `ValueKey` on `GestureDetector` allows widget tests to target chips by hex.

### D3 — `_MaterialSection` — replace per-band Wrap with flat GridView

**Locate** `_MaterialSection.build()`. It currently builds `final bands = _buildHueBands(group.chips)` and renders each band as a separate `Wrap(spacing: 8, runSpacing: 8, children: [_SwatchChip...])`.

**Full replacement of `build()`:**

```dart
@override
Widget build(BuildContext context) {
  // Flatten all hue bands into a single ordered list.
  // _buildHueBands returns bands in rainbow order; within each band chips
  // are sorted light → dark. Flattening preserves that ordering.
  final flatChips = _buildHueBands(group.chips).expand((band) => band).toList();

  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header — unchanged from current implementation.
        Row(
          children: [
            Text(
              group.label,
              style: const TextStyle(
                color: Color(0xFF71717A),
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${group.chips.length}',
                style: const TextStyle(
                  color: Color(0xFF52525B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Shade-card grid — zero gap, rounded outer corners.
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 0,
              crossAxisSpacing: 0,
              childAspectRatio: 1.0,
            ),
            itemCount: flatChips.length,
            itemBuilder: (ctx, i) => _SwatchChip(
              chip: flatChips[i],
              onTap: () => onChipTap(flatChips[i]),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1, color: Color(0xFF27272A)),
      ],
    ),
  );
}
```

---

## E. Same-color / different-brand variant tracking

### E1 — New `_SpoolVariant` data class

Add this class to the **"Data classes"** section of `swatch_screen.dart`, immediately **before** `_ColorChip`:

```dart
class _SpoolVariant {
  const _SpoolVariant({
    required this.brand,
    required this.colorName,
    required this.spoolIds,
  });

  final String? brand;
  final String? colorName;
  final List<int> spoolIds;
}
```

### E2 — Update `_ColorChip`

Replace the class entirely:

```dart
// BEFORE
class _ColorChip {
  const _ColorChip({
    required this.hex,
    required this.spoolIds,
    this.name,
    this.brand,
    this.material,
    this.series = _SpoolSeries.standard,
    this.extraHexes = const [],
  });

  final String hex;
  final String? name;
  final String? brand;
  final String? material;
  final List<int> spoolIds;
  final _SpoolSeries series;
  final List<String> extraHexes;
}
```

```dart
// AFTER
class _ColorChip {
  const _ColorChip({
    required this.hex,
    required this.variants,
    this.material,
    this.series = _SpoolSeries.standard,
    this.extraHexes = const [],
  });

  final String hex;
  final List<_SpoolVariant> variants;  // one entry per unique brand+colorName pair
  final String? material;
  final _SpoolSeries series;
  final List<String> extraHexes;

  /// Total number of physical spools across all variants.
  int get totalSpools => variants.fold(0, (n, v) => n + v.spoolIds.length);

  /// Primary display name: first variant's colorName (used by nothing in the
  /// grid itself; shown only in the detail modal header).
  String? get primaryName => variants.isEmpty ? null : variants.first.colorName;
}
```

### E3 — Update `_buildGroups` chip creation

**Locate** the chip-creation block inside `_buildGroups`. Currently:

```dart
final chips = byKey.entries.map((e) {
  final ss = e.value;
  return _ColorChip(
    hex: ss.first.hex,
    name: ss.first.colorName,
    brand: ss.first.brand,
    material: ss.first.material,
    spoolIds: ss.map((s) => s.id).toList(),
    series: ss.first.series,
    extraHexes: ss.first.extraHexes,
  );
}).toList();
```

Replace with:

```dart
final chips = byKey.entries.map((e) {
  final ss = e.value;

  // Sub-group entries by brand+colorName to produce variant list.
  // Entries with the same brand and color name collapse to one variant
  // whose spoolIds lists all matching spools.
  final byVariant = <String, List<_SpoolEntry>>{};
  for (final s in ss) {
    final key = '${s.brand ?? ''}::${s.colorName ?? ''}';
    byVariant.putIfAbsent(key, () => []).add(s);
  }
  final variants = byVariant.entries.map((ve) {
    return _SpoolVariant(
      brand: ve.value.first.brand,
      colorName: ve.value.first.colorName,
      spoolIds: ve.value.map((s) => s.id).toList(),
    );
  }).toList();

  return _ColorChip(
    hex: ss.first.hex,
    variants: variants,
    material: ss.first.material,
    series: ss.first.series,
    extraHexes: ss.first.extraHexes,
  );
}).toList();
```

### E4 — Update `_showDetail` modal

Replace `_showDetail` entirely:

```dart
void _showDetail(BuildContext context, _ColorChip chip) {
  final color = _hexToColor(chip.hex);
  final extraColors = chip.extraHexes
      .map((h) => _hexToColor(h) ?? const Color(0xFF3F3F46))
      .toList();

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: const Color(0xFF1C1C20),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Square swatch (matches chip shape).
                SizedBox(
                  width: 32,
                  height: 32,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CustomPaint(
                      painter: _SwatchPainter(
                        primaryColor: color ?? const Color(0xFF3F3F46),
                        extraColors: extraColors,
                        series: chip.series,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chip.primaryName ?? 'Unknown color',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (chip.material != null)
                        Text(
                          chip.material!,
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                // Spool count badge.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${chip.totalSpools} spool${chip.totalSpools == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Hex values ──────────────────────────────────────────────────
            if (chip.extraHexes.isEmpty)
              _DetailRow(label: 'Hex', value: '#${chip.hex}', mono: true)
            else ...[
              _DetailRow(label: 'Color 1', value: '#${chip.hex}', mono: true),
              for (var i = 0; i < chip.extraHexes.length; i++)
                _DetailRow(
                  label: 'Color ${i + 2}',
                  value: '#${chip.extraHexes[i]}',
                  mono: true,
                ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFF27272A)),
            const SizedBox(height: 12),

            // ── Variants (one per unique brand+colorName) ───────────────────
            for (var vi = 0; vi < chip.variants.length; vi++) ...[
              if (vi > 0) const SizedBox(height: 10),
              _VariantRow(variant: chip.variants[vi]),
            ],
          ],
        ),
      ),
    ),
  );
}
```

### E5 — New `_VariantRow` widget

Add this private widget at the end of the file (after `_MessageBanner` or before the data classes):

```dart
class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.variant});

  final _SpoolVariant variant;

  @override
  Widget build(BuildContext context) {
    final brand = variant.brand;
    final name = variant.colorName;
    final ids = variant.spoolIds.map((id) => '#$id').join('  ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (brand != null)
                Text(
                  brand,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (name != null)
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 12,
                  ),
                ),
              if (brand == null && name == null)
                const Text(
                  'Unknown',
                  style: TextStyle(color: Color(0xFF52525B), fontSize: 12),
                ),
            ],
          ),
        ),
        Text(
          ids,
          style: const TextStyle(
            color: Color(0xFF52525B),
            fontSize: 12,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
```

---

## F. Color picker → camera badge on spool disc

### F1 — Add `dart:math` import to `weigh_screen.dart`

`weigh_screen.dart` currently does **not** import `dart:math`. Change G needs `math.Random` and `math.max`. Add the import at the top alongside the other `dart:` imports:

```dart
import 'dart:math' as math;
```

### F2 — Add params to `_SpoolCard`

```dart
// BEFORE
class _SpoolCard extends StatelessWidget {
  const _SpoolCard({required this.spool, required this.detail});

  final MobileSpool spool;
  final MobileSpoolDetail? detail;
  ...
}
```

```dart
// AFTER
class _SpoolCard extends StatelessWidget {
  const _SpoolCard({
    required this.spool,
    required this.detail,
    this.pickedColor,
    this.onPickColor,
    this.onClearColor,
  });

  final MobileSpool spool;
  final MobileSpoolDetail? detail;
  final Color? pickedColor;
  final VoidCallback? onPickColor;
  final VoidCallback? onClearColor;
  ...
}
```

### F3 — Update `_SpoolCard.build()` spool-view section

Locate the end of `_SpoolCard.build()` where the Row is assembled. Currently:

```dart
const SizedBox(width: 12),
_SpoolSideView(
  color: primary,
  fill: pct ?? 1.0,
  surface: cs.surfaceContainerHigh,
  track: cs.outline,
),
```

Replace with:

```dart
const SizedBox(width: 12),
Builder(builder: (ctx) {
  final swatches = _filamentSwatches(spool, detail);
  // extras = all swatches after the primary (used for multi-color gradient).
  final extras = swatches.length > 1 ? swatches.sublist(1) : const <Color>[];
  return Stack(
    children: [
      _SpoolSideView(
        color: pickedColor ?? primary,
        fill: pct ?? 1.0,
        surface: cs.surfaceContainerHigh,
        track: cs.outline,
        effect: _spoolEffect(detail, spool),
        extraColors: extras,
      ),
      // Camera badge — always visible when a spool is loaded.
      Positioned(
        top: 6,
        right: 6,
        child: GestureDetector(
          onTap: onPickColor,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF3F3F46)),
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              size: 15,
              color: Color(0xFF71717A),
            ),
          ),
        ),
      ),
      // Clear badge — top-left, only shown when a color has been picked.
      if (pickedColor != null)
        Positioned(
          top: 6,
          left: 6,
          child: GestureDetector(
            onTap: onClearColor,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: const Icon(
                Icons.close,
                size: 11,
                color: Color(0xFF71717A),
              ),
            ),
          ),
        ),
    ],
  );
}),
```

### F4 — Update `_SpoolCard` call site in `WeighScreenState.build()`

Pass the new params:

```dart
// BEFORE
_SpoolCard(spool: _spool!, detail: _detail),
```

```dart
// AFTER
_SpoolCard(
  spool: _spool!,
  detail: _detail,
  pickedColor: _pickedColor,
  onPickColor: _pickColorFromCamera,
  onClearColor: () => setState(() => _pickedColor = null),
),
```

### F5 — Remove `_SwatchColorRow` from the "Update spool" panel

In `WeighScreenState.build()`, inside the `FrostedPanel > Column`, locate and **delete** these two lines (the widget and the `SizedBox` spacer that follows it):

```dart
// DELETE these two lines:
_SwatchColorRow(
  currentHex: _spool?.rgba,
  pickedColor: _pickedColor,
  enabled: !_busy,
  onPick: _pickColorFromCamera,
  onClear: () => setState(() => _pickedColor = null),
),
const SizedBox(height: 12),
```

### F6 — Delete the `_SwatchColorRow` class definition

Delete the entire `_SwatchColorRow` class (lines 1029–1110 in the original file). It will no longer be referenced.

**Do NOT delete `_colorToHex`** — it is still called by `_save()` at:
```dart
final hex = _colorToHex(_pickedColor!);
```

---

## G. Material-effect rendering on the spool disc

### G1 — New `_spoolEffect` top-level helper in `weigh_screen.dart`

Add this function near the other top-level helpers (`_remainingPercent`, `_filamentColor`, `_filamentSwatches`):

```dart
/// Returns a lowercase effect tag for [_SpoolSidePainter].
/// Checks [detail.effectType] (bambuddy-stored) first, then falls back to
/// [spool.material] (spoolman-stored) so either source works.
String _spoolEffect(MobileSpoolDetail? detail, MobileSpool spool) {
  final s = '${detail?.effectType ?? ''}|${spool.material ?? ''}'.toUpperCase();
  if (s.contains('GALAXY') || s.contains('STARLIGHT')) return 'galaxy';
  if (s.contains('SILK')) return 'silk';
  if (s.contains('METALLIC')) return 'metallic';
  return '';
}
```

### G2 — Add params to `_SpoolSideView`

```dart
// BEFORE
class _SpoolSideView extends StatelessWidget {
  const _SpoolSideView({
    required this.color,
    required this.fill,
    required this.surface,
    required this.track,
  });

  final Color color;
  final double fill;
  final Color surface;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: CustomPaint(
        painter: _SpoolSidePainter(
          color: color,
          fill: fill,
          surface: surface,
          track: track,
        ),
      ),
    );
  }
}
```

```dart
// AFTER
class _SpoolSideView extends StatelessWidget {
  const _SpoolSideView({
    required this.color,
    required this.fill,
    required this.surface,
    required this.track,
    this.effect = '',
    this.extraColors = const [],
  });

  final Color color;
  final double fill;
  final Color surface;
  final Color track;
  final String effect;
  final List<Color> extraColors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: CustomPaint(
        painter: _SpoolSidePainter(
          color: color,
          fill: fill,
          surface: surface,
          track: track,
          effect: effect,
          extraColors: extraColors,
        ),
      ),
    );
  }
}
```

### G3 — Add params to `_SpoolSidePainter`

```dart
// BEFORE
class _SpoolSidePainter extends CustomPainter {
  const _SpoolSidePainter({
    required this.color,
    required this.fill,
    required this.surface,
    required this.track,
  });

  final Color color;
  final double fill;
  final Color surface;
  final Color track;
```

```dart
// AFTER
class _SpoolSidePainter extends CustomPainter {
  const _SpoolSidePainter({
    required this.color,
    required this.fill,
    required this.surface,
    required this.track,
    this.effect = '',
    this.extraColors = const [],
  });

  final Color color;
  final double fill;
  final Color surface;
  final Color track;
  final String effect;
  final List<Color> extraColors;
```

### G4 — Replace `_SpoolSidePainter.paint()`

This is the complete replacement of the `paint` method:

```dart
@override
void paint(Canvas canvas, Size size) {
  final center = Offset(size.width / 2, size.height / 2);
  final outer = size.shortestSide / 2;
  final coreR = outer * 0.22;
  final margin = outer * 0.05;
  final maxR = outer - margin;
  final fillR = coreR + (maxR - coreR) * fill.clamp(0.0, 1.0);

  // ── Flange (two side plates of the spool) ────────────────────────────────
  canvas.drawCircle(center, outer, Paint()..color = track);
  canvas.drawCircle(
    center,
    outer - margin * 0.6,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Color.lerp(track, surface, 0.35)!,
  );

  // ── Wound filament ────────────────────────────────────────────────────────
  if (extraColors.isNotEmpty) {
    // Multi-color: sweep gradient that wraps around the fill disc.
    final allColors = [color, ...extraColors];
    // Repeat the first color at stop 1.0 to close the gradient loop cleanly.
    final gradColors = [...allColors, allColors.first];
    final stops = List.generate(allColors.length, (i) => i / allColors.length)
      ..add(1.0);
    final shader = SweepGradient(
      colors: gradColors,
      stops: stops,
      center: Alignment.center,
    ).createShader(Rect.fromCircle(center: center, radius: fillR));
    canvas.drawCircle(center, fillR, Paint()..shader = shader);
  } else {
    canvas.drawCircle(center, fillR, Paint()..color = color);
  }

  // Winding lines — concentric rings suggesting wound layers.
  final windingColor = extraColors.isNotEmpty
      ? Colors.black.withValues(alpha: 0.20)
      : Color.lerp(color, Colors.black, 0.28)!;
  for (var i = 1; i <= 3; i++) {
    final r = coreR + (fillR - coreR) * (i / 4);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = windingColor,
    );
  }

  // ── Effect overlay (on the fill area only) ────────────────────────────────
  if (effect == 'silk' || effect == 'metallic') {
    final alpha = effect == 'silk' ? 0.40 : 0.22;
    final fillRect = Rect.fromCircle(center: center, radius: fillR);
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: alpha),
        Colors.transparent,
      ],
      stops: const [0.25, 0.50, 0.75],
    ).createShader(fillRect);
    canvas.save();
    canvas.clipPath(Path()..addOval(fillRect));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.screen,
    );
    canvas.restore();
  } else if (effect == 'galaxy') {
    _drawDiscGalaxy(canvas, center, fillR);
  }

  // ── Core hole + hub ring ──────────────────────────────────────────────────
  canvas.drawCircle(center, coreR, Paint()..color = surface);
  canvas.drawCircle(
    center,
    coreR * 0.55,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = track,
  );
}
```

### G5 — New `_drawDiscGalaxy` method on `_SpoolSidePainter`

Add this private method inside `_SpoolSidePainter`, after `paint()`:

```dart
/// Draws galaxy sparkles inside the fill circle on the spool disc.
/// Fewer particles than the swatch painter (18 + 4) because the disc is
/// primarily a fill-level indicator, not a color showcase.
void _drawDiscGalaxy(Canvas canvas, Offset center, double fillR) {
  final rng = math.Random(color.value);
  final hsl = HSLColor.fromColor(color);
  final sparkle = hsl.withLightness(math.max(hsl.lightness, 0.72)).toColor();

  canvas.save();
  canvas.clipPath(
    Path()..addOval(Rect.fromCircle(center: center, radius: fillR)),
  );

  void dot(Color c, double minR, double maxR) {
    while (true) {
      final x = center.dx + (rng.nextDouble() * 2 - 1) * fillR;
      final y = center.dy + (rng.nextDouble() * 2 - 1) * fillR;
      if ((x - center.dx) * (x - center.dx) +
              (y - center.dy) * (y - center.dy) >
          fillR * fillR) continue;
      canvas.drawCircle(
        Offset(x, y),
        minR + rng.nextDouble() * (maxR - minR),
        Paint()..color = c,
      );
      break;
    }
  }

  for (var i = 0; i < 18; i++) dot(sparkle, 0.5, 1.3);
  for (var i = 0; i < 4; i++) dot(const Color(0xFFEEEEFF), 1.0, 2.0);

  canvas.restore();
}
```

### G6 — Update `_SpoolSidePainter.shouldRepaint`

```dart
// BEFORE
@override
bool shouldRepaint(covariant _SpoolSidePainter old) =>
    old.color != color ||
    old.fill != fill ||
    old.surface != surface ||
    old.track != track;
```

```dart
// AFTER
@override
bool shouldRepaint(covariant _SpoolSidePainter old) =>
    old.color != color ||
    old.fill != fill ||
    old.surface != surface ||
    old.track != track ||
    old.effect != effect ||
    old.extraColors != extraColors;
```

---

## Test changes — `swatch_screen_test.dart`

### Tests that BREAK and must be updated

**1. "Chips with same hue appear before chips with darker lightness" (line 107–126)**

This test verifies ordering by finding `Text('Ivory')` and `Text('Chocolate')` widgets and comparing their x positions. After Change D, chips have no text labels, so `find.text('Ivory')` finds nothing.

**Fix:** Chips now carry `ValueKey('swatch-${chip.hex}')` on their `GestureDetector`. Use `find.byKey` to locate each chip, then compare `tester.getTopLeft(...)` positions.

```dart
testWidgets('Light chips appear before dark chips of same hue', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: SwatchScreen(testSpools: [
        {'id': 1, 'rgba': '5C3317', 'material': 'PLA+', 'brand': 'A', 'color_name': 'Chocolate', 'extra_colors': null},
        {'id': 2, 'rgba': 'FFFFF0', 'material': 'PLA+', 'brand': 'A', 'color_name': 'Ivory', 'extra_colors': null},
      ]),
    ),
  );
  await tester.pump();
  expect(find.text('No spools in inventory'), findsNothing);

  final ivoryChip = find.byKey(const ValueKey('swatch-fffff0'));
  final chocChip = find.byKey(const ValueKey('swatch-5c3317'));
  expect(ivoryChip, findsOneWidget);
  expect(chocChip, findsOneWidget);
  // Ivory (higher lightness) is left of Chocolate in the flat grid.
  expect(
    tester.getTopLeft(ivoryChip).dx,
    lessThan(tester.getTopLeft(chocChip).dx),
  );
});
```

**2. "Detail modal shows individual color rows for multi-color chip" (line 128–154)**

This test taps `find.text('Black-Gold')` to open the modal. After Change D, chip text labels are removed; the chip must be tapped via its key. The modal content assertions (`Color 1`, `Color 2`, `#111111`, `#d4af37`) are still valid because the new modal keeps `_DetailRow(label: 'Color 1', ...)` for multi-color chips.

```dart
testWidgets('Detail modal shows individual color rows for multi-color chip', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: SwatchScreen(testSpools: [
        {
          'id': 3,
          'rgba': '',
          'material': 'PLA SILK',
          'brand': 'Test',
          'color_name': 'Black-Gold',
          'extra_colors': '111111,D4AF37',
        },
      ]),
    ),
  );
  await tester.pump();

  // Tap the chip by its hex key (primary color is first extraColor: 111111).
  await tester.tap(find.byKey(const ValueKey('swatch-111111')));
  await tester.pumpAndSettle();

  expect(find.text('#111111'), findsOneWidget);
  expect(find.text('#d4af37'), findsOneWidget);
  expect(find.text('Color hex'), findsNothing);
  expect(find.text('Color 1'), findsOneWidget);
  expect(find.text('Color 2'), findsOneWidget);
});
```

### New tests to add

```dart
testWidgets('PLA PRO spools appear in the PLA+ section', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: SwatchScreen(testSpools: [
        {'id': 1, 'rgba': 'F6F6F0', 'material': 'PLA PRO', 'brand': 'A', 'color_name': 'White', 'extra_colors': null},
      ]),
    ),
  );
  await tester.pump();
  expect(find.text('PLA+'), findsOneWidget);
  expect(find.text('PLA PRO'), findsNothing);
});

testWidgets('Same hex from two brands produces one chip with two variants in modal', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: SwatchScreen(testSpools: [
        {'id': 1, 'rgba': 'F0EDE4', 'material': 'PLA+', 'brand': 'Bambu Lab', 'color_name': 'Jade White', 'extra_colors': null},
        {'id': 2, 'rgba': 'F0EDE4', 'material': 'PLA+', 'brand': 'Polymaker', 'color_name': 'Pearl White', 'extra_colors': null},
      ]),
    ),
  );
  await tester.pump();
  // Only one chip should render (same hex).
  expect(find.byKey(const ValueKey('swatch-f0ede4')), findsOneWidget);
  // Open the modal.
  await tester.tap(find.byKey(const ValueKey('swatch-f0ede4')));
  await tester.pumpAndSettle();
  // Both brands must appear.
  expect(find.text('Bambu Lab'), findsOneWidget);
  expect(find.text('Polymaker'), findsOneWidget);
  // Both color names.
  expect(find.text('Jade White'), findsOneWidget);
  expect(find.text('Pearl White'), findsOneWidget);
  // Spool IDs.
  expect(find.text('#1'), findsOneWidget);
  expect(find.text('#2'), findsOneWidget);
});

testWidgets('STARLIGHT material detected as galaxy series without throwing', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: SwatchScreen(testSpools: [
        {'id': 1, 'rgba': '6A0DAD', 'material': 'PLA STARLIGHT', 'brand': 'A', 'color_name': 'Purple Starlight', 'extra_colors': null},
      ]),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  // Starlight falls into PLA GALAXY group (same series).
  expect(find.text('PLA GALAXY'), findsOneWidget);
});
```

Note: the STARLIGHT test expects the spool to appear under `PLA GALAXY`. Verify that `_normalizeGroup('PLA STARLIGHT')` falls through to the `_kBases` loop and returns `'PLA'` (since 'PLA STARLIGHT' contains 'PLA' but no special-series match). If the desired behaviour is a dedicated `PLA GALAXY` section for STARLIGHT, add `'PLA STARLIGHT'` to `_kSpecialSeries` and handle it in `_normalizeGroup`. If STARLIGHT spools should just sit in their base material section, leave as-is — the STARLIGHT detection only affects the *rendering effect* inside `_detectSeries`, not the group label.

---

## Edge cases and invariants

| Scenario | Expected behaviour |
|----------|-------------------|
| `extra_colors` is `null` | `_parseExtraColors` returns `const []`; chip renders as solid single color |
| `extra_colors` has `#`-prefixed tokens | Tokens are normalised; multi-color chip renders correctly |
| `rgba` is empty, `extra_colors` has one token | First extra promoted to primary; `effectiveExtras` is empty; chip renders as solid |
| PLA PRO spool in inventory | Maps to PLA+ group; renders as `_SpoolSeries.standard` |
| Galaxy chip with very dark primary (e.g. `#000000`) | `math.max(lightness, 0.72)` ensures sparkles are always visible |
| Multi-color spool on weigh disc with `fill = 0` | `fillR = coreR`; sweep gradient draws on a tiny disc; visually the fill area is the empty core ring — acceptable |
| `onPickColor` / `onClearColor` are null on `_SpoolCard` | `GestureDetector.onTap: null` disables tap silently — no crash |
| `pickedColor` set and `_colorChanged` is false (picked same color as stored) | Save button still enables; `_colorChanged` compares RGB channels so exact equality suppresses the color update in `_save()` — no spurious API call |
