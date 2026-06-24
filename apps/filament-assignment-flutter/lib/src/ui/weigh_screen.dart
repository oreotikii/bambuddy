import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_exception.dart';
import '../core/weigh_math.dart';
import '../data/api_client.dart';
import '../data/assignment_repository.dart';
import 'camera_color_picker.dart';
import 'design_effects.dart';
import 'scanner_sheet.dart';

class WeighScreen extends StatefulWidget {
  const WeighScreen({
    super.key,
    this.repository,
    this.scannerLauncher,
    this.refreshNonce = 0,
  });

  final AssignmentRepository? repository;
  final CodeScannerLauncher? scannerLauncher;
  final int refreshNonce;

  @override
  State<WeighScreen> createState() => WeighScreenState();
}

class WeighScreenState extends State<WeighScreen> {
  final _spoolController = TextEditingController();
  final _weightController = TextEditingController();
  final _emptySpoolController = TextEditingController();
  AssignmentRepository? _repository;
  MobileSpool? _spool;
  MobileSpoolDetail? _detail;
  List<String> _locations = const [];
  String? _location;
  bool _busy = false;
  String? _error;
  String? _success;
  Color? _pickedColor;

  @override
  void didUpdateWidget(covariant WeighScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshNonce != oldWidget.refreshNonce) {
      unawaited(_refreshForPageSwitch());
    }
  }

  @override
  void dispose() {
    _spoolController.dispose();
    _weightController.dispose();
    _emptySpoolController.dispose();
    super.dispose();
  }

  Future<AssignmentRepository> _repo() async {
    final injected = widget.repository;
    if (injected != null) return injected;
    final existing = _repository;
    if (existing != null) return existing;
    final created = AssignmentApi(await ApiClient.create());
    _repository = created;
    return created;
  }

  Future<void> scanQr() => _scanSpool();

  Future<void> _refreshForPageSwitch() async {
    if (_busy) return;
    final code = _spoolController.text.trim();
    if (code.isNotEmpty) {
      _weightController.clear();
      await _resolveSpool();
      return;
    }
    setState(() {
      _error = null;
      _success = null;
    });
  }

  Future<void> _scanSpool() async {
    final launcher = widget.scannerLauncher ?? showCodeScanner;
    final code = await launcher(context, 'Scan spool');
    if (code == null || code.trim().isEmpty) return;
    _spoolController.text = code.trim();
    await _resolveSpool();
  }

  Future<void> _resolveSpool() async {
    final code = _spoolController.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final repo = await _repo();
      final spool = await repo.resolveSpool(code);
      // The mobile resolve summary omits the empty weight / color detail; fetch
      // the full inventory record for those. A failure here degrades the UI but
      // must not fail the resolve.
      MobileSpoolDetail? detail;
      try {
        detail = await repo.fetchSpoolDetail(spool.id);
      } on ApiException {
        detail = null;
      }
      if (!mounted) return;
      final empty = detail?.coreWeight;
      setState(() {
        _spool = spool;
        _detail = detail;
        _weightController.clear();
        _emptySpoolController.text = empty == null
            ? ''
            : empty.toStringAsFixed(0);
        _location =
            detail?.storageLocation ??
            spool.storageLocation ??
            spool.currentLocation;
      });
      await _loadLocations(repo);
    } on ApiException catch (e) {
      _setError(e.detailMessage());
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadLocations(AssignmentRepository repo) async {
    try {
      final fetched = await repo.fetchSpoolLocations();
      if (!mounted) return;
      final current = _location;
      final merged = <String>{
        ...fetched,
        if (current != null && current.trim().isNotEmpty) current.trim(),
      }.toList()..sort();
      setState(() => _locations = merged);
    } on ApiException {
      // Spoolman disabled/unavailable — keep the current location only.
    } catch (_) {
      // Locations are a convenience; never block the weigh flow.
    }
  }

  Future<void> _save() async {
    final spool = _spool;
    if (spool == null || _busy) return;
    final repo = await _repo();
    final detail = _detail;

    final hasWeight = WeighMath.isValidWeight(_weightController.text);
    final grams = WeighMath.parseWeight(_weightController.text, double.nan);

    final coreWeight = detail?.coreWeight;
    final hasEmpty = WeighMath.isValidWeight(_emptySpoolController.text);
    final emptyGrams = WeighMath.parseWeight(
      _emptySpoolController.text,
      double.nan,
    );
    final emptyChanged =
        hasEmpty &&
        (coreWeight == null || (emptyGrams - coreWeight).abs() >= 0.05);

    final location = _location;
    final storedLocation =
        detail?.storageLocation ??
        spool.storageLocation ??
        spool.currentLocation;
    final locationChanged =
        location != null &&
        location.trim().isNotEmpty &&
        location != storedLocation;

    if (!hasWeight && !emptyChanged && !locationChanged && !_colorChanged) return;

    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    final messages = <String>[];
    bool saved = false;
    try {
      if (hasWeight || emptyChanged || locationChanged) {
        await repo.updateSpoolWeigh(
          spool.id,
          measuredWeight: hasWeight ? grams : null,
          emptySpoolWeight: emptyChanged ? emptyGrams : null,
          location: locationChanged ? location.trim() : null,
        );
        if (hasWeight) messages.add('weight');
        if (emptyChanged) messages.add('empty spool weight');
        if (locationChanged) messages.add('location');
      }
      if (_colorChanged) {
        final hex = _colorToHex(_pickedColor!);
        await repo.updateSpoolColor(spool.id, hex);
        messages.add('color');
      }
      if (!mounted) return;
      final summary = messages.isEmpty
          ? 'Updated'
          : 'Updated ${messages.join(', ')}';
      setState(() {
        _success = '$summary for spool #${spool.id}';
        _pickedColor = null;
      });
      saved = true;
    } on ApiException catch (e) {
      _setError(e.detailMessage());
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (saved) await _resolveSpool();
  }

  Future<void> _pickColorFromCamera() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;
    final color = await showCameraColorPicker(context, File(photo.path));
    if (color != null && mounted) setState(() => _pickedColor = color);
  }

  void _reset() {
    _spoolController.clear();
    _weightController.clear();
    _emptySpoolController.clear();
    setState(() {
      _spool = null;
      _detail = null;
      _location = null;
      _locations = const [];
      _error = null;
      _success = null;
      _pickedColor = null;
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  bool get _hasChanges {
    final spool = _spool;
    if (spool == null) return false;
    if (WeighMath.isValidWeight(_weightController.text)) return true;

    final coreWeight = _detail?.coreWeight;
    final hasEmpty = WeighMath.isValidWeight(_emptySpoolController.text);
    final emptyGrams = WeighMath.parseWeight(
      _emptySpoolController.text,
      double.nan,
    );
    if (hasEmpty &&
        (coreWeight == null || (emptyGrams - coreWeight).abs() >= 0.05)) {
      return true;
    }

    final loc = _location;
    final stored =
        _detail?.storageLocation ??
        spool.storageLocation ??
        spool.currentLocation;
    if (loc != null && loc.trim().isNotEmpty && loc != stored) return true;

    if (_colorChanged) return true;

    return false;
  }

  bool get _colorChanged {
    final picked = _pickedColor;
    if (picked == null) return false;
    final current = _parseHexColor(_spool?.rgba);
    if (current == null) return true;
    return (picked.r * 255).round() != (current.r * 255).round() ||
        (picked.g * 255).round() != (current.g * 255).round() ||
        (picked.b * 255).round() != (current.b * 255).round();
  }

  bool get _weightBelowEmpty {
    if (!WeighMath.isValidWeight(_weightController.text)) return false;
    if (!WeighMath.isValidWeight(_emptySpoolController.text)) return false;
    final grams = WeighMath.parseWeight(_weightController.text, double.nan);
    final emptyGrams = WeighMath.parseWeight(
      _emptySpoolController.text,
      double.nan,
    );
    return grams < emptyGrams;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      appBar: AppBar(
        title: const Text(
          'Weigh spool',
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
        actions: [
          IconButton(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, color: Color(0xFF71717A)),
            tooltip: 'Reset',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_error != null) ...[
              _MessageBanner(message: _error!, isError: true),
              const SizedBox(height: 12),
            ],
            if (_success != null) ...[
              _MessageBanner(message: _success!, isError: false),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey('spool-code-field'),
              controller: _spoolController,
              enabled: !_busy,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _resolveSpool(),
              decoration: InputDecoration(
                hintText: 'Spool code',
                prefixIcon: const Icon(Icons.qr_code_2),
                suffixIcon: IconButton(
                  tooltip: 'Resolve spool',
                  icon: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  onPressed: _busy ? null : _resolveSpool,
                ),
                filled: true,
                fillColor: const Color(0xFF1F1F23),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E2E34)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E2E34)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF00C853),
                    width: 1.5,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF27272A)),
                ),
                labelStyle: const TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelStyle: const TextStyle(
                  color: Color(0xFF00C853),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                hintStyle: const TextStyle(
                  color: Color(0xFF52525B),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIconColor: const Color(0xFF52525B),
                suffixIconColor: const Color(0xFF52525B),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
            ),
            if (_spool != null) ...[
              const SizedBox(height: 16),
              _SpoolCard(spool: _spool!, detail: _detail),
              const SizedBox(height: 16),
              FrostedPanel(
                radius: 14,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Update spool',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('weight-grams-field'),
                      controller: _weightController,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Measured weight (g)',
                        prefixIcon: Icon(Icons.scale_outlined),
                        filled: true,
                        fillColor: Color(0xFF1F1F23),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFF2E2E34)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFF2E2E34)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: Color(0xFF00C853),
                            width: 1.5,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFF27272A)),
                        ),
                        labelStyle: TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        floatingLabelStyle: TextStyle(
                          color: Color(0xFF00C853),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        hintStyle: TextStyle(
                          color: Color(0xFF52525B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIconColor: Color(0xFF52525B),
                        suffixIconColor: Color(0xFF52525B),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                    ),
                    if (_weightBelowEmpty) ...[
                      const SizedBox(height: 8),
                      const _MessageBanner(
                        message:
                            'Measured weight is below the empty spool weight. '
                            'Bambuddy will not save this value.',
                        isError: true,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('empty-spool-field'),
                      controller: _emptySpoolController,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Empty spool weight (g)',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        floatingLabelStyle: TextStyle(
                          color: Color(0xFF00C853),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                        filled: true,
                        fillColor: Color(0xFF1F1F23),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFF2E2E34)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFF2E2E34)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(
                            color: Color(0xFF00C853),
                            width: 1.5,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                          borderSide: BorderSide(color: Color(0xFF27272A)),
                        ),
                        labelStyle: TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        hintStyle: TextStyle(
                          color: Color(0xFF52525B),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIconColor: Color(0xFF52525B),
                        suffixIconColor: Color(0xFF52525B),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SwatchColorRow(
                      currentHex: _spool?.rgba,
                      pickedColor: _pickedColor,
                      enabled: !_busy,
                      onPick: _pickColorFromCamera,
                      onClear: () => setState(() => _pickedColor = null),
                    ),
                    const SizedBox(height: 12),
                    _LocationField(
                      spoolId: _spool!.id,
                      locations: _locations,
                      selected: _location,
                      enabled: !_busy,
                      onChanged: (v) => setState(() => _location = v),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: const Color(0xFF00C853),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(
                          0xFF00C853,
                        ).withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _hasChanges && !_busy && !_weightBelowEmpty
                          ? _save
                          : null,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFFFFFF),
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Update spool'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.spoolId,
    required this.locations,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final int spoolId;
  final List<String> locations;
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <String>{
      ...locations,
      if (selected != null && selected!.trim().isNotEmpty) selected!.trim(),
    }.toList()..sort();
    final initial = selected != null && items.contains(selected)
        ? selected
        : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('location-field-$spoolId'),
      initialValue: initial,
      items: [
        for (final loc in items) DropdownMenuItem(value: loc, child: Text(loc)),
      ],
      onChanged: enabled ? onChanged : null,
      decoration: const InputDecoration(
        labelText: 'Location',
        prefixIcon: Icon(Icons.place_outlined),
        filled: true,
        fillColor: Color(0xFF1F1F23),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF2E2E34)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF2E2E34)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF00C853), width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFF27272A)),
        ),
        labelStyle: TextStyle(
          color: Color(0xFF71717A),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          color: Color(0xFF00C853),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: TextStyle(
          color: Color(0xFF52525B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        prefixIconColor: Color(0xFF52525B),
        suffixIconColor: Color(0xFF52525B),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
    );
  }
}

