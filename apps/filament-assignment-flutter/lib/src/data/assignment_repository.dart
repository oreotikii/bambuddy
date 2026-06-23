import '../core/api_exception.dart';
import 'api_client.dart';

abstract class AssignmentRepository {
  Future<MobilePrinter> resolvePrinter(String code);
  Future<List<MobilePrinter>> fetchPrinters();
  Future<MobileSpool> resolveSpool(String code);
  Future<List<MobileSlot>> fetchPrinterSlots(int printerId);
  Future<MobileAssignResult> assignSpool({
    required int printerId,
    required int spoolId,
    required int amsId,
    required int slot,
    bool replaceExisting = false,
    bool moveExisting = false,
  });
  /// Distinct non-empty `storage_location` values across all spools, used to
  /// populate the weigh-screen location dropdown. Derived from the spool list.
  Future<List<String>> fetchSpoolLocations();

  /// Full detail for one spool (the inventory spool endpoint). Carries the
  /// fields the mobile resolve-spool summary omits: the empty spool weight
  /// (`core_weight`), multi-color/effect metadata, and `subtype`.
  Future<MobileSpoolDetail> fetchSpoolDetail(int spoolId);

  /// Record a weigh on the dedicated weigh endpoint: the scale reading
  /// (`measured_weight`, filament + spool), the empty spool weight
  /// (`empty_spool_weight`), and/or the storage `location`. Only the provided
  /// fields are sent.
  Future<void> updateSpoolWeigh(
    int spoolId, {
    double? measuredWeight,
    double? emptySpoolWeight,
    String? location,
  });

  Future<void> resetSlot(int printerId, int amsId, int trayId);

  Future<void> unassignSpool(int spoolmanSpoolId);
}

class AssignmentApi implements AssignmentRepository {
  AssignmentApi(this._api);

  final ApiClient _api;

  @override
  Future<MobilePrinter> resolvePrinter(String code) async {
    final response = await _api.get(
      ApiClient.withQuery('/mobile-assignment/resolve-printer', 'code', code),
    );
    return MobilePrinter.fromJson(_object(response['printer']));
  }

  @override
  Future<List<MobilePrinter>> fetchPrinters() async {
    final response = await _api.getArray('/printers/');
    final printers = response
        .map((raw) => MobilePrinter.fromJson(_object(raw)))
        .toList(growable: false);
    printers.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return printers;
  }

  @override
  Future<MobileSpool> resolveSpool(String code) async {
    final response = await _api.get(
      ApiClient.withQuery('/mobile-assignment/resolve-spool', 'code', code),
    );
    return MobileSpool.fromJson(_object(response['spool']));
  }

  @override
  Future<List<MobileSlot>> fetchPrinterSlots(int printerId) async {
    final response = await _api.get(
      ApiClient.withQuery(
        '/mobile-assignment/printer-slots',
        'printer_id',
        printerId.toString(),
      ),
    );
    return _list(
      response['slots'],
    ).map((slot) => MobileSlot.fromJson(_object(slot))).toList(growable: false);
  }

