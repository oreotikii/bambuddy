import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/app_model.dart';
import '../core/api_exception.dart';
import '../data/api_client.dart';
import '../data/session_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
      _api ??= await ApiClient.create();
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
        await SessionStore.clearCredentials();
        if (mounted) context.read<AppModel>().logoutToSetup();
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
    final printers =
        (await api.getArray('/printers/')).cast<Map<String, dynamic>>();

    final statuses = await Future.wait(printers.map((p) async {
      final id = (p['id'] as num?)?.toInt() ?? -1;
      if (id < 0) return null;
      try {
        return await api.get('/printers/$id/status');
      } catch (_) {
        return null;
      }
    }));

    final slotToSpool = <String, int>{};
    final spoolById = <int, Map<String, dynamic>>{};
    try {
      final slots = (await api.getArray('/spoolman/inventory/slot-assignments/all'))
          .cast<Map<String, dynamic>>();
      for (final s in slots) {
        final key = _slotKey((s['printer_id'] as num?)?.toInt() ?? 0,
            (s['ams_id'] as num?)?.toInt() ?? 0, (s['tray_id'] as num?)?.toInt() ?? 0);
        slotToSpool[key] = (s['spoolman_spool_id'] as num?)?.toInt() ?? 0;
      }
      final spools = (await api.getArray('/spoolman/inventory/spools'))
          .cast<Map<String, dynamic>>();
      for (final sp in spools) {
        final id = (sp['id'] as num?)?.toInt() ?? 0;
        if (id != 0) spoolById[id] = sp;
      }
    } on ApiException {
      // Spoolman disabled/unavailable — render without inventory links.
    }

    final cards = <PrinterCard>[];
    for (var i = 0; i < printers.length; i++) {
      cards.add(_buildCard(printers[i], statuses[i], slotToSpool, spoolById));
    }
    return cards;
  }

  PrinterCard _buildCard(
    Map<String, dynamic> printer,
    Map<String, dynamic>? status,
    Map<String, int> slotToSpool,
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
          card.slots.add(_buildSlot(printerId, amsId,
              (tray['id'] as num?)?.toInt() ?? t, isAmsHt, tray, slotToSpool, spoolById));
        }
      }
    }
    final vt = status['vt_tray'] as List<dynamic>?;
    if (vt != null) {
      for (final raw in vt) {
        if (raw is! Map<String, dynamic>) continue;
        card.slots.add(_buildSlot(printerId, 255,
            (raw['id'] as num?)?.toInt() ?? 0, false, raw, slotToSpool, spoolById));
      }
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
          ? 'External'
          : '${isAmsHt ? 'AMS-HT' : 'AMS${amsId + 1}'} · T${trayId + 1}'
      ..colorHex = tray['tray_color'] as String?
      ..material = _firstNonEmpty(
          [tray['tray_sub_brands'] as String?, tray['tray_type'] as String?])
      ..remainPercent = _toDouble(tray['remain'])
      ..trayState = _toInt(tray['state'])
      ..occupied = _toInt(tray['state']) != null
          ? _toInt(tray['state']) != 9
          : (tray['tray_sub_brands'] != null || tray['tray_type'] != null);

    final spoolId = slotToSpool[_slotKey(printerId, amsId, trayId)];
    if (spoolId != null) {
      final spool = spoolById[spoolId];
      if (spool != null) {
        slot
          ..spoolId = spoolId
          ..spoolBrand = spool['brand'] as String?
          ..spoolMaterial = spool['material'] as String?
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
        return 'Finishing';
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

  static bool _isAwaitingClear(String? raw) {
    if (raw == null) return false;
    final s = raw.toUpperCase();
    return s == 'FINISH' || s == 'FAILED';
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
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: cs.primary, borderRadius: BorderRadius.circular(6)),
            child: Text('B',
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text('Bambuddy',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () => context.read<AppModel>().lockNow(),
              style: TextButton.styleFrom(
                foregroundColor: cs.onSurface,
                backgroundColor: cs.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
                minimumSize: const Size(0, 32),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: const Text('Lock', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_banner != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _bannerColor?.withValues(alpha: 0.12),
              child: Text(_banner!,
                  style: TextStyle(color: _bannerColor ?? cs.error, fontSize: 13)),
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
                                      top: 6, bottom: 10),
                                  child: Row(children: [
                                    Text('Workshop printers',
                                        style: TextStyle(
                                            color: cs.onSurface,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const Spacer(),
                                    Text('pull to refresh',
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 11,
                                            fontFamily: 'monospace')),
                                  ]),
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
    int printing = 0, idle = 0, plate = 0;
    for (final c in _cards) {
      if (_isAwaitingClear(c.rawState)) {
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
          _metric('$printing printing', cs.primary),
          _metric('$idle idle', cs.onSurfaceVariant),
          _metric('$plate plate', cs.tertiary),
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
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildCardWidget(ColorScheme cs, PrinterCard card) {
    final isA1 = (card.model ?? '').toUpperCase().contains('A1');
    return Card(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outline)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
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
                    color: cs.onSurfaceVariant),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(
                      _firstNonEmpty([
                              card.model,
                              card.subtaskName,
                              card.online
                                  ? 'Ready for spool assignment'
                                  : 'No connection'
                            ]) ??
                          '',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                    if (_tempLine(card).isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(_tempLine(card),
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: card.online
                      ? cs.primary.withValues(alpha: 0.13)
                      : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(card.stateLabel,
                    style: TextStyle(
                        color: card.online ? cs.primary : cs.onSurfaceVariant,
                        fontSize: 12)),
              ),
            ]),
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
            if (card.online && card.id > 0 && _isAwaitingClear(card.rawState)) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => _clearPlate(card.id),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Mark plate cleared'),
              ),
            ],
            if (card.slots.isNotEmpty) ...[
              const SizedBox(height: 12),
              _slotList(cs, card),
            ] else if (card.online) ...[
              const SizedBox(height: 8),
              Text('No AMS loaded',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _slotList(ColorScheme cs, PrinterCard card) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              (card.model ?? '').toUpperCase().contains('A1')
                  ? 'AMS Lite slots'
                  : 'AMS slots',
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...card.slots.where((s) => s.amsId != 255).map((s) => _slotRow(cs, s)),
        ],
      ),
    );
  }

  Widget _slotRow(ColorScheme cs, SlotInfo s) {
    final swatch = Color(_parseColorHex(
        _firstNonEmpty([s.spoolRgba, s.colorHex]) ?? '0xFF52525B'));
    final label = !s.occupied
        ? 'Empty'
        : _firstNonEmpty([s.spoolMaterial, s.material, s.spoolBrand, 'Loaded'])!;
    String? sub;
    if (s.occupied) {
      final parts = <String>[];
      if (s.remainPercent != null) parts.add('${s.remainPercent!.round()}%');
      if (s.spoolRemaining != null) parts.add('~${s.spoolRemaining!.round()} g');
      sub = parts.join('  ·  ');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: swatch,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: cs.outline, width: 1),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: s.occupied ? cs.onSurface : cs.onSurfaceVariant)),
              if (sub != null)
                Text(sub,
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return ListView(children: [
      const SizedBox(height: 80),
      Center(
        child: Column(children: [
          Icon(Icons.print_disabled_outlined,
              size: 72, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No printers connected',
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SizedBox(
            width: 280,
            child: Text(
              'No printers configured. Add printers in the Bambuddy web UI.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
            ),
          ),
        ]),
      ),
    ]);
  }

  String _tempLine(PrinterCard card) {
    final parts = <String>[];
    if (card.nozzleTemp != null) parts.add('${card.nozzleTemp!.round()}°C');
    if (card.bedTemp != null) {
      parts.add('${parts.isNotEmpty ? '/ ' : ''}${card.bedTemp!.round()}°C');
    }
    return parts.join(' ');
  }

  Future<void> _clearPlate(int printerId) async {
    final model = context.read<AppModel>();
    try {
      _api ??= await ApiClient.create();
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
        await SessionStore.clearCredentials();
        model.logoutToSetup();
        return;
      }
      final msg = e.statusCode == 400
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
  String? spoolColorName;
  String? spoolRgba;
  double? spoolRemaining;
  int? spoolLabelWeight;
}