class _SpoolCard extends StatelessWidget {
  const _SpoolCard({required this.spool, required this.detail});

  final MobileSpool spool;
  final MobileSpoolDetail? detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final pct = _remainingPercent(spool);
    final primary = _filamentColor(spool) ?? cs.primary;
    final swatches = _filamentSwatches(spool, detail);
    final displayColorName = _firstNonEmpty(detail?.subtype, spool.colorName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      (spool.brand != null && spool.brand!.trim().isNotEmpty)
                          ? spool.brand!
                          : 'Spool #${spool.id}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF71717A),
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _PercentBadge(percent: pct),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                (spool.material != null && spool.material!.trim().isNotEmpty)
                    ? spool.material!
                    : 'Unknown',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _ColorRow(
                colorName: displayColorName,
                swatches: swatches,
                effect: detail?.effectType,
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (spool.remainingGrams != null)
                    '${spool.remainingGrams!.toStringAsFixed(0)} g left',
                  if (spool.currentLocation != null) spool.currentLocation!,
                ].join('  ·  '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF52525B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _SpoolSideView(
          color: primary,
          fill: pct ?? 1.0,
          surface: cs.surfaceContainerHigh,
          track: cs.outline,
        ),
      ],
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.colorName,
    required this.swatches,
    required this.effect,
  });

  final String? colorName;
  final List<Color> swatches;
  final String? effect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasName = colorName != null && colorName!.trim().isNotEmpty;
    final hasEffect = effect != null && effect!.trim().isNotEmpty;
    if (swatches.isEmpty && !hasName && !hasEffect) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final c in swatches.take(6)) _Swatch(color: c),
        if (hasName)
          Text(
            colorName!,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (hasEffect)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Color.lerp(cs.primary, cs.surface, 0.85),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              effect!,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2E2E34)),
      ),
    );
  }
}