  @override
  Future<MobileAssignResult> assignSpool({
    required int printerId,
    required int spoolId,
    required int amsId,
    required int slot,
    bool replaceExisting = false,
    bool moveExisting = false,
  }) async {
    try {
      final response = await _api.post('/mobile-assignment/assign', {
        'printer_id': printerId,
        'spool_id': spoolId,
        'ams_id': amsId,
        'slot': slot,
        'replace_existing': replaceExisting,
        'move_existing': moveExisting,
      });
      return MobileAssignResult.fromJson(response);
    } on ApiException catch (e) {
      final detail = e.detailObject();
      final confirmField = detail?['confirm_field'];
      final canConfirm = detail?['can_confirm'] == true;
      if (e.statusCode == 409 && canConfirm && confirmField is String) {
        final code = detail?['code'];
        final message = detail?['message'];
        throw AssignmentConflictException(
          code: code is String ? code : 'ASSIGNMENT_CONFLICT',
          message: message is String ? message : e.detailMessage(),
          confirmField: confirmField,
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<String>> fetchSpoolLocations() async {
    final spools = await _api.getArray('/spoolman/inventory/spools');
    final locations = <String>{};
    for (final raw in spools) {
      if (raw is Map) {
        final loc = raw['storage_location'];
        if (loc is String && loc.trim().isNotEmpty) locations.add(loc.trim());
      }
    }
    return locations.toList()..sort();
  }

  @override
  Future<MobileSpoolDetail> fetchSpoolDetail(int spoolId) async {
    final response = await _api.get('/spoolman/inventory/spools/$spoolId');
    return MobileSpoolDetail.fromJson(_object(response));
  }

  @override
  Future<void> updateSpoolWeigh(
    int spoolId, {
    double? measuredWeight,
    double? emptySpoolWeight,
    String? location,
  }) async {
    final body = <String, dynamic>{};
    if (measuredWeight != null) body['measured_weight'] = measuredWeight;
    if (emptySpoolWeight != null) body['empty_spool_weight'] = emptySpoolWeight;
    if (location != null) body['location'] = location;
    if (body.isEmpty) return;
    await _api.patch('/spoolman/inventory/spools/$spoolId/weigh', body);
  }

  @override
  Future<void> resetSlot(int printerId, int amsId, int trayId) async {
    await _api.post('/printers/$printerId/ams/$amsId/tray/$trayId/reset');
  }

  @override
  Future<void> unassignSpool(int spoolmanSpoolId) async {
    await _api.delete('/spoolman/inventory/slot-assignments/$spoolmanSpoolId');
  }
}

class AssignmentConflictException implements Exception {
  const AssignmentConflictException({
    required this.code,
    required this.message,
    required this.confirmField,
  });

  final String code;
  final String message;
  final String confirmField;

  bool get confirmsReplaceExisting => confirmField == 'replace_existing';
  bool get confirmsMoveExisting => confirmField == 'move_existing';

  @override
  String toString() => 'AssignmentConflictException($code): $message';
}

class MobilePrinter {
  const MobilePrinter({
    required this.id,
    required this.name,
    this.serialNumber,
    this.model,
    this.location,
    this.connected,
    this.status,
  });

  factory MobilePrinter.fromJson(Map<String, dynamic> json) {
    return MobilePrinter(
      id: _int(json['id']) ?? -1,
      name: _string(json['name']) ?? 'Printer',
      serialNumber: _string(json['serial_number']),
      model: _string(json['model']),
      location: _string(json['location']),
      connected: _bool(json['connected']),
      status: _string(json['status']),
    );
  }

  final int id;
  final String name;
  final String? serialNumber;
  final String? model;
  final String? location;
  final bool? connected;
  final String? status;
}

class MobileSpool {
  const MobileSpool({
    required this.id,
    this.inventoryMode,
    this.externalSpoolmanId,
    this.material,
    this.brand,
    this.vendor,
    this.colorName,
    this.rgba,
    this.remainingGrams,
    this.labelWeight,
    this.weightUsed,
    this.currentLocation,
    this.storageLocation,
    this.currentAssignment,
  });

  factory MobileSpool.fromJson(Map<String, dynamic> json) {
    final currentAssignment = json['current_assignment'];
    return MobileSpool(
      id: _int(json['id']) ?? -1,
      inventoryMode: _string(json['inventory_mode']),
      externalSpoolmanId: _int(json['external_spoolman_id']),
      material: _string(json['material']),
      brand: _string(json['brand']),
      vendor: _string(json['vendor']),
      colorName: _string(json['color_name']),
      rgba: _string(json['rgba']),
      remainingGrams: _double(json['remaining_grams']),
      labelWeight: _double(json['label_weight']),
      weightUsed: _double(json['weight_used']),
      currentLocation: _string(json['current_location']),
      storageLocation: _string(json['storage_location']),
      currentAssignment: currentAssignment == null
          ? null
          : MobileCurrentAssignment.fromJson(_object(currentAssignment)),
    );
  }

  final int id;
  final String? inventoryMode;
  final int? externalSpoolmanId;
  final String? material;
  final String? brand;
  final String? vendor;
  final String? colorName;
  final String? rgba;
  final double? remainingGrams;
  final double? labelWeight;
  final double? weightUsed;
  final String? currentLocation;
  final String? storageLocation;
  final MobileCurrentAssignment? currentAssignment;

  String get displayName {
    final parts = <String>[
      if (_present(brand)) brand!,
      if (!_same(brand, vendor) && _present(vendor)) vendor!,
      if (_present(material)) material!,
      if (_present(colorName)) colorName!,
    ];
    return parts.isEmpty ? 'Spool #$id' : parts.join(' ');
  }
}

/// Full inventory detail for one spool (`GET /spoolman/inventory/spools/{id}`).
/// Carries the fields the mobile resolve-spool summary omits, used by the weigh
/// screen to pre-fill the empty spool weight and render color/effect swatches.
class MobileSpoolDetail {
  const MobileSpoolDetail({
    this.coreWeight,
    this.subtype,
    this.extraColors,
    this.effectType,
    this.storageLocation,
    this.archivedAt,
  });

  factory MobileSpoolDetail.fromJson(Map<String, dynamic> json) {
    return MobileSpoolDetail(
      coreWeight: _double(json['core_weight']),
      subtype: _string(json['subtype']),
      extraColors: _string(json['extra_colors']),
      effectType: _string(json['effect_type']),
      storageLocation: _string(json['storage_location']),
      archivedAt: _string(json['archived_at']),
    );
  }

  /// Empty spool weight (the reel/core, without filament), in grams.
  final double? coreWeight;

  /// Filament variant/line (e.g. a color or SKU sub-name).
  final String? subtype;

  /// Additional colors as a single server-provided string. Format is not
  /// fixed by the schema; split on common delimiters into hex tokens.
  final String? extraColors;

  /// Surface effect (e.g. "Silk", "Matte", "Glow").
  final String? effectType;

  final String? storageLocation;

  /// ISO timestamp when the spool was soft-deleted; non-null means archived.
  final String? archivedAt;

  bool get archived => archivedAt != null;

  /// `extraColors` parsed into individual hex tokens (empty when absent).
  List<String> get extraColorHexes {
    final raw = extraColors;
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[,;\s|]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
  }
}

class MobileCurrentAssignment {
  const MobileCurrentAssignment({
    required this.printerId,
    this.printerName,
    required this.amsId,
    required this.slot,
    required this.spoolId,
  });

  factory MobileCurrentAssignment.fromJson(Map<String, dynamic> json) {
    return MobileCurrentAssignment(
      printerId: _int(json['printer_id']) ?? -1,
      printerName: _string(json['printer_name']),
      amsId: _int(json['ams_id']) ?? 0,
      slot: _int(json['slot']) ?? 0,
      spoolId: _int(json['spool_id']) ?? -1,
    );
  }

  final int printerId;
  final String? printerName;
  final int amsId;
  final int slot;
  final int spoolId;
}

class MobileSlot {
  const MobileSlot({
    required this.printerId,
    required this.amsId,
    required this.slot,
    this.trayId,
    required this.label,
    this.unitName,
    this.isExternal = false,
    this.isAmsHt = false,
    this.occupied = false,
    this.physicalOccupied = false,
    this.assignedSpoolId,
    this.assignedSource,
    this.currentMaterial,
    this.currentColor,
    this.currentColorName,
    this.state,
  });

  factory MobileSlot.fromJson(Map<String, dynamic> json) {
    return MobileSlot(
      printerId: _int(json['printer_id']) ?? -1,
      amsId: _int(json['ams_id']) ?? 0,
      slot: _int(json['slot']) ?? _int(json['tray_id']) ?? 0,
      trayId: _int(json['tray_id']),
      label: _string(json['label']) ?? 'Slot',
      unitName: _string(json['unit_name']),
      isExternal: _bool(json['is_external']) ?? false,
      isAmsHt: _bool(json['is_ams_ht']) ?? false,
      occupied: _bool(json['occupied']) ?? false,
      physicalOccupied: _bool(json['physical_occupied']) ?? false,
      assignedSpoolId: _int(json['assigned_spool_id']),
      assignedSource: _string(json['assigned_source']),
      currentMaterial: _string(json['current_material']),
      currentColor: _string(json['current_color']),
      currentColorName: _string(json['current_color_name']),
      state: _int(json['state']),
    );
  }

  final int printerId;
  final int amsId;
  final int slot;
  final int? trayId;
  final String label;
  final String? unitName;
  final bool isExternal;
  final bool isAmsHt;
  final bool occupied;
  final bool physicalOccupied;
  final int? assignedSpoolId;
  final String? assignedSource;
  final String? currentMaterial;
  final String? currentColor;
  final String? currentColorName;
  final int? state;

  String get description {
    final details = <String>[
      if (_present(unitName)) unitName!,
      if (assignedSpoolId != null) 'spool #$assignedSpoolId',
      if (physicalOccupied) 'physically loaded',
      if (_present(currentMaterial)) currentMaterial!,
      if (_present(currentColorName)) currentColorName!,
    ];
    return details.join(' | ');
  }
}

class MobileAssignment {
  const MobileAssignment({
    required this.printerId,
    this.printerName,
    required this.amsId,
    required this.slot,
    this.trayId,
    required this.slotLabel,
    required this.spoolId,
    this.inventoryMode,
    this.location,
    this.material,
    this.color,
    this.configured,
    this.pendingConfig,
  });

  factory MobileAssignment.fromJson(Map<String, dynamic> json) {
    return MobileAssignment(
      printerId: _int(json['printer_id']) ?? -1,
      printerName: _string(json['printer_name']),
      amsId: _int(json['ams_id']) ?? 0,
      slot: _int(json['slot']) ?? _int(json['tray_id']) ?? 0,
      trayId: _int(json['tray_id']),
      slotLabel: _string(json['slot_label']) ?? 'Slot',
      spoolId: _int(json['spool_id']) ?? -1,
      inventoryMode: _string(json['inventory_mode']),
      location: _string(json['location']),
      material: _string(json['material']),
      color: _string(json['color']),
      configured: _bool(json['configured']),
      pendingConfig: _bool(json['pending_config']),
    );
  }

  final int printerId;
  final String? printerName;
  final int amsId;
  final int slot;
  final int? trayId;
  final String slotLabel;
  final int spoolId;
  final String? inventoryMode;
  final String? location;
  final String? material;
  final String? color;
  final bool? configured;
  final bool? pendingConfig;
}

class MobileAssignResult {
  const MobileAssignResult({
    required this.assignment,
    this.warnings = const [],
  });

  factory MobileAssignResult.fromJson(Map<String, dynamic> json) {
    return MobileAssignResult(
      assignment: MobileAssignment.fromJson(_object(json['assignment'])),
      warnings: _list(
        json['warnings'],
      ).whereType<String>().toList(growable: false),
    );
  }

  final MobileAssignment assignment;
  final List<String> warnings;
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool? _bool(Object? value) => value is bool ? value : null;

bool _present(String? value) => value != null && value.trim().isNotEmpty;

bool _same(String? left, String? right) {
  if (!_present(left) || !_present(right)) return false;
  return left!.toLowerCase() == right!.toLowerCase();
}
