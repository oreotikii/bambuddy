import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../data/api_client.dart';

class SwatchScreen extends StatefulWidget {
  const SwatchScreen({super.key, this.refreshNonce = 0, this.testSpools});

  final int refreshNonce;

  /// Inject raw spool maps for widget tests, bypassing the API call.
  final List<Map<String, dynamic>>? testSpools;

  @override
  State<SwatchScreen> createState() => _SwatchScreenState();
}

class _SwatchScreenState extends State<SwatchScreen> {
  ApiClient? _api;
  List<_MaterialGroup> _groups = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant SwatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshNonce != oldWidget.refreshNonce) {
      unawaited(_load());
    }
  }

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
    try {
      _api ??= await ApiClient.create();
      final rawList = (await _api!.getArray('/spoolman/inventory/spools'))
          .whereType<Map<String, dynamic>>()
          .toList();

      // The list endpoint omits extra_colors for multi-color spools; Spoolman
      // represents these with rgba='808080'. Fetch one detail per unique
      // brand+colorName so each distinct filament gets its real hex set.
      final repIds = <String, int>{}; // brand::colorName → representative spool id
      for (final sp in rawList) {
        if (_normalizeHex(sp['rgba'] as String?) != '808080') continue;
        if (_parseExtraColors(sp['extra_colors']).isNotEmpty) continue;
        final key = '${_str(sp['brand']) ?? ''}::${_str(sp['color_name']) ?? ''}';
        repIds.putIfAbsent(key, () => (sp['id'] as num?)?.toInt() ?? -1);
      }

      // Parallel detail calls — one per unique brand+colorName combination.
      final keys = repIds.keys.toList();
      final fetched = await Future.wait(keys.map((k) async {
        final id = repIds[k]!;
        if (id < 0) return <String, dynamic>{};
        try {
          return await _api!.get('/spoolman/inventory/spools/$id');
        } catch (_) {
          return <String, dynamic>{};
        }
      }));

      // Build a lookup: brand::colorName → raw extra_colors value from detail.
      final detailExtras = <String, dynamic>{
        for (var i = 0; i < keys.length; i++)
          if (fetched[i]['extra_colors'] != null)
            keys[i]: fetched[i]['extra_colors'],
      };

      // Enrich list entries that are still placeholder-gray.
      final enriched = rawList.map((sp) {
        if (_normalizeHex(sp['rgba'] as String?) != '808080') return sp;
        if (_parseExtraColors(sp['extra_colors']).isNotEmpty) return sp;
        final key = '${_str(sp['brand']) ?? ''}::${_str(sp['color_name']) ?? ''}';
        final extras = detailExtras[key];
        if (extras == null) return sp;
        return {...sp, 'extra_colors': extras};
      }).toList();

      if (!mounted) return;
      setState(() {
        _groups = _buildGroups(enriched);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.detailMessage();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_MaterialGroup> _buildGroups(List<Map<String, dynamic>> spools) {
    final byMaterial = <String, List<_SpoolEntry>>{};
    for (final sp in spools) {
      final extraHexes = _parseExtraColors(sp['extra_colors']);
      final rawHex = _normalizeHex(sp['rgba'] as String?);
      // When extra_colors is present it contains the complete multi-color set.
      // rgba is then a Spoolman-derived summary/placeholder — ignore it so the
      // placeholder doesn't appear as a sector alongside the real colors.
      String? hex;
      List<String> effectiveExtras;
      if (extraHexes.isNotEmpty) {
        hex = extraHexes.first;
        effectiveExtras = extraHexes.sublist(1);
      } else {
        hex = rawHex;
        effectiveExtras = const [];
      }
      // Last resort: if still the Spoolman gray placeholder and the backend
      // didn't expose multi_color_hexes, derive approximate colors from the
      // descriptive color_name (e.g. "Black-Gold" → ['1a1a1a', 'c9a227']).
      if (hex == '808080' && effectiveExtras.isEmpty) {
        final nameColors = _parseColorsFromName(_str(sp['color_name']));
        if (nameColors.isNotEmpty) {
          hex = nameColors.first;
          effectiveExtras = nameColors.sublist(1);
        }
      }
      if (hex == null) continue;
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
      // Fallback for spools whose extra_colors couldn't be fetched: key on
      // brand+colorName so each distinct filament stays its own chip rather
      // than all collapsing into one gray swatch.
      final byKey = <String, List<_SpoolEntry>>{};
      for (final s in entry.value) {
        final String key;
        if (s.hex == '808080' && s.extraHexes.isEmpty) {
          key = '808080::${s.brand ?? ''}::${s.colorName ?? s.id}';
        } else {
          key = [s.hex, ...s.extraHexes].join('+');
        }
        byKey.putIfAbsent(key, () => []).add(s);
      }
      final chips = byKey.entries.map((e) {
        final ss = e.value;

        // Sub-group entries by brand+colorName to produce the variant list.
        // Spools with the same brand and color name collapse into one variant.
        final byVariant = <String, List<_SpoolEntry>>{};
        for (final s in ss) {
          final vk = '${s.brand ?? ''}::${s.colorName ?? ''}';
          byVariant.putIfAbsent(vk, () => []).add(s);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      appBar: AppBar(
        title: const Text(
          'Swatches',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFF18181B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF27272A)),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00C853)),
              )
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    color: const Color(0xFF00C853),
                    onRefresh: _load,
                    child: _groups.isEmpty
                        ? const _EmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: _groups.length,
                            itemBuilder: (ctx, i) => _MaterialSection(
                              group: _groups[i],
                              onChipTap: (chip) =>
                                  _showDetail(context, chip),
                            ),
                          ),
                  ),
      ),
    );
  }

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Square swatch matches chip shape.
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
                          // For multi-variant show material (primary name shown
                          // per variant row instead, to avoid duplication).
                          chip.variants.length > 1
                              ? chip.material ?? 'Multiple colors'
                              : chip.primaryName ?? 'Unknown color',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (chip.variants.length == 1 && chip.material != null)
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
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

              // ── Variants (one per unique brand + colorName) ─────────────────
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
}

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
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final clip = Path()..addRect(rect);

    canvas.save();
    canvas.clipPath(clip);

    final allColors = [primaryColor, ...extraColors];

    if (series == _SpoolSeries.galaxy) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFF0A0A0F));
      _drawGalaxy(canvas, center, radius);
    } else if (allColors.length >= 2) {
      _drawStripes(canvas, size, allColors);
    } else {
      canvas.drawRect(rect, Paint()..color = primaryColor);
    }

    if (series == _SpoolSeries.silk || series == _SpoolSeries.metallic) {
      _drawSheen(canvas, rect);
    }

    canvas.restore();
    // No per-chip border. The grid container provides edge definition.
  }

  void _drawStripes(Canvas canvas, Size size, List<Color> colors) {
    final n = colors.length;
    final w = size.width / n;
    for (var i = 0; i < n; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * w, 0, w, size.height),
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
    canvas.drawRect(
      rect,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.screen,
    );
  }

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
    // Layer 3 — five bright hot sparks near pure white.
    for (var i = 0; i < 5; i++) dot(const Color(0xFFEEEEFF), 1.4, 2.4);
  }

  @override
  bool shouldRepaint(_SwatchPainter old) =>
      old.primaryColor != primaryColor ||
      old.extraColors != extraColors ||
      old.series != series;
}