class _PercentBadge extends StatelessWidget {
  const _PercentBadge({required this.percent});

  final double? percent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(percent, cs);
    final text = percent == null ? '—' : '${(percent! * 100).round()}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color.lerp(color, const Color(0xFF18181B), 0.82),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  Color _statusColor(double? pct, ColorScheme cs) {
    if (pct == null) return cs.onSurfaceVariant;
    if (pct < 0.05) return cs.error;
    if (pct < 0.25) return const Color(0xFFE65100);
    if (pct < 0.5) return const Color(0xFFB8860B);
    return const Color(0xFF2E7D32);
  }
}

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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = size.shortestSide / 2;
    final coreR = outer * 0.22;
    final margin = outer * 0.05;
    final maxR = outer - margin;
    final fillR = coreR + (maxR - coreR) * fill.clamp(0.0, 1.0);
    final winding = Color.lerp(color, Colors.black, 0.28)!;

    // Flange (the two side plates of the spool).
    canvas.drawCircle(center, outer, Paint()..color = track);
    canvas.drawCircle(
      center,
      outer - margin * 0.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Color.lerp(track, surface, 0.35)!,
    );

    // Wound filament — radius grows with the amount left.
    canvas.drawCircle(center, fillR, Paint()..color = color);
    for (var i = 1; i <= 3; i++) {
      final r = coreR + (fillR - coreR) * (i / 4);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = winding,
      );
    }

    // Core hole (reveal the card) + hub ring.
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

  @override
  bool shouldRepaint(covariant _SpoolSidePainter old) =>
      old.color != color ||
      old.fill != fill ||
      old.surface != surface ||
      old.track != track;
}

