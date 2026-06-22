import 'dart:async';
import 'dart:ui';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_model.dart';
import '../core/api_exception.dart';
import '../data/api_client.dart';
import 'crav3d_logo.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.apiClientFactory});

  final Future<ApiClient> Function()? apiClientFactory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _pollInterval = Duration(seconds: 8);

  ApiClient? _api;
  Timer? _timer;
  List<PrinterCard> _cards = const [];
  bool _loading = true;
  String? _banner;
  Color? _bannerColor;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _refresh(true);
    if (mounted) {
      _timer?.cancel();
      _timer = Timer.periodic(_pollInterval, (_) => _refresh(false));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _api?.close();
    super.dispose();
  }

  Future<void> _refresh(bool fromUser) async {
    try {
      _api ??= await (widget.apiClientFactory?.call() ?? ApiClient.create());
      final cards = await _fetchCards(_api!);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
        _banner = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        final model = context.read<AppModel>();
        await model.signOut();
        return;
      }
      setState(() {
        _loading = false;
        _banner = 'Could not refresh: ${e.detailMessage()}';
        _bannerColor = Theme.of(context).colorScheme.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _banner = 'Could not refresh: $e';
        _bannerColor = Theme.of(context).colorScheme.error;
      });
    }
  }

  Future<List<PrinterCard>> _fetchCards(ApiClient api) async {
    final printers = (await api.getArray(
      '/printers/',
    )).cast<Map<String, dynamic>>();

    final statuses = await Future.wait(
      printers.map((p) async {
        final id = (p['id'] as num?)?.toInt() ?? -1;
        if (id < 0) return null;
        try {
          return await api.get('/printers/$id/status');
        } catch (_) {
          return null;
        }
      }),
    );

    final slotToSpool = <String, int>{};
    final slotAssignments = <_SlotAssignment>[];
    final spoolById = <int, Map<String, dynamic>>{};
    try {
      final slots = (await api.getArray(
        '/spoolman/inventory/slot-assignments/all',
      )).cast<Map<String, dynamic>>();
      for (final s in slots) {
        final printerId = _toInt(s['printer_id']) ?? 0;
        final amsId = _toInt(s['ams_id']) ?? 0;
        final trayId = _toInt(s['tray_id']) ?? _toInt(s['slot']) ?? 0;
        final spoolId =
            _toInt(s['spoolman_spool_id']) ?? _toInt(s['spool_id']) ?? 0;
        if (printerId == 0 || spoolId == 0) continue;
        final key = _slotKey(printerId, amsId, trayId);
        slotToSpool[key] = spoolId;
        slotAssignments.add(
          _SlotAssignment(
            printerId: printerId,
            amsId: amsId,
            trayId: trayId,
            spoolId: spoolId,
          ),
        );
      }
      final spools = (await api.getArray(
        '/spoolman/inventory/spools',
      )).cast<Map<String, dynamic>>();
      for (final sp in spools) {
        final id = (sp['id'] as num?)?.toInt() ?? 0;
        if (id != 0) spoolById[id] = sp;
      }
    } on ApiException {
      // Spoolman disabled/unavailable — render without inventory links.
    }

    final cards = <PrinterCard>[];
    for (var i = 0; i < printers.length; i++) {
      cards.add(
        _buildCard(
          printers[i],
          statuses[i],
          slotToSpool,
          slotAssignments,
          spoolById,
        ),
      );
    }
    cards.sort((a, b) {
      final byTier = _attentionTier(a).compareTo(_attentionTier(b));
      if (byTier != 0) return byTier;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return cards;
  }

  /// Sort priority: 0 = needs attention (plate clear / fault / failed),
  /// 1 = printing, 2 = idle/standby, 3 = offline.
  static int _attentionTier(PrinterCard c) {
    if (c.awaitingClear || c.hasFault) return 0;
    if (c.stateLabel == 'Printing') return 1;
    if (c.online) return 2;
    return 3;
  }

  PrinterCard _buildCard(
    Map<String, dynamic> printer,
    Map<String, dynamic>? status,
    Map<String, int> slotToSpool,
    List<_SlotAssignment> slotAssignments,
    Map<int, Map<String, dynamic>> spoolById,
  ) {
    final card = PrinterCard()
      ..id = (printer['id'] as num?)?.toInt() ?? -1
      ..name = (printer['name'] as String?) ?? 'Printer'
      ..model = printer['model'] as String?;

    if (status == null) {
      card.connected = false;
      card.stateLabel = 'Offline';
      return card;
    }
    card.connected = status['connected'] == true;
    card.online = card.connected;
    card.rawState = status['state'] as String?;
    card.stateLabel = _stateLabel(card.connected, card.rawState);
    card.awaitingClear = status['awaiting_plate_clear'] == true;
    final hms = status['hms_errors'];
    card.hasFault =
        (hms is List && hms.isNotEmpty) ||
        (card.rawState != null && card.rawState!.toUpperCase() == 'FAILED');
    final progress = status['progress'];
    card.progress = progress is num ? progress.toDouble() : -1.0;
    card.subtaskName = status['subtask_name'] as String?;
    final temps = status['temperatures'] as Map<String, dynamic>?;
    if (temps != null) {
      final nozzle = temps['nozzle'];
      card.nozzleTemp = nozzle is num ? nozzle.toDouble() : null;
      final bed = temps['bed'];
      card.bedTemp = bed is num ? bed.toDouble() : null;
    }

    final printerId = card.id;
    final ams = status['ams'] as List<dynamic>?;
    if (ams != null) {
      for (final raw in ams) {
        if (raw is! Map<String, dynamic>) continue;
        final amsId = (raw['id'] as num?)?.toInt() ?? 0;
        final isAmsHt = raw['is_ams_ht'] == true;
        final trays = raw['tray'] as List<dynamic>?;
        if (trays == null) continue;
        for (var t = 0; t < trays.length; t++) {
          final tray = trays[t] as Map<String, dynamic>?;
          if (tray == null) continue;
          final slot = _buildSlot(
            printerId,
            amsId,
            (tray['id'] as num?)?.toInt() ?? t,
            isAmsHt,
            tray,
            slotToSpool,
            spoolById,
          );
          if (slot.hasAssignedSpool) card.slots.add(slot);
        }
      }
    }
    final vt = status['vt_tray'] as List<dynamic>?;
    if (vt != null) {
      for (final raw in vt) {
        if (raw is! Map<String, dynamic>) continue;
        final slot = _buildSlot(
          printerId,
          255,
          (raw['id'] as num?)?.toInt() ?? 0,
          false,
          raw,
          slotToSpool,
          spoolById,
        );
        if (slot.hasAssignedSpool) card.slots.add(slot);
      }
    }
    final renderedKeys = card.slots
        .map((slot) => _slotKey(printerId, slot.amsId, slot.trayId))
        .toSet();
    for (final assignment in slotAssignments) {
      if (assignment.printerId != printerId || assignment.amsId != 255) {
        continue;
      }
      final key = _slotKey(
        assignment.printerId,
        assignment.amsId,
        assignment.trayId,
      );
      if (renderedKeys.contains(key)) continue;
      final slot = _buildSlot(
        printerId,
        assignment.amsId,
        assignment.trayId,
        false,
        const <String, dynamic>{},
        slotToSpool,
        spoolById,
      );
      if (slot.hasAssignedSpool) card.slots.add(slot);
    }
    return card;
  }

  SlotInfo _buildSlot(
    int printerId,
    int amsId,
    int trayId,
    bool isAmsHt,
    Map<String, dynamic> tray,
    Map<String, int> slotToSpool,
    Map<int, Map<String, dynamic>> spoolById,
  ) {
    final slot = SlotInfo()
      ..amsId = amsId
      ..trayId = trayId
      ..label = amsId == 255
          ? 'External Spool'
          : '${isAmsHt ? 'AMS-HT' : 'AMS${amsId + 1}'} · T${trayId + 1}'
      ..colorHex = tray['tray_color'] as String?
      ..material = _firstNonEmpty([
        tray['tray_sub_brands'] as String?,
        tray['tray_type'] as String?,
      ])
      ..remainPercent = _toDouble(tray['remain'])
      ..trayState = _toInt(tray['state']);

    final spoolId = slotToSpool[_slotKey(printerId, amsId, trayId)];
    if (spoolId != null) {
      slot
        ..spoolId = spoolId
        ..occupied = true;
      final spool = spoolById[spoolId];
      if (spool != null) {
        slot
          ..spoolBrand = spool['brand'] as String?
          ..spoolMaterial = spool['material'] as String?
          ..spoolSubtype = spool['subtype'] as String?
          ..spoolColorName = spool['color_name'] as String?
          ..spoolRgba = spool['rgba'] as String?
          ..spoolRemaining = _remainingGrams(spool)
          ..spoolLabelWeight = _toInt(spool['label_weight']);
      }
    }
    return slot;
  }

  static double? _remainingGrams(Map<String, dynamic> spool) {
    final label = spool['label_weight'];
    final used = spool['weight_used'];
    if (label is num && used is num) {
      final r = label.toDouble() - used.toDouble();
      return r < 0 ? 0.0 : r;
    }
    return null;
  }

  static String _slotKey(int printerId, int amsId, int trayId) =>
      '$printerId:$amsId:$trayId';

  static String _stateLabel(bool connected, String? state) {
    if (!connected) return 'Offline';
    if (state == null || state.isEmpty) return 'Standby';
    switch (state.toUpperCase()) {
      case 'RUNNING':
      case 'PRINTING':
        return 'Printing';
      case 'PAUSE':
        return 'Paused';
      case 'FINISH':
      case 'FINISHING':
      case 'FINISHED':
        return 'Finished';
      case 'IDLE':
        return 'Idle';
      case 'SLICING':
        return 'Slicing';
      default:
        final s = state.toLowerCase();
        return s.isEmpty ? state : '${s[0].toUpperCase()}${s.substring(1)}';
    }
  }

  static String? _firstNonEmpty(List<String?> vals) {
    for (final v in vals) {
      if (v != null && v.isNotEmpty && v != 'null') return v;
    }
    return null;
  }

  static double? _toDouble(dynamic v) =>
      v is num ? v.toDouble() : (v == null ? null : double.tryParse('$v'));
  static int? _toInt(dynamic v) =>
      v is num ? v.toInt() : (v == null ? null : int.tryParse('$v'));

  int _parseColorHex(String? hex) {
    if (hex == null) return 0xFF52525B;
    var h = hex.replaceAll('#', '').trim().toUpperCase();
    if (h.length >= 6) {
      final v = int.tryParse(h.substring(0, 6), radix: 16);
      if (v != null) return 0xFF000000 | v;
    }
    return 0xFF52525B;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        titleSpacing: 16,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Crav3dLogo(width: 168, color: Colors.white),
            const SizedBox(height: 3),
            Text(
              'BAMBUDDY',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 10,
                fontWeight: FontWeight.w200,
                letterSpacing: 2,
                height: 1,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_banner != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _bannerColor?.withValues(alpha: 0.12),
              child: Text(
                _banner!,
                style: TextStyle(color: _bannerColor ?? cs.error, fontSize: 13),
              ),
            ),
          if (_cards.isNotEmpty) _metricsRow(cs),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    color: cs.primary,
                    onRefresh: () => _refresh(true),
                    child: _cards.isEmpty
                        ? _emptyState(cs)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                            itemCount: _cards.length + 1,
                            itemBuilder: (_, i) {
                              if (i == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    bottom: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Workshop printers',
                                        style: TextStyle(
                                          color: cs.onSurface,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'pull to refresh',
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _buildCardWidget(cs, _cards[i - 1]),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _metricsRow(ColorScheme cs) {
    int printing = 0, idle = 0, plate = 0, fault = 0;
    for (final c in _cards) {
      if (c.hasFault) {
        fault++;
      } else if (c.awaitingClear) {
        plate++;
      } else if (c.stateLabel == 'Printing') {
        printing++;
      } else if (c.online) {
        idle++;
      }
    }
    return Container(
      width: double.infinity,
      color: cs.surfaceContainer,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (fault > 0) _metric('$fault fault', cs.error),
          if (plate > 0) _metric('$plate plate', cs.tertiary),
          _metric('$printing printing', cs.primary),
          _metric('$idle idle', cs.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _metric(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCardWidget(ColorScheme cs, PrinterCard card) {
    final isA1 = (card.model ?? '').toUpperCase().contains('A1');
    final modelName = _firstNonEmpty([card.model]);
    final subtitle =
        _firstNonEmpty([
          card.subtaskName,
          card.online ? 'Ready for spool assignment' : 'No connection',
        ]) ??
        '';
    return Card(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    isA1 ? Icons.view_in_ar_outlined : Icons.print_outlined,
                    size: 34,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 20,
                        child: AutoSizeText(
                          card.name,
                          maxLines: 1,
                          minFontSize: 12,
                          overflow: TextOverflow.ellipsis,
                          wrapWords: false,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (modelName != null)
                            Flexible(child: _modelChip(cs, card.id, modelName))
                          else
                            Flexible(
                              child: Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          _statusChip(cs, card),
                        ],
                      ),
                      if (card.nozzleTemp != null || card.bedTemp != null) ...[
                        const SizedBox(height: 8),
                        _temperatureBanners(card),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (card.progress >= 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (card.progress / 100).clamp(0.02, 1.0),
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerLow,
                ),
              ),
            ],
            if (card.online && card.id > 0 && card.awaitingClear) ...[
              const SizedBox(height: 10),
              _GlassClearPlateButton(onPressed: () => _clearPlate(card.id)),
            ],
            if (card.slots.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  'LOADED FILAMENTS',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _slotList(cs, card),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modelChip(ColorScheme cs, int printerId, String modelName) {
    return Container(
      key: ValueKey('model-chip-$printerId'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline),
      ),
      child: Text(
        modelName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusChip(ColorScheme cs, PrinterCard card) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: card.online
            ? cs.primary.withValues(alpha: 0.13)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        card.stateLabel,
        style: TextStyle(
          color: card.online ? cs.primary : cs.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _slotList(ColorScheme cs, PrinterCard card) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < card.slots.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.outline.withValues(alpha: 0.4),
                ),
              ),
            _slotRow(cs, card.slots[i]),
          ],
        ],
      ),
    );
  }

  Widget _slotRow(ColorScheme cs, SlotInfo s) {
    final swatch = Color(
      _parseColorHex(_firstNonEmpty([s.spoolRgba, s.colorHex]) ?? '0xFF52525B'),
    );

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('slot-row-${s.spoolId}'),
        onTap: s.hasAssignedSpool ? () => _showFilamentDetails(s) : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cs.outline),
                ),
                child: Text(
                  s.label,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                key: ValueKey('slot-swatch-${s.spoolId}'),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: swatch,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: cs.outline),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _filamentTypeLabel(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '#${s.spoolId}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _amountLeftLabel(s),
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFilamentDetails(SlotInfo slot) async {
    final spoolId = slot.spoolId;
    if (spoolId == null) return;
    final swatch = Color(
      _parseColorHex(
        _firstNonEmpty([slot.spoolRgba, slot.colorHex]) ?? '0xFF52525B',
      ),
    );
    final brand = _firstNonEmpty([slot.spoolBrand, 'Unknown brand'])!;
    final type = _filamentTypeLabel(slot);
    final subtype = _firstNonEmpty([slot.spoolSubtype, slot.spoolColorName]);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        key: ValueKey('filament-detail-swatch-$spoolId'),
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: swatch,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: cs.outline),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Filament details',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _detailLine(cs, 'Filament ID', spoolId.toString()),
                  _detailLine(cs, 'Amount left', _amountLeftLabel(slot)),
                  _detailLine(cs, 'Slot', slot.label),
                  _detailLine(cs, 'Brand', brand),
                  _detailLine(cs, 'Type', type),
                  if (subtype != null) _detailLine(cs, 'Subtype', subtype),
                  if (slot.spoolColorName != null)
                    _detailLine(cs, 'Color', slot.spoolColorName!),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            unawaited(_confirmUnassign(slot));
                          },
                          icon: const Icon(Icons.link_off_outlined, size: 17),
                          label: const Text('Unassign filament'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailLine(ColorScheme cs, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _filamentTypeLabel(SlotInfo slot) =>
      _firstNonEmpty([slot.spoolMaterial, slot.material, 'Unknown type'])!;

  String _amountLeftLabel(SlotInfo slot) {
    if (slot.spoolRemaining != null) {
      return '${slot.spoolRemaining!.round()} g';
    }
    if (slot.remainPercent != null) {
      return '${slot.remainPercent!.round()}%';
    }
    return 'Amount unknown';
  }

  Widget _temperatureBanners(PrinterCard card) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (card.nozzleTemp != null)
          _temperatureChip(
            key: const ValueKey('nozzle-temperature-chip'),
            icon: Icons.local_fire_department_outlined,
            label: 'Nozzle ${card.nozzleTemp!.round()}°C',
            color: const Color(0xFFEA580C),
          ),
        if (card.bedTemp != null)
          _temperatureChip(
            key: const ValueKey('bed-temperature-chip'),
            icon: Icons.layers_outlined,
            label: 'Bed ${card.bedTemp!.round()}°C',
            color: const Color(0xFF2563EB),
          ),
      ],
    );
  }

  Widget _temperatureChip({
    required Key key,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.print_disabled_outlined,
                size: 72,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No printers connected',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 280,
                child: Text(
                  'No printers configured. Add printers in the Bambuddy web UI.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmUnassign(SlotInfo slot) async {
    final spoolId = slot.spoolId;
    if (spoolId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unassign filament?'),
        content: Text('Remove spool #$spoolId from ${slot.label}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _unassignSlot(slot);
    }
  }

  Future<void> _unassignSlot(SlotInfo slot) async {
    final spoolId = slot.spoolId;
    if (spoolId == null) return;
    AppModel? model;
    try {
      model = context.read<AppModel>();
    } catch (_) {
      model = null;
    }
    try {
      _api ??= await (widget.apiClientFactory?.call() ?? ApiClient.create());
      await _api!.delete('/spoolman/inventory/slot-assignments/$spoolId');
      final cards = await _fetchCards(_api!);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _loading = false;
        _banner = 'Unassigned spool #$spoolId from ${slot.label}.';
        _bannerColor = Theme.of(context).colorScheme.primary;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        if (model != null) {
          await model.signOut();
          return;
        }
      }
      setState(() {
        _banner = 'Could not unassign spool #$spoolId: ${e.detailMessage()}';
        _bannerColor = Theme.of(context).colorScheme.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _banner = 'Could not unassign spool #$spoolId: $e';
        _bannerColor = Theme.of(context).colorScheme.error;
      });
    }
  }

  Future<void> _clearPlate(int printerId) async {
    final model = context.read<AppModel>();
    try {
      _api ??= await (widget.apiClientFactory?.call() ?? ApiClient.create());
      await _api!.post('/printers/$printerId/clear-plate');
      if (!mounted) return;
      setState(() {
        _banner = 'Plate marked cleared — next print will start shortly.';
        _bannerColor = Theme.of(context).colorScheme.primary;
      });
      _refresh(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        await model.signOut();
        return;
      }
      final msg = e.isForbidden
          ? 'This account cannot control the printer. Ask an admin to grant '
                'printer control permission.'
          : e.statusCode == 400
          ? 'Printer is not awaiting plate-clear.'
          : 'Could not clear plate: ${e.detailMessage()}';
      setState(() {
        _banner = msg;
        _bannerColor = Theme.of(context).colorScheme.error;
      });
    }
  }
}

class PrinterCard {
  String name = 'Printer';
  int id = -1;
  String? model;
  bool online = false;
  bool connected = false;
  String? rawState;
  String stateLabel = '';
  bool awaitingClear = false;
  bool hasFault = false;
  double progress = -1;
  String? subtaskName;
  double? nozzleTemp;
  double? bedTemp;
  final List<SlotInfo> slots = [];
}

class SlotInfo {
  int amsId = 0;
  int trayId = 0;
  String label = '';
  String? colorHex;
  String? material;
  double? remainPercent;
  int? trayState;
  bool occupied = false;
  int? spoolId;
  String? spoolBrand;
  String? spoolMaterial;
  String? spoolSubtype;
  String? spoolColorName;
  String? spoolRgba;
  double? spoolRemaining;
  int? spoolLabelWeight;

  bool get hasAssignedSpool => spoolId != null;
}

class _SlotAssignment {
  const _SlotAssignment({
    required this.printerId,
    required this.amsId,
    required this.trayId,
    required this.spoolId,
  });

  final int printerId;
  final int amsId;
  final int trayId;
  final int spoolId;
}

/// Subtle "clear plate" action rendered as a frosted yellow glass pill so the
/// warning tone reads without dominating the card. The [BackdropFilter] frosts
/// whatever sits behind it; the translucent yellow gradient + edge give it the
/// glass sheen.
class _GlassClearPlateButton extends StatelessWidget {
  const _GlassClearPlateButton({required this.onPressed});

  final VoidCallback onPressed;

  static const Color _yellow = Color(0xFFFACC15);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _yellow.withValues(alpha: 0.30),
                _yellow.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(color: _yellow.withValues(alpha: 0.45)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              child: const SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: _yellow),
                    SizedBox(width: 8),
                    Text(
                      'Mark plate cleared',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