class _MaterialSection extends StatelessWidget {
  const _MaterialSection({required this.group, required this.onChipTap});

  final _MaterialGroup group;
  final ValueChanged<_ColorChip> onChipTap;

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
}

class _SwatchChip extends StatelessWidget {
  const _SwatchChip({required this.chip, required this.onTap});

  final _ColorChip chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryColor = _hexToColor(chip.hex) ?? const Color(0xFF3F3F46);
    final extraColors = chip.extraHexes
        .map((h) => _hexToColor(h) ?? const Color(0xFF3F3F46))
        .toList();
    // Use dark label on light chips, light label on dark chips.
    final labelColor = primaryColor.computeLuminance() > 0.4
        ? const Color(0x99000000)
        : const Color(0xCCFFFFFF);

    return GestureDetector(
      key: ValueKey('swatch-${chip.hex}'),
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _SwatchPainter(
              primaryColor: primaryColor,
              extraColors: extraColors,
              series: chip.series,
            ),
          ),
          Positioned(
            right: 3,
            bottom: 2,
            child: Text(
              '${chip.totalSpools}',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                color: labelColor,
                height: 1,
                shadows: const [Shadow(blurRadius: 3, color: Color(0x55000000))],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF71717A),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFF52525B),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF71717A),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                foregroundColor: Colors.black,
              ),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 64,
                color: Color(0xFF52525B),
              ),
              SizedBox(height: 16),
              Text(
                'No spools in inventory',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Add spools in Spoolman to see your color swatches here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF71717A), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

enum _SpoolSeries { standard, silk, metallic, galaxy, matte }

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

class _ColorChip {
  const _ColorChip({
    required this.hex,
    required this.variants,
    this.material,
    this.series = _SpoolSeries.standard,
    this.extraHexes = const [],
  });

  final String hex;
  final List<_SpoolVariant> variants;
  final String? material;
  final _SpoolSeries series;
  final List<String> extraHexes;

  /// Total number of physical spools across all variants.
  int get totalSpools => variants.fold(0, (n, v) => n + v.spoolIds.length);

  /// Primary display name: first variant's colorName.
  String? get primaryName => variants.isEmpty ? null : variants.first.colorName;
}

class _MaterialGroup {
  const _MaterialGroup({required this.label, required this.chips});

