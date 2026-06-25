# Swatch Special Series Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render special filament series (Silk, Metallic, Galaxy, multi-color) with distinctive visuals in the swatch screen, and replace the flat chip layout with a 2D hue matrix (rainbow vertically, light→dark horizontally).

**Architecture:** All changes are confined to `swatch_screen.dart`. A `_SpoolSeries` enum drives visual dispatch; a `_SwatchPainter` CustomPainter handles all chip rendering. `_buildHueBands` replaces the flat `_byHue` sort, grouping chips into hue rows sorted by HSL lightness. A `testSpools` constructor parameter enables widget testing without a live API.

**Tech Stack:** Flutter/Dart, `dart:math` (already in SDK — no new pub dependencies), Flutter's `CustomPainter`, `HSVColor`, `HSLColor`, `LinearGradient`.

## Global Constraints

- All implementation changes are within `apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart` — no new source files.
- New test file: `apps/filament-assignment-flutter/test/swatch_screen_test.dart`.
- No new `pubspec.yaml` dependencies — `dart:math` is part of the Dart SDK.
- Run all commands from inside `apps/filament-assignment-flutter/` unless noted otherwise.
- Follow existing code style: private classes/functions prefixed with `_`, `const` constructors where possible, `withValues(alpha:)` not deprecated `withOpacity`.
- The `extra_colors` field is assumed to be present in the `/spoolman/inventory/spools` list response. If absent at runtime the code falls back gracefully (treats as single-color).

---

### Task 1: Data model foundation — enum, helpers, model fields, test injection

**Files:**
- Modify: `apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart`
- Create: `apps/filament-assignment-flutter/test/swatch_screen_test.dart`

**Interfaces:**
- Produces: `_SpoolSeries` enum; `_detectSeries(String?)` → `_SpoolSeries`; `_parseExtraColors(dynamic)` → `List<String>`; updated `_SpoolEntry` and `_ColorChip` with `series` and `extraHexes`; `SwatchScreen.testSpools` optional parameter.

- [ ] **Step 1: Write the failing test**

Create `apps/filament-assignment-flutter/test/swatch_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filament_assignment/src/ui/swatch_screen.dart';

void main() {
  testWidgets('SwatchScreen renders empty state with no spools', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SwatchScreen(testSpools: [])),
    );
    await tester.pump();
    expect(find.text('No spools in inventory'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/swatch_screen_test.dart
```

Expected: compilation error — `SwatchScreen` has no `testSpools` parameter yet.

- [ ] **Step 3: Add `_SpoolSeries` enum**

In `swatch_screen.dart`, add the enum just before the `_SpoolEntry` class (around line 499):

```dart
enum _SpoolSeries { standard, silk, metallic, galaxy, matte }
```

- [ ] **Step 4: Add `_detectSeries` and `_parseExtraColors` helpers**

Add these two free functions to the `// ── Helpers ──` section at the bottom of the file, before `_str`:

```dart
_SpoolSeries _detectSeries(String? material) {
  final s = (material ?? '').toUpperCase();
  if (s.contains('SILK')) return _SpoolSeries.silk;
  if (s.contains('METALLIC')) return _SpoolSeries.metallic;
  if (s.contains('GALAXY')) return _SpoolSeries.galaxy;
  if (s.contains('MATTE')) return _SpoolSeries.matte;
  return _SpoolSeries.standard;
}

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

- [ ] **Step 5: Update `_SpoolEntry` to carry the new fields**

Replace the existing `_SpoolEntry` class:

```dart
class _SpoolEntry {
  const _SpoolEntry({
    required this.id,
    required this.hex,
    this.material,
    this.brand,
    this.colorName,
    this.series = _SpoolSeries.standard,
    this.extraHexes = const [],
  });

  final int id;
  final String hex;
  final String? material;
  final String? brand;
  final String? colorName;
  final _SpoolSeries series;
  final List<String> extraHexes;
}
```

- [ ] **Step 6: Update `_ColorChip` to carry the new fields**

Replace the existing `_ColorChip` class:

```dart
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

- [ ] **Step 7: Add `testSpools` to `SwatchScreen` and wire it into `_load`**