double? _remainingPercent(MobileSpool spool) {
  final remaining = spool.remainingGrams;
  final capacity = spool.labelWeight;
  if (remaining == null || capacity == null || capacity <= 0) return null;
  final ratio = remaining / capacity;
  if (ratio < 0) return 0;
  if (ratio > 1) return 1;
  return ratio;
}

Color? _parseHexColor(String? hex) {
  if (hex == null) return null;
  var value = hex.trim();
  if (value.isEmpty) return null;
  if (value.startsWith('#')) value = value.substring(1);
  if (value.length == 6) {
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }
  if (value.length == 8) {
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    // Interpret as RRGGBBAA.
    final r = (parsed >> 24) & 0xFF;
    final g = (parsed >> 16) & 0xFF;
    final b = (parsed >> 8) & 0xFF;
    final a = parsed & 0xFF;
    return Color.fromARGB(a, r, g, b);
  }
  return null;
}

Color? _filamentColor(MobileSpool spool) => _parseHexColor(spool.rgba);

List<Color> _filamentSwatches(MobileSpool spool, MobileSpoolDetail? detail) {
  final colors = <Color>[];
  final primary = _parseHexColor(spool.rgba);
  if (primary != null) colors.add(primary);
  if (detail != null) {
    for (final hex in detail.extraColorHexes) {
      final parsed = _parseHexColor(hex);
      if (parsed != null && !colors.contains(parsed)) colors.add(parsed);
    }
  }
  return colors;
}