  final String label;
  final List<_ColorChip> chips;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

// Special series are matched by exact case-insensitive equality and preserved as-is.
const _kSpecialSeries = [
  'PLA GALAXY', 'PLA METALLIC', 'PLA SILK', 'PLA MATTE',
];

// Base material normalization — longer/more-specific strings first.
const _kBases = ['PETG', 'PLA+', 'PLA', 'ABS', 'ASA', 'TPU', 'PEEK', 'HIPS', 'PVA', 'PC', 'PA'];

// Section display order.
const _kGroupOrder = [
  'PLA+', 'PLA',
  'PLA SILK', 'PLA METALLIC', 'PLA MATTE', 'PLA GALAXY',
  'PETG', 'ABS', 'ASA', 'TPU', 'PA', 'PC', 'PEEK', 'PVA', 'HIPS',
];

String _normalizeGroup(String? raw) {
  final s = (raw ?? '').trim().toUpperCase();
  if (s.isEmpty) return 'Other';
  // PLA PRO folds into the PLA+ section.
  if (s == 'PLA PRO') return 'PLA+';
  // STARLIGHT is a brand variant of galaxy.
  if (s.contains('STARLIGHT')) return 'PLA GALAXY';
  // Exact match against special series first (preserves the full label).
  // Exact match only: "PLA SILK+" or "PLA SILK DUAL" fall through to _kBases.
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

int _groupOrder(String label) {
  final i = _kGroupOrder.indexOf(label);
  return i < 0 ? _kGroupOrder.length : i;
}

// Approximate hex values for common color words used in multi-color filament names.
const _kSimpleColors = <String, String>{
  'black':   '1a1a1a',
  'white':   'f0f0f0',
  'red':     'e63946',
  'blue':    '1d5fa3',
  'green':   '2ecc71',
  'yellow':  'f4d03f',
  'orange':  'f4834f',
  'purple':  '9b59b6',
  'pink':    'ff80ab',
  'gold':    'c9a227',
  'silver':  'bdc3c7',
  'copper':  'b87333',
  'magenta': 'e040fb',
  'cyan':    '00bcd4',
  'teal':    '009688',
  'brown':   '8d6e63',
};

/// Derives approximate hex colors from a descriptive filament name like "Black-Gold".
/// Splits on hyphens/spaces and looks up each word in [_kSimpleColors].
/// Returns the list only when all parts are recognised AND ≥ 2 colors are found;
/// returns empty otherwise so the chip stays gray rather than showing wrong colors.
List<String> _parseColorsFromName(String? name) {
  if (name == null || name.trim().isEmpty) return const [];
  final parts = name.toLowerCase().split(RegExp(r'[-\s]+'));
  final hexes = <String>[];
  for (final part in parts) {
    final hex = _kSimpleColors[part.trim()];
    if (hex == null) return const [];
    hexes.add(hex);
  }
  return hexes.length >= 2 ? hexes : const [];
}

String? _normalizeHex(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().replaceAll('#', '').toLowerCase();
  if (s.length == 6) return s;
  if (s.length == 8) return s.substring(0, 6);
  return null;
}

Color? _hexToColor(String? hex) {
  if (hex == null) return null;
  final v = int.tryParse(hex.replaceAll('#', ''), radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

Color _contrastOn(Color? bg) {
  if (bg == null) return Colors.white;
  return bg.computeLuminance() > 0.45
      ? Colors.black.withValues(alpha: 0.70)
      : Colors.white.withValues(alpha: 0.90);
}

_SpoolSeries _detectSeries(String? material) {
  final s = (material ?? '').toUpperCase();
  if (s.contains('SILK')) return _SpoolSeries.silk;
  if (s.contains('METALLIC')) return _SpoolSeries.metallic;
  if (s.contains('GALAXY') || s.contains('STARLIGHT')) return _SpoolSeries.galaxy;
  if (s.contains('MATTE')) return _SpoolSeries.matte;
  return _SpoolSeries.standard;
}

List<String> _parseExtraColors(dynamic raw) {
  // Accept both a JSON array (Spoolman multi_color_hexes) and a delimited string.
  final Iterable<String> tokens;
  if (raw is List) {
    tokens = raw.whereType<String>();
  } else if (raw is String && raw.trim().isNotEmpty) {
    tokens = raw.split(RegExp(r'[,;\s|]+'));
  } else {
    return const [];
  }
  return tokens
      .map((t) => t.trim().replaceAll('#', '').toLowerCase())
      .where((t) => t.length == 6 || t.length == 8)
      .map((t) => t.length == 8 ? t.substring(0, 6) : t)
      .toList(growable: false);
}

String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;

double _hslLightness(Color? color) {
  if (color == null) return 0;
  return HSLColor.fromColor(color).lightness;
}

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
    final hsl = HSLColor.fromColor(color);
    // Classify as neutral only if both HSL and HSV saturation are low
    // (avoids misclassifying near-white warm tones like ivory).
    if (hsv.saturation < 0.15 && hsl.saturation < 0.15) {
      bands['neutral']!.add(chip);
      continue;
    }
    final hue = hsv.hue;
    final String band;
    if (hue >= 330 || hue < 20) {
      band = 'red';
    } else if (hue < 65) {
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