Update the `SwatchScreen` class:

```dart
class SwatchScreen extends StatefulWidget {
  const SwatchScreen({super.key, this.refreshNonce = 0, this.testSpools});

  final int refreshNonce;

  /// Inject raw spool maps for widget tests, bypassing the API call.
  final List<Map<String, dynamic>>? testSpools;

  @override
  State<SwatchScreen> createState() => _SwatchScreenState();
}
```

In `_SwatchScreenState._load()`, add a test-injection branch at the very top, before the `setState` call:

```dart
Future<void> _load() async {
  if (!mounted) return;
  // Test injection: bypass API when testSpools is provided.
  final injected = widget.testSpools;
  if (injected != null) {
    setState(() {
      _groups = _buildGroups(injected);
      _loading = false;
    });
    return;
  }
  setState(() {
    _loading = true;
    _error = null;
  });
  // ... rest of existing _load body unchanged ...
```

- [ ] **Step 8: Run the test to confirm it passes**

```
flutter test test/swatch_screen_test.dart
```

Expected: PASS — empty `testSpools` renders the empty state widget.

- [ ] **Step 9: Commit**

```
git add apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart apps/filament-assignment-flutter/test/swatch_screen_test.dart
git commit -m "feat(swatches): add _SpoolSeries enum, model fields, test injection"
```

---

### Task 2: Fix `_buildGroups` — multi-color parsing, composite key, series detection

**Files:**
- Modify: `apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart`
- Modify: `apps/filament-assignment-flutter/test/swatch_screen_test.dart`

**Interfaces:**
- Consumes: `_parseExtraColors`, `_detectSeries`, `_normalizeHex`, `_normalizeGroup`, `_str` (all existing or from Task 1).
- Produces: updated `_buildGroups` that correctly handles multi-color spools and passes `series`/`extraHexes` to `_ColorChip`.

- [ ] **Step 1: Write the failing test**

Add to `test/swatch_screen_test.dart`:

```dart
testWidgets('Multi-color spool (empty rgba, extra_colors set) appears in PLA SILK section', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: SwatchScreen(testSpools: [
        {
          'id': 10,
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
  // Section header for PLA SILK must appear.
  expect(find.text('PLA SILK'), findsOneWidget);
  // Must NOT show empty state.
  expect(find.text('No spools in inventory'), findsNothing);
});
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/swatch_screen_test.dart
```

Expected: FAIL — the multi-color spool is currently filtered (empty `rgba`), so the screen shows the empty state.

- [ ] **Step 3: Replace `_buildGroups` with the updated version**

Replace the entire `_buildGroups` method in `_SwatchScreenState`:

```dart
List<_MaterialGroup> _buildGroups(List<Map<String, dynamic>> spools) {
  final byMaterial = <String, List<_SpoolEntry>>{};
  for (final sp in spools) {
    final extraHexes = _parseExtraColors(sp['extra_colors']);
    final rawHex = _normalizeHex(sp['rgba'] as String?);
    // Multi-color spools have empty rgba; promote first extra color to primary.
    final hex = rawHex ?? (extraHexes.isNotEmpty ? extraHexes.first : null);
    if (hex == null) continue;
    final effectiveExtras =
        rawHex == null && extraHexes.isNotEmpty ? extraHexes.sublist(1) : extraHexes;
    final material = _str(sp['material']);
    final group = _normalizeGroup(material);
    byMaterial.putIfAbsent(group, () => []).add(_SpoolEntry(
      id: (sp['id'] as num?)?.toInt() ?? -1,
      material: material,
      brand: _str(sp['brand']),
      colorName: _str(sp['color_name']),
      hex: hex,
      series: _detectSeries(material),
      extraHexes: effectiveExtras,
    ));
  }

  final groups = <_MaterialGroup>[];
  for (final entry in byMaterial.entries) {
    // Composite key: all colors joined so multi-color variants don't merge.
    final byKey = <String, List<_SpoolEntry>>{};
    for (final s in entry.value) {
      final key = [s.hex, ...s.extraHexes].join('+');
      byKey.putIfAbsent(key, () => []).add(s);
    }
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
    // No flat sort here — ordering is handled by _buildHueBands at render time.
    groups.add(_MaterialGroup(label: entry.key, chips: chips));
  }
  groups.sort((a, b) {
    final ai = _groupOrder(a.label);
    final bi = _groupOrder(b.label);
    if (ai != bi) return ai.compareTo(bi);
    return a.label.compareTo(b.label);
  });
  return groups;
}
```

