import 'dart:async';

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
      final raw = (await _api!.getArray('/spoolman/inventory/spools'))
          .whereType<Map<String, dynamic>>()
          .toList();
      if (!mounted) return;
      setState(() {
        _groups = _buildGroups(raw);
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
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF3F3F46)),
                      boxShadow: [
                        BoxShadow(
                          color: (color ?? Colors.transparent)
                              .withValues(alpha: 0.40),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      chip.name ?? 'Unknown color',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (chip.brand != null)
                _DetailRow(label: 'Brand', value: chip.brand!),
              if (chip.material != null)
                _DetailRow(label: 'Material', value: chip.material!),
              _DetailRow(
                label: 'Color hex',
                value: '#${chip.hex}',
                mono: true,
              ),
              _DetailRow(
                label: 'Spools',
                value:
                    '${chip.spoolIds.length} × ${chip.spoolIds.map((id) => '#$id').join(', ')}',
                mono: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialSection extends StatelessWidget {
  const _MaterialSection({required this.group, required this.onChipTap});

  final _MaterialGroup group;
  final ValueChanged<_ColorChip> onChipTap;

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
}

class _SwatchChip extends StatelessWidget {
  const _SwatchChip({required this.chip, required this.onTap});

  final _ColorChip chip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(chip.hex);
    final name = chip.name?.trim() ?? '';
    final count = chip.spoolIds.length;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color ?? const Color(0xFF3F3F46),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3F3F46),
                  width: 1.5,
                ),
                boxShadow: color != null
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.30),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: count > 1
                  ? Center(
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: _contrastOn(color),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    )
                  : null,
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

class _MaterialGroup {
  const _MaterialGroup({required this.label, required this.chips});

  final String label;
  final List<_ColorChip> chips;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

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

int _groupOrder(String label) {
  final i = _kGroupOrder.indexOf(label);
  return i < 0 ? _kGroupOrder.length : i;
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