String? _firstNonEmpty(String? preferred, String? fallback) {
  final first = preferred?.trim();
  if (first != null && first.isNotEmpty) return first;
  final second = fallback?.trim();
  if (second != null && second.isNotEmpty) return second;
  return null;
}

class _SwatchColorRow extends StatelessWidget {
  const _SwatchColorRow({
    required this.currentHex,
    required this.pickedColor,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final String? currentHex;
  final Color? pickedColor;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final currentColor = _parseHexColor(currentHex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E2E34)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.palette_outlined,
            color: Color(0xFF52525B),
            size: 20,
          ),
          const SizedBox(width: 12),
          if (currentColor != null)
            _Swatch(color: currentColor)
          else
            const Text(
              'No color',
              style: TextStyle(color: Color(0xFF52525B), fontSize: 13),
            ),
          if (pickedColor != null) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward,
              size: 14,
              color: Color(0xFF52525B),
            ),
            const SizedBox(width: 6),
            _Swatch(color: pickedColor!),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: enabled ? onClear : null,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: Color(0xFF71717A),
                ),
              ),
            ),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: enabled ? onPick : null,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00C853),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.camera_alt_outlined, size: 16),
            label: const Text(
              'Pick',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

String _colorToHex(Color c) =>
    (c.r * 255).round().toRadixString(16).padLeft(2, '0') +
    (c.g * 255).round().toRadixString(16).padLeft(2, '0') +
    (c.b * 255).round().toRadixString(16).padLeft(2, '0');

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final background = isError
        ? const Color(0xFF2C1414)
        : const Color(0xFF0D2818);
    final borderColor = isError
        ? const Color(0xFF7F1D1D)
        : const Color(0xFF166534);
    final textColor = isError
        ? const Color(0xFFFCA5A5)
        : const Color(0xFF86EFAC);
    final icon = isError
        ? Icons.error_outline_rounded
        : Icons.check_circle_outline_rounded;
    final iconColor = isError
        ? const Color(0xFFF87171)
        : const Color(0xFF4ADE80);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