- [ ] **Step 4: Delete `_byHue`**

Remove the entire `_byHue` function (it is no longer called anywhere — sorting is handled by `_buildHueBands` in Task 4):

```dart
// DELETE this entire function:
int _byHue(_ColorChip a, _ColorChip b) {
  ...
}
```

- [ ] **Step 5: Run the test to confirm it passes**

```
flutter test test/swatch_screen_test.dart
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```
git add apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart apps/filament-assignment-flutter/test/swatch_screen_test.dart
git commit -m "feat(swatches): fix _buildGroups for multi-color spools and series detection"
```

---

### Task 3: Updated grouping constants and `_normalizeGroup`

**Files:**
- Modify: `apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart`
- Modify: `apps/filament-assignment-flutter/test/swatch_screen_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: updated `_kGroupOrder`, new `_kSpecialSeries` constant, updated `_normalizeGroup` that preserves special series as distinct section labels.

- [ ] **Step 1: Write the failing test**

Add to `test/swatch_screen_test.dart`:

```dart
testWidgets('PLA SILK and PLA METALLIC appear as separate sections from PLA+', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: SwatchScreen(testSpools: [
        {'id': 1, 'rgba': 'F6F6F0', 'material': 'PLA+', 'brand': 'A', 'color_name': 'Cool White', 'extra_colors': null},
        {'id': 2, 'rgba': 'B87333', 'material': 'PLA SILK', 'brand': 'A', 'color_name': 'Silk Copper', 'extra_colors': null},
        {'id': 3, 'rgba': '3C91E6', 'material': 'PLA METALLIC', 'brand': 'A', 'color_name': 'Titanium Blue', 'extra_colors': null},
      ]),
    ),
  );
  await tester.pump();
  expect(find.text('PLA+'), findsOneWidget);
  expect(find.text('PLA SILK'), findsOneWidget);
  expect(find.text('PLA METALLIC'), findsOneWidget);
  // Ensure PLA SILK is NOT collapsed into PLA+
  expect(find.text('PLA'), findsNothing);
});
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/swatch_screen_test.dart
```

Expected: FAIL — current `_normalizeGroup` collapses "PLA SILK" → "PLA".

- [ ] **Step 3: Replace the grouping constants**

In `swatch_screen.dart`, replace the two existing constants (`_kBases` and `_kGroupOrder`) and add `_kSpecialSeries`:

```dart
// Special series are matched by exact case-insensitive equality and preserved as-is.
const _kSpecialSeries = [
  'PLA GALAXY', 'PLA METALLIC', 'PLA SILK', 'PLA MATTE', 'PLA PRO',
];

// Base material normalization — longer/more-specific strings first.
const _kBases = ['PETG', 'PLA+', 'PLA', 'ABS', 'ASA', 'TPU', 'PEEK', 'HIPS', 'PVA', 'PC', 'PA'];

// Section display order.
const _kGroupOrder = [
  'PLA+', 'PLA PRO', 'PLA',
  'PLA SILK', 'PLA METALLIC', 'PLA MATTE', 'PLA GALAXY',
  'PETG', 'ABS', 'ASA', 'TPU', 'PA', 'PC', 'PEEK', 'PVA', 'HIPS',
];
```

- [ ] **Step 4: Replace `_normalizeGroup`**

```dart
String _normalizeGroup(String? raw) {
  final s = (raw ?? '').trim().toUpperCase();
  if (s.isEmpty) return 'Other';
  // Exact match against special series first (preserves the full label).
  for (final series in _kSpecialSeries) {
    if (s == series) return series;
  }
  // Fall back to base material normalization.
  for (final b in _kBases) {
    if (s.contains(b)) return b;
  }
  final cleaned = raw!.trim();
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}
```

