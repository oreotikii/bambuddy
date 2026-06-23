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
  const HomeScreen({super.key, this.apiClientFactory, this.refreshNonce = 0});

  final Future<ApiClient> Function()? apiClientFactory;
  final int refreshNonce;

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

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshNonce != oldWidget.refreshNonce) {
      unawaited(_refresh(false));
    }
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

  static Color _stateAccentColor(PrinterCard card) {
    if (card.hasFault) return const Color(0xFF7F1D1D);
    if (card.awaitingClear) return const Color(0xFF78350F);
    if (card.stateLabel == 'Printing') return const Color(0xFF166534);
    if (card.online) return const Color(0xFF3F3F46);
    return const Color(0xFF252529);
  }

  static Color _stateDotColor(PrinterCard card) {
    if (card.hasFault) return const Color(0xFFF87171);
    if (card.awaitingClear) return const Color(0xFFFBBF24);
    if (card.stateLabel == 'Printing') return const Color(0xFF4ADE80);
    if (card.online) return const Color(0xFF71717A);
    return const Color(0xFF3F3F46);
  }

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
    final isSuccessBanner =
        _bannerColor == Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        toolbarHeight: 64,
        titleSpacing: 16,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Crav3dLogo(width: 200, color: Colors.white),
            const SizedBox(height: 3),
            Text(
              'BAMBUDDY',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 10,
                fontWeight: FontWeight.w200,
                letterSpacing: 5,
                height: 1,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF27272A)),
        ),
      ),
      body: Column(
        children: [
          if (_banner != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSuccessBanner
                    ? const Color(0xFF0D2818)
                    : const Color(0xFF2C1414),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSuccessBanner
                      ? const Color(0xFF166534)
                      : const Color(0xFF7F1D1D),
                ),
              ),
              child: Text(
                _banner!,
                style: TextStyle(
                  color: isSuccessBanner
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                  fontSize: 13,
                ),
              ),
            ),
          if (_cards.isNotEmpty) _metricsRow(cs),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    color: const Color(0xFF00C853),
                    onRefresh: () => _refresh(true),
                    child: _cards.isEmpty
                        ? _emptyState(cs)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
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
                                      const Text(
                                        'WORKSHOP PRINTERS',
                                        style: TextStyle(
                                          color: Color(0xFF71717A),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Text(
                                        'pull to refresh',
                                        style: TextStyle(
                                          color: Color(0xFF3F3F46),
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1E),
        border: Border(bottom: BorderSide(color: Color(0xFF27272A))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (fault > 0) _metric('$fault fault', _MetricStyle.fault),
          if (plate > 0) _metric('$plate plate', _MetricStyle.warn),
          _metric('$printing printing', _MetricStyle.printing),
          _metric('$idle idle', _MetricStyle.idle),
        ],
      ),
    );
  }

  Widget _metric(String label, _MetricStyle style) {
    final Color bg;
    final Color textColor;
    switch (style) {
      case _MetricStyle.fault:
        bg = const Color(0xFF1A0A0A);
        textColor = const Color(0xFFD87171);
        break;
      case _MetricStyle.warn:
        bg = const Color(0xFF130F00);
        textColor = const Color(0xFFCB9C1A);
        break;
      case _MetricStyle.printing:
        bg = const Color(0xFF0A160D);
        textColor = const Color(0xFF4ADE80);
        break;
      case _MetricStyle.idle:
        bg = Colors.transparent;
        textColor = const Color(0xFF52525B);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
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
    final amsSlots = card.slots.where((s) => s.amsId != 255).toList();
    final externalSlots = card.slots.where((s) => s.amsId == 255).toList();
    final showAmsDiagram = isA1 && amsSlots.isNotEmpty;
    final listSlots = showAmsDiagram ? externalSlots : card.slots;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 3, color: _stateAccentColor(card)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
            child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252528),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF2E2E34)),
                          ),
                          child: Icon(
                            isA1
                                ? Icons.view_in_ar_outlined
                                : Icons.print_outlined,
                            size: 24,
                            color: _stateDotColor(card).withValues(
                              alpha:
                                  card.online || card.hasFault ? 0.85 : 0.35,
                            ),
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
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    height: 1.2,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (modelName != null)
                                    Flexible(
                                      child: _modelChip(
                                        cs,
                                        card.id,
                                        modelName,
                                      ),
                                    )
                                  else
                                    Flexible(
                                      child: Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF52525B),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  _statusChip(cs, card),
                                ],
                              ),
                              if (card.nozzleTemp != null ||
                                  card.bedTemp != null) ...[
                                const SizedBox(height: 6),
                                _temperatureRow(card),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (card.stateLabel == 'Printing' &&
                        card.progress >= 0) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: (card.progress / 100).clamp(0.02, 1.0),
                                minHeight: 4,
                                backgroundColor: const Color(0xFF252529),
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF22C55E),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${card.progress.round()}%',
                            style: const TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (card.online && card.id > 0 && card.awaitingClear) ...[
                      const SizedBox(height: 10),
                      _GlassClearPlateButton(
                        onPressed: () => _clearPlate(card.id),
                      ),
                    ],
                    if (showAmsDiagram) ...[
                      const SizedBox(height: 14),
                      _HomeAmsDiagram(
                        slots: amsSlots,
                        onSlotTap: _showFilamentDetails,
                      ),
                    ],
                    if (listSlots.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
                        child: Text(
                          showAmsDiagram
                              ? 'EXTERNAL SPOOLS'
                              : 'LOADED FILAMENTS',
                          style: const TextStyle(
                            color: Color(0xFF3F3F46),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      _slotList(cs, listSlots),
                    ],
                  ],
                ),
              ),
          ],
        ),
    );
  }

  Widget _modelChip(ColorScheme cs, int printerId, String modelName) {
    return Container(
      key: ValueKey('model-chip-$printerId'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF252529),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        modelName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF52525B),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _statusChip(ColorScheme cs, PrinterCard card) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: _stateDotColor(card),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          card.stateLabel,
          style: const TextStyle(
            color: Color(0xFF71717A),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _slotList(ColorScheme cs, List<SlotInfo> slots) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2E2E34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < slots.length; i++) ...[
            if (i > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFF27272A),
                ),
              ),
            _slotRow(cs, slots[i]),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF3F3F46)),
                ),
                child: Text(
                  s.label,
                  style: const TextStyle(
                    color: Color(0xFF71717A),
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
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
                  border: Border.all(color: const Color(0xFF2E2E34)),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '#${s.spoolId}',
                      style: const TextStyle(
                        color: Color(0xFF52525B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _amountLeftLabel(s),
                style: const TextStyle(
                  color: Color(0xFF71717A),
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

  Widget _temperatureRow(PrinterCard card) {
    final parts = <String>[];
    if (card.nozzleTemp != null) parts.add('N ${card.nozzleTemp!.round()}°C');
    if (card.bedTemp != null) parts.add('B ${card.bedTemp!.round()}°C');
    return Text(
      parts.join('  ·  '),
      style: const TextStyle(
        color: Color(0xFF52525B),
        fontSize: 11,
        fontFamily: 'monospace',
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
              const Icon(
                Icons.print_disabled_outlined,
                size: 72,
                color: Color(0xFF52525B),
              ),
              const SizedBox(height: 16),
              const Text(
                'No printers connected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 280,
                child: const Text(
                  'No printers configured. Add printers in the Bambuddy web UI.',
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

enum _MetricStyle { fault, warn, printing, idle }

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

// Mount positions match assign_screen.dart — trayId maps directly to index.
const _kHomeMounts = [
  (0.79, 0.20), // trayId 0 – T1 upper right
  (0.20, 0.20), // trayId 1 – T2 upper left
  (0.20, 0.80), // trayId 2 – T3 lower left
  (0.79, 0.80), // trayId 3 – T4 lower right
];

class _HomeAmsDiagram extends StatelessWidget {
  const _HomeAmsDiagram({required this.slots, this.onSlotTap});
  final List<SlotInfo> slots;
  final ValueChanged<SlotInfo>? onSlotTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const imageAspect = 979.5 / 452.97;
        final w = constraints.maxWidth;
        final h = w / imageAspect;
        return GestureDetector(
          onTapUp: onSlotTap == null
              ? null
              : (details) {
                  final pos = details.localPosition;
                  SlotInfo? nearest;
                  double? bestSq;
                  for (var trayId = 0; trayId < _kHomeMounts.length; trayId++) {
                    SlotInfo? slot;
                    for (final s in slots) {
                      if (s.trayId == trayId) {
                        slot = s;
                        break;
                      }
                    }
                    if (slot == null) continue;
                    final cx = _kHomeMounts[trayId].$1 * w;
                    final cy = _kHomeMounts[trayId].$2 * h;
                    final dx = pos.dx - cx;
                    final dy = pos.dy - cy;
                    final d = dx * dx + dy * dy;
                    if (bestSq == null || d < bestSq) {
                      bestSq = d;
                      nearest = slot;
                    }
                  }
                  if (nearest != null) onSlotTap!(nearest);
                },
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/ui/ams_body.png',
                    fit: BoxFit.fill,
                    color: const Color.fromARGB(255, 209, 209, 209),
                    colorBlendMode: BlendMode.modulate,
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HomeAmsSpoolsPainter(slots: slots),
                  ),
                ),
                Positioned(
                  top: 0,
                  height: h,
                  left: (w - h * 375.0 / 526.0) / 2,
                  width: h * 375.0 / 526.0,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/ui/ams_frame.png',
                      fit: BoxFit.fill,
                      color: const Color.fromARGB(255, 144, 144, 144),
                      colorBlendMode: BlendMode.modulate,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeAmsSpoolsPainter extends CustomPainter {
  const _HomeAmsSpoolsPainter({required this.slots});
  final List<SlotInfo> slots;

  static const _sw = 390.0 / 979.5;
  static const _sh = 170.0 / 452.97;
  static const _fh = 11.49 / 170.0;
  static const _flangeColor = Color(0xFF181818);

  @override
  void paint(Canvas canvas, Size size) {
    final spoolW = size.width * _sw;
    final spoolH = size.height * _sh;
    final flangeH = spoolH * _fh;

    for (var trayId = 0; trayId < 4; trayId++) {
      SlotInfo? slot;
      for (final s in slots) {
        if (s.trayId == trayId) {
          slot = s;
          break;
        }
      }
      if (slot == null) continue;

      final mount = _kHomeMounts[trayId];
      final cx = mount.$1 * size.width;
      final cy = mount.$2 * size.height;
      final left = cx - spoolW / 2;
      final top = cy - spoolH / 2;
      final bodyTop = top + flangeH;
      final bodyH = spoolH - flangeH * 2;

      // Hub background — visible as the dark centre when spool is not full.
      canvas.drawRect(
        Rect.fromLTWH(left, bodyTop, spoolW, bodyH),
        Paint()..color = const Color(0xFF1C1C1C),
      );

      // Filament fill width scales with remaining amount (centred on spool).
      final frac = _remainFraction(slot);
      final fillW = (spoolW * frac).clamp(0.0, spoolW);
      if (fillW > 0) {
        final fillLeft = cx - fillW / 2;
        final color = _slotColor(slot);
        canvas.drawRect(
          Rect.fromLTWH(fillLeft, bodyTop, fillW, bodyH),
          Paint()..color = color,
        );

        final gp = Paint()
          ..color = Colors.black.withValues(alpha: 0.13)
          ..strokeWidth = 0.6
          ..style = PaintingStyle.stroke;
        for (var j = 1; j < 5; j++) {
          final y = bodyTop + bodyH * j / 5;
          canvas.drawLine(Offset(fillLeft, y), Offset(fillLeft + fillW, y), gp);
        }

        canvas.drawRect(
          Rect.fromLTWH(fillLeft, bodyTop, fillW, bodyH * 0.25),
          Paint()..color = Colors.white.withValues(alpha: 0.07),
        );
      }

      canvas.drawRect(
        Rect.fromLTWH(left, top, spoolW, flangeH),
        Paint()..color = _flangeColor,
      );
      canvas.drawRect(
        Rect.fromLTWH(left, top + spoolH - flangeH, spoolW, flangeH),
        Paint()..color = _flangeColor,
      );

      // Spool ID + material label inside spool body.
      final spoolNum = slot.spoolId;
      TextPainter? numPainter;
      if (spoolNum != null) {
        numPainter = TextPainter(
          text: TextSpan(
            text: '#$spoolNum',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
      }

      final mat = slot.spoolMaterial ?? slot.material;
      TextPainter? matPainter;
      if (mat != null && mat.isNotEmpty) {
        matPainter = TextPainter(
          text: TextSpan(
            text: mat.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 6,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: spoolW * 0.85);
      }

      if (numPainter != null || matPainter != null) {
        final numH = numPainter?.height ?? 0;
        final totalH = numH + (matPainter != null ? 2 + matPainter.height : 0);
        final textY = bodyTop + (bodyH - totalH) / 2;
        numPainter?.paint(canvas, Offset(cx - numPainter.width / 2, textY));
        if (matPainter != null) {
          matPainter.paint(
            canvas,
            Offset(cx - matPainter.width / 2, textY + numH + 2),
          );
        }
      }
    }
  }

  double _remainFraction(SlotInfo slot) {
    final remaining = slot.spoolRemaining;
    final total = slot.spoolLabelWeight;
    if (remaining != null && total != null && total > 0) {
      return (remaining / total).clamp(0.0, 1.0);
    }
    final pct = slot.remainPercent;
    if (pct != null) return (pct / 100.0).clamp(0.0, 1.0);
    return 1.0; // Unknown → assume full.
  }

  Color _slotColor(SlotInfo slot) {
    final raw = (slot.spoolRgba ?? slot.colorHex)?.trim().replaceAll('#', '');
    if (raw != null && raw.length >= 6) {
      final v = int.tryParse(raw.substring(0, 6), radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return const Color(0xFF6B6B6B);
  }

  @override
  bool shouldRepaint(covariant _HomeAmsSpoolsPainter old) => old.slots != slots;
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