- [ ] **Step 5: Run all tests**

```
flutter test test/swatch_screen_test.dart
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```
git add apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart apps/filament-assignment-flutter/test/swatch_screen_test.dart
git commit -m "feat(swatches): split material sections by special series (Silk, Metallic, etc.)"
```

---

### Task 4: `_buildHueBands` and hue matrix layout in `_MaterialSection`

**Files:**
- Modify: `apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart`
- Modify: `apps/filament-assignment-flutter/test/swatch_screen_test.dart`

**Interfaces:**
- Consumes: `_ColorChip.hex`, `_hexToColor` (existing).
- Produces: `_hslLightness(Color?)` → `double`; `_buildHueBands(List<_ColorChip>)` → `List<List<_ColorChip>>`; updated `_MaterialSection.build` using Column-of-Wraps.

- [ ] **Step 1: Write the failing test**

Add to `test/swatch_screen_test.dart`:

```dart
testWidgets('Chips with same hue appear before chips with darker lightness', (tester) async {
  // ivory (FFFFF0, very light) and chocolate (5C3317, very dark) — both warm/yellow-orange hue
  await tester.pumpWidget(
    const MaterialApp(
      home: SwatchScreen(testSpools: [
        {'id': 1, 'rgba': '5C3317', 'material': 'PLA+', 'brand': 'A', 'color_name': 'Chocolate', 'extra_colors': null},
        {'id': 2, 'rgba': 'FFFFF0', 'material': 'PLA+', 'brand': 'A', 'color_name': 'Ivory', 'extra_colors': null},
      ]),
    ),
  );
  await tester.pump();
  // Both chips render — screen is not empty.
  expect(find.text('No spools in inventory'), findsNothing);
  // Ivory name appears before Chocolate in the widget tree (light → dark).
  final ivoryPos = tester.getTopLeft(find.text('Ivory')).dy;
  final chocolatePos = tester.getTopLeft(find.text('Chocolate')).dy;
  // Same hue band → same row → same y. Light (Ivory, higher HSL L) appears to the left (lower x).
  expect(tester.getTopLeft(find.text('Ivory')).dx,
      lessThan(tester.getTopLeft(find.text('Chocolate')).dx));
});
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/swatch_screen_test.dart
```

Expected: FAIL — the current layout uses a flat hue sort with `Wrap`, so the positional assertion fails.

- [ ] **Step 3: Add `_hslLightness` helper**

Add to the helpers section of `swatch_screen.dart`:

```dart
double _hslLightness(Color? color) {
  if (color == null) return 0;
  return HSLColor.fromColor(color).lightness;
}
```

- [ ] **Step 4: Add `_buildHueBands` function**

Add to the helpers section:

```dart
/// Groups [chips] into hue bands in rainbow order and sorts each band
/// by HSL lightness descending (lightest first). Returns only non-empty bands.
List<List<_ColorChip>> _buildHueBands(List<_ColorChip> chips) {
  const bandNames = [
    'red', 'orange', 'yellow', 'green', 'teal',
    'blue', 'purple', 'pink', 'neutral',
  ];
  final bands = <String, List<_ColorChip>>{
    for (final b in bandNames) b: [],
  };

  for (final chip in chips) {
    final color = _hexToColor(chip.hex);
    if (color == null) {
      bands['neutral']!.add(chip);
      continue;
    }
    final hsv = HSVColor.fromColor(color);
    if (hsv.saturation < 0.15) {
      bands['neutral']!.add(chip);
      continue;
    }
    final hue = hsv.hue;
    final String band;
    if (hue >= 330 || hue < 20) {
      band = 'red';
    } else if (hue < 50) {
      band = 'orange';
    } else if (hue < 80) {
      band = 'yellow';
    } else if (hue < 160) {
      band = 'green';
    } else if (hue < 200) {
      band = 'teal';
    } else if (hue < 260) {
      band = 'blue';
    } else if (hue < 300) {
      band = 'purple';
    } else {
      band = 'pink';
    }
    bands[band]!.add(chip);
  }

  for (final bandChips in bands.values) {
    bandChips.sort((a, b) {
      final la = _hslLightness(_hexToColor(a.hex));
      final lb = _hslLightness(_hexToColor(b.hex));
      return lb.compareTo(la); // descending → lightest first
    });
  }

  return bandNames
      .map((b) => bands[b]!)
      .where((b) => b.isNotEmpty)
      .toList(growable: false);
}
```

- [ ] **Step 5: Replace `_MaterialSection.build` to use hue matrix layout**

Replace the `Widget build(BuildContext context)` method inside `_MaterialSection`:

```dart
@override
Widget build(BuildContext context) {
  final bands = _buildHueBands(group.chips);
  return Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 12),
        for (final band in bands)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in band)
                  _SwatchChip(
                    chip: chip,
                    onTap: () => onChipTap(chip),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        const Divider(height: 1, color: Color(0xFF27272A)),
      ],
    ),
  );
}
```

Note: `Wrap` (not `Row`) is used per band so chips never overflow the screen width. For typical inventories each band will have 1–5 chips so it renders as a single line per band, achieving the intended grid look.

- [ ] **Step 6: Run all tests**

```
flutter test test/swatch_screen_test.dart
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```
git add apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart apps/filament-assignment-flutter/test/swatch_screen_test.dart
git commit -m "feat(swatches): hue matrix layout — rainbow rows, light-to-dark columns"
```

---

### Task 5: `_SwatchPainter` — all visual effects and updated `_SwatchChip`

**Files:**
- Modify: `apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart`
- Modify: `apps/filament-assignment-flutter/test/swatch_screen_test.dart`

**Interfaces:**
- Consumes: `_SpoolSeries` (Task 1); `_ColorChip.extraHexes`, `_ColorChip.series` (Task 1); `_hexToColor`, `_contrastOn` (existing).
- Produces: `_SwatchPainter` CustomPainter; updated `_SwatchChip.build`.

- [ ] **Step 1: Add `dart:math` import**

Add at the top of `swatch_screen.dart` alongside the existing imports:

```dart
import 'dart:math' as math;
```

- [ ] **Step 2: Write the failing smoke test**

Add to `test/swatch_screen_test.dart`:

```dart
testWidgets('Screen renders all series types without throwing', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: SwatchScreen(testSpools: [
        // standard
        {'id': 1, 'rgba': 'F6F6F0', 'material': 'PLA+', 'brand': 'A', 'color_name': 'White', 'extra_colors': null},
        // silk single
        {'id': 2, 'rgba': 'B87333', 'material': 'PLA SILK', 'brand': 'A', 'color_name': 'Copper', 'extra_colors': null},
        // silk multi-color
        {'id': 3, 'rgba': '', 'material': 'PLA SILK', 'brand': 'A', 'color_name': 'Black-Gold', 'extra_colors': '111111,D4AF37'},
        // metallic
        {'id': 4, 'rgba': '3C91E6', 'material': 'PLA METALLIC', 'brand': 'A', 'color_name': 'Titanium Blue', 'extra_colors': null},
        // galaxy
        {'id': 5, 'rgba': '111111', 'material': 'PLA GALAXY', 'brand': 'A', 'color_name': 'Galaxy Black', 'extra_colors': null},
      ]),
    ),
  );
  await tester.pump();
  expect(tester.takeException(), isNull);
  expect(find.text('PLA+'), findsOneWidget);
  expect(find.text('PLA SILK'), findsOneWidget);
  expect(find.text('PLA METALLIC'), findsOneWidget);
  expect(find.text('PLA GALAXY'), findsOneWidget);
});
```

- [ ] **Step 3: Run test to confirm it fails**

```
flutter test test/swatch_screen_test.dart
```

Expected: PASS (screen already renders, tests from Tasks 1–4 still pass). This step establishes the baseline before the painter change.

- [ ] **Step 4: Add `_SwatchPainter` class**

Add this class to `swatch_screen.dart`, just before `_MaterialSection`:

```dart
class _SwatchPainter extends CustomPainter {
  const _SwatchPainter({
    required this.primaryColor,
    required this.extraColors,
    required this.series,
  });

  final Color primaryColor;
  final List<Color> extraColors;
  final _SpoolSeries series;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final clip = Path()..addOval(rect);

    canvas.save();
    canvas.clipPath(clip);

    final allColors = [primaryColor, ...extraColors];

    if (series == _SpoolSeries.galaxy) {
      // Galaxy always uses a near-black base regardless of stored color.
      canvas.drawOval(rect, Paint()..color = const Color(0xFF0A0A0F));
      _drawGalaxy(canvas, center, radius);
    } else if (allColors.length >= 2) {
      _drawSectors(canvas, center, radius, allColors);
    } else {
      canvas.drawOval(rect, Paint()..color = primaryColor);
    }

    if (series == _SpoolSeries.silk || series == _SpoolSeries.metallic) {
      _drawSheen(canvas, rect);
    }

    canvas.restore();

    // Outer zinc border — drawn outside the clip for a clean edge.
    canvas.drawCircle(
      center,
      radius - 0.75,
      Paint()
        ..color = const Color(0xFF3F3F46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Inset highlight ring — 0.5px white at 8% opacity just inside the border.
    // Gives the chip a physical "mounted disc" quality without any color glow.
    canvas.drawCircle(
      center,
      radius - 1.75,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawSectors(Canvas canvas, Offset center, double radius, List<Color> colors) {
    final n = colors.length;
    final sweep = 2 * math.pi / n;
    const startAngle = -math.pi / 2;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + i * sweep,
        sweep,
        true,
        Paint()..color = colors[i],
      );
    }
  }

  void _drawSheen(Canvas canvas, Rect rect) {
    final isSilk = series == _SpoolSeries.silk;
    final alpha = isSilk ? 0.45 : 0.28;
    final stops = isSilk
        ? const <double>[0.25, 0.50, 0.75]
        : const <double>[0.20, 0.50, 0.80];
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.transparent,
        Colors.white.withValues(alpha: alpha),
        Colors.transparent,
      ],
      stops: stops,
    ).createShader(rect);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.screen,
    );
  }

  void _drawGalaxy(Canvas canvas, Offset center, double radius) {
    final rng = math.Random(primaryColor.value);

    void star(Color color, double minR, double maxR) {
      // Reject-sample to keep stars within the circle.
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

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.primaryColor != primaryColor ||
      old.extraColors != extraColors ||
      old.series != series;
}
```

- [ ] **Step 5: Replace `_SwatchChip.build` to use `_SwatchPainter`**

Replace the `Widget build(BuildContext context)` method inside `_SwatchChip`:

```dart
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
                Text(
                  '$count',
                  style: TextStyle(
                    color: _contrastOn(color),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
            ],
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF71717A),
                fontSize: 9,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
```

- [ ] **Step 6: Run all tests**

```
flutter test test/swatch_screen_test.dart
```

Expected: all tests PASS, no exceptions.

- [ ] **Step 7: Manual visual check**

Run the app against the real Spoolman instance and verify:
- PLA SILK chips show a bright diagonal sheen stripe
- PLA METALLIC chips show a softer, wider sheen stripe
- Black-Gold and Red-Black silk chips show a split circle (two sectors)
- PLA GALAXY chips show a near-black circle with small star dots
- Standard chips look identical to before

- [ ] **Step 8: Commit**

```
git add apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart apps/filament-assignment-flutter/test/swatch_screen_test.dart
git commit -m "feat(swatches): _SwatchPainter with silk sheen, multi-color sectors, galaxy stars"
```

---

### Task 6: Multi-color hex rows in the detail modal

**Files:**
- Modify: `apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart`
- Modify: `apps/filament-assignment-flutter/test/swatch_screen_test.dart`

**Interfaces:**
- Consumes: `_ColorChip.extraHexes` (Task 1); `_showDetail` (existing); `_DetailRow` (existing).
- Produces: updated `_showDetail` that renders one `_DetailRow` per color for multi-color chips.

- [ ] **Step 1: Write the failing test**

Add to `test/swatch_screen_test.dart`:

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
  // Tap the chip — the SizedBox wrapping the chip is 52x* so we tap the label.
  await tester.tap(find.text('Black-Gold'));
  await tester.pumpAndSettle();
  // Expect two separate color rows.
  expect(find.text('#111111'), findsOneWidget);
  expect(find.text('#d4af37'), findsOneWidget);
  // 'Color hex' label must NOT appear (replaced by 'Color 1', 'Color 2').
  expect(find.text('Color hex'), findsNothing);
  expect(find.text('Color 1'), findsOneWidget);
  expect(find.text('Color 2'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/swatch_screen_test.dart
```

Expected: FAIL — modal currently shows a single 'Color hex' row.

- [ ] **Step 3: Update `_showDetail` color rows**

Inside `_showDetail`, replace this block:

```dart
_DetailRow(
  label: 'Color hex',
  value: '#${chip.hex}',
  mono: true,
),
```

with:

```dart
if (chip.extraHexes.isEmpty)
  _DetailRow(label: 'Color hex', value: '#${chip.hex}', mono: true)
else ...[
  _DetailRow(label: 'Color 1', value: '#${chip.hex}', mono: true),
  for (var i = 0; i < chip.extraHexes.length; i++)
    _DetailRow(
      label: 'Color ${i + 2}',
      value: '#${chip.extraHexes[i]}',
      mono: true,
    ),
],
```

- [ ] **Step 4: Run all tests**

```
flutter test test/swatch_screen_test.dart
```

Expected: all tests PASS.

- [ ] **Step 5: Manual visual check**

Tap a Black-Gold silk chip in the running app. The bottom sheet should show:
- Color 1: `#111111`
- Color 2: `#d4af37`

Tap a single-color chip (e.g. Silk Copper). The sheet should still show `Color hex: #b87333` (unchanged).

- [ ] **Step 6: Commit**

```
git add apps/filament-assignment-flutter/lib/src/ui/swatch_screen.dart apps/filament-assignment-flutter/test/swatch_screen_test.dart
git commit -m "feat(swatches): show per-color hex rows in detail modal for multi-color chips"
```

---

## Self-Review

**Spec coverage check:**

| Spec requirement | Covered by |
|---|---|
| `_SpoolSeries` enum | Task 1 |
| `_detectSeries` helper | Task 1 |
| `_parseExtraColors` helper | Task 1 |
| Multi-color empty-rgba fix (promote first extra to primary) | Task 2 |
| Composite grouping key | Task 2 |
| Remove flat `_byHue` sort | Task 2 |
| `_normalizeGroup` preserves special series | Task 3 |
| Updated `_kGroupOrder` with special series positions | Task 3 |
| `_buildHueBands` (9 hue bands + neutral) | Task 4 |
| `_hslLightness` | Task 4 |
| Column-of-Wraps layout in `_MaterialSection` | Task 4 |
| `_SwatchPainter` standard fill + border | Task 5 |
| Multi-color pie sectors (2-color split, N-color equal sectors) | Task 5 |
| Silk sheen (`BlendMode.screen`, alpha 0.45, tight stops) | Task 5 |
| Metallic sheen (alpha 0.28, wider stops) | Task 5 |
| Galaxy near-black fill + seeded star dots (16 white + 4 lavender) | Task 5 |
| Galaxy glow suppressed (no color-based box shadow) | Task 5 |
| Updated `_SwatchChip` uses `CustomPaint`, no color glow | Task 5 |
| Inset highlight ring replaces color glow (physical disc feel) | Task 5 |
| Multi-color hex rows in detail modal | Task 6 |

**Placeholder scan:** None found. All code blocks are complete.

**Type consistency:**
- `_SpoolSeries` defined in Task 1, used in Tasks 2, 5.
- `_ColorChip.extraHexes: List<String>` defined Task 1, consumed in Task 5 (`chip.extraHexes`) and Task 6.
- `_ColorChip.series: _SpoolSeries` defined Task 1, consumed in Task 5.
- `_buildHueBands(List<_ColorChip>)` defined Task 4, called in `_MaterialSection.build` in Task 4.
- `_hslLightness(Color?)` defined Task 4, called inside `_buildHueBands` in Task 4.
- `_SwatchPainter` defined Task 5, instantiated in `_SwatchChip.build` in Task 5.
- All consistent — no name drift.
