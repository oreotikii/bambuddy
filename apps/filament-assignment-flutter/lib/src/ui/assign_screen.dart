import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../data/api_client.dart';
import '../data/assignment_repository.dart';
import 'scanner_sheet.dart';

class AssignScreen extends StatefulWidget {
  const AssignScreen({
    super.key,
    this.repository,
    this.scannerLauncher,
    this.refreshNonce = 0,
  });

  final AssignmentRepository? repository;
  final CodeScannerLauncher? scannerLauncher;
  final int refreshNonce;

  @override
  State<AssignScreen> createState() => AssignScreenState();
}

class AssignScreenState extends State<AssignScreen> {
  final _spoolController = TextEditingController();
  final _scrollController = ScrollController();
  AssignmentRepository? _repository;
  List<MobilePrinter> _printers = const [];
  bool _printersLoading = false;
  String? _printersError;
  MobilePrinter? _printer;
  List<MobileSlot> _slots = const [];
  MobileSlot? _selectedSlot;
  MobileSpool? _spool;
  MobileSpoolDetail? _detail;
  bool _busy = false;
  String? _error;
  String? _success;
  List<String> _warnings = const [];

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  @override
  void didUpdateWidget(covariant AssignScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshNonce != oldWidget.refreshNonce) {
      unawaited(_refreshForPageSwitch());
    }
  }

  @override
  void dispose() {
    _spoolController.dispose();
    _scrollController.dispose();
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

  Future<void> scanQr() {
    return _printer == null ? _scanPrinter() : _scanSpool();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _printersLoading = true;
      _printersError = null;
    });
    try {
      final printers = await (await _repo()).fetchPrinters();
      if (!mounted) return;
      final selected = _printer;
      setState(() {
        _printers = printers;
        _printersLoading = false;
        if (selected != null && !printers.any((p) => p.id == selected.id)) {
          _printers = [...printers, selected];
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _printersError = e.detailMessage();
        _printersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _printersError = e.toString();
        _printersLoading = false;
      });
    }
  }

  Future<void> _scanPrinter() async {
    if (_busy) return;
    final launcher = widget.scannerLauncher ?? showCodeScanner;
    final code = await launcher(context, 'Scan printer');
    if (code == null || code.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
      _warnings = const [];
    });
    MobilePrinter? printer;
    try {
      printer = await (await _repo()).resolvePrinter(code.trim());
    } on ApiException catch (e) {
      _setError(e.detailMessage());
      if (mounted) setState(() => _busy = false);
      return;
    } catch (e) {
      _setError(e.toString());
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    _ensurePrinterInList(printer);
    setState(() {
      _printer = printer;
      _slots = const [];
      _selectedSlot = null;
    });
    await _loadSlots(printer);
  }

  Future<void> _onPrinterSelected(MobilePrinter? printer) async {
    if (printer == null || _busy) return;
    if (_printer?.id == printer.id) return;
    setState(() {
      _printer = printer;
      _slots = const [];
      _selectedSlot = null;
    });
    await _loadSlots(printer);
  }

  void _ensurePrinterInList(MobilePrinter printer) {
    if (_printers.any((p) => p.id == printer.id)) return;
    _printers = [..._printers, printer];
  }

  Future<void> _loadSlots(MobilePrinter printer) async {
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
      _warnings = const [];
    });
    try {
      final slots = await (await _repo()).fetchPrinterSlots(printer.id);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _selectedSlot = _defaultSlotFor(printer, slots);
      });
    } on ApiException catch (e) {
      _setError(e.detailMessage());
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshForPageSwitch() async {
    if (_busy) return;
    final printer = _printer;
    if (printer == null) {
      await _loadPrinters();
      return;
    }
    await _refreshSelectedPrinter(printer);
  }

  Future<void> _refreshSelectedPrinter(MobilePrinter printer) async {
    _spoolController.clear();
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
      _warnings = const [];
      _spool = null;
    });
    try {
      final repo = await _repo();
      final printers = await repo.fetchPrinters();
      if (!mounted) return;
      final selectedPrinter = _matchingPrinter(printers, printer) ?? printer;
      final slots = await repo.fetchPrinterSlots(selectedPrinter.id);
      if (!mounted) return;
      setState(() {
        _printers = printers.any((p) => p.id == selectedPrinter.id)
            ? printers
            : [...printers, selectedPrinter];
        _printersLoading = false;
        _printersError = null;
        _printer = selectedPrinter;
        _slots = slots;
        _selectedSlot = _defaultSlotFor(selectedPrinter, slots);
      });
    } on ApiException catch (e) {
      _setError(e.detailMessage());
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      _warnings = const [];
      _spool = null;
      _detail = null;
    });
    try {
      final spool = await (await _repo()).resolveSpool(code);
      if (!mounted) return;
      setState(() => _spool = spool);
      await _loadSpoolDetail(spool.id);
    } on ApiException catch (e) {
      _setError(e.detailMessage());
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadSpoolDetail(int spoolId) async {
    try {
      final detail = await (await _repo()).fetchSpoolDetail(spoolId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (_) {
      // Detail is only needed to detect archived spools; a failure here must
      // not block normal assignment, so we degrade gracefully.
    }
  }

  Future<void> _assign({
    bool replaceExisting = false,
    bool moveExisting = false,
  }) async {
    final printer = _printer;
    final spool = _spool;
    final slot = _selectedSlot;
    if (printer == null || spool == null || slot == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
      _warnings = const [];
    });
    try {
      final result = await (await _repo()).assignSpool(
        printerId: printer.id,
        spoolId: spool.id,
        amsId: slot.amsId,
        slot: slot.slot,
        replaceExisting: replaceExisting,
        moveExisting: moveExisting,
      );
      if (!mounted) return;
      final success =
          'Assigned spool #${result.assignment.spoolId} to ${result.assignment.slotLabel}';
      await _refreshAfterAssignment(
        printer: printer,
        success: success,
        warnings: result.warnings,
      );
      _scrollToFeedback();
    } on AssignmentConflictException catch (e) {
      if (mounted) setState(() => _busy = false);
      final confirmed = await _confirmConflict(e);
      if (confirmed && mounted) {
        await _assign(
          replaceExisting: e.confirmsReplaceExisting,
          moveExisting: e.confirmsMoveExisting,
        );
      }
      return;
    } on ApiException catch (e) {
      _setError(e.detailMessage());
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmConflict(AssignmentConflictException conflict) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1F23),
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF2E2E34)),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1400),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF713F12)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Color(0xFFFBBF24),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Confirm assignment',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    conflict.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Divider(height: 1, color: Color(0xFF2E2E34)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFA1A1AA),
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF2E2E34)),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Confirm'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _refreshAfterAssignment({
    required MobilePrinter printer,
    required String success,
    required List<String> warnings,
  }) async {
    _spoolController.clear();
    try {
      final repo = await _repo();
      final printers = await repo.fetchPrinters();
      if (!mounted) return;
      final selectedPrinter = _matchingPrinter(printers, printer) ?? printer;
      final slots = await repo.fetchPrinterSlots(selectedPrinter.id);
      if (!mounted) return;
      setState(() {
        _printers = printers.any((p) => p.id == selectedPrinter.id)
            ? printers
            : [...printers, selectedPrinter];
        _printersLoading = false;
        _printersError = null;
        _printer = selectedPrinter;
        _slots = slots;
        _selectedSlot = _defaultSlotFor(selectedPrinter, slots);
        _spool = null;
        _error = null;
        _success = success;
        _warnings = warnings;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _printer = printer;
        _spool = null;
        _success = success;
        _warnings = warnings;
        _error = 'Assigned, but could not refresh: ${e.detailMessage()}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _printer = printer;
        _spool = null;
        _success = success;
        _warnings = warnings;
        _error = 'Assigned, but could not refresh: $e';
      });
    }
  }

  Future<void> _unassignAll() async {
    final printer = _printer;
    if (printer == null || _busy) return;
    final occupied = _slots
        .where((s) => s.occupied)
        .toList(growable: false);
    if (occupied.isEmpty) return;
    final confirmed = await _confirmUnassignAll(printer, occupied.length);
    if (!confirmed || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
      _warnings = const [];
    });
    final failedLabels = <String>[];
    for (final slot in occupied) {
      try {
        final repo = await _repo();
        await repo.resetSlot(
          slot.printerId,
          slot.amsId,
          slot.trayId ?? slot.slot,
        );
        final spoolId = slot.assignedSpoolId;
        if (spoolId != null) {
          await repo.unassignSpool(spoolId);
        }
      } on ApiException catch (e) {
        failedLabels.add('${slot.label}: ${e.detailMessage()}');
      } catch (e) {
        failedLabels.add('${slot.label}: $e');
      }
    }
    if (!mounted) return;
    final successCount = occupied.length - failedLabels.length;
    try {
      final repo = await _repo();
      final printers = await repo.fetchPrinters();
      if (!mounted) return;
      final updatedPrinter = _matchingPrinter(printers, printer) ?? printer;
      final slots = await repo.fetchPrinterSlots(updatedPrinter.id);
      if (!mounted) return;
      setState(() {
        _printers = printers.any((p) => p.id == updatedPrinter.id)
            ? printers
            : [...printers, updatedPrinter];
        _printersLoading = false;
        _printersError = null;
        _printer = updatedPrinter;
        _slots = slots;
        _selectedSlot = _defaultSlotFor(updatedPrinter, slots);
        if (failedLabels.isEmpty) {
          _success =
              'Unassigned $successCount spool${successCount == 1 ? '' : 's'} from ${printer.name}';
          _error = null;
        } else if (successCount == 0) {
          _success = null;
          _error = 'Could not unassign: ${failedLabels.join('; ')}';
        } else {
          _success = 'Unassigned $successCount of ${occupied.length}';
          _error =
              '${failedLabels.length} slot${failedLabels.length == 1 ? '' : 's'} failed';
        }
        _warnings = const [];
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (failedLabels.isEmpty && successCount > 0) {
          _success =
              'Unassigned $successCount spool${successCount == 1 ? '' : 's'}';
        }
        _error = 'Unassigned, but could not refresh: ${e.detailMessage()}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (failedLabels.isEmpty && successCount > 0) {
          _success =
              'Unassigned $successCount spool${successCount == 1 ? '' : 's'}';
        }
        _error = 'Unassigned, but could not refresh: $e';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _scrollToFeedback();
  }

  Future<bool> _confirmUnassignAll(MobilePrinter printer, int count) async {
    if (!mounted) return false;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1F23),
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF2E2E34)),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0505),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF7F1D1D)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFF87171),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unassign all spools',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Remove $count assignment${count == 1 ? '' : 's'} from ${printer.name}? This cannot be undone.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Color(0xFFA1A1AA),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Divider(height: 1, color: Color(0xFF2E2E34)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFA1A1AA),
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFF2E2E34)),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Unassign all'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return confirmed ?? false;
  }

  MobilePrinter? _matchingPrinter(
    List<MobilePrinter> printers,
    MobilePrinter selected,
  ) {
    for (final printer in printers) {
      if (printer.id == selected.id) return printer;
    }
    return null;
  }

  MobileSlot? _defaultSlotFor(MobilePrinter printer, List<MobileSlot> slots) {
    final model = (printer.model ?? '').toUpperCase();
    final isA1 = model.contains('A1');
    final amsSlots = slots.where((s) => !s.isExternal).toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));
    return isA1 && amsSlots.isNotEmpty
        ? amsSlots.first
        : (slots.isEmpty ? null : slots.first);
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    _scrollToFeedback();
  }

  void _scrollToFeedback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _reset() {
    _spoolController.clear();
    setState(() {
      _printer = null;
      _selectedSlot = null;
      _slots = const [];
      _spool = null;
      _detail = null;
      _error = null;
      _success = null;
      _warnings = const [];
    });
  }

  bool get _canAssign =>
      _printer != null &&
      _spool != null &&
      _selectedSlot != null &&
      !_busy &&
      !_spoolBlocked;

  bool get _hasAssignedSlots => _slots.any((s) => s.occupied);

  bool get _spoolBlocked {
    final spool = _spool;
    if (spool == null) return false;
    if (_detail?.archivedAt != null) return true;
    final remaining = spool.remainingGrams;
    return remaining != null && remaining <= 0;
  }

  String? get _spoolBlockReason {
    final spool = _spool;
    if (spool == null) return null;
    if (_detail?.archivedAt != null) {
      return 'This spool is archived and cannot be assigned.';
    }
    final remaining = spool.remainingGrams;
    if (remaining != null && remaining <= 0) {
      return 'This spool has no filament remaining and cannot be assigned.';
    }
    return null;
  }

  bool get _isA1AmsLayout {
    final model = (_printer?.model ?? '').toUpperCase();
    return model.contains('A1') && _slots.any((s) => !s.isExternal);
  }

  List<MobileSlot> get _amsSlots =>
      (_slots.where((s) => !s.isExternal).toList()
        ..sort((a, b) => a.slot.compareTo(b.slot)));

  String get _printerHint {
    if (_printersLoading) return 'Loading printers…';
    if (_printersError != null) return 'Could not load printers';
    if (_printers.isEmpty) return 'No printers available';
    return 'Select a printer';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF18181B),
      appBar: AppBar(
        title: const Text(
          'Assign',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: const Color(0xFF18181B),
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: (_printer != null && _hasAssignedSlots && !_busy)
                ? _unassignAll
                : null,
            icon: const Icon(Icons.delete_outline_rounded),
            color: const Color(0xFFF87171),
            disabledColor: const Color(0xFF3F3F46),
            tooltip: 'Unassign all',
          ),
          IconButton(
            onPressed: _reset,
            icon: const Icon(Icons.refresh, color: Color(0xFF71717A)),
            tooltip: 'Reset',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF27272A)),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          border: Border(top: BorderSide(color: Color(0xFF27272A))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: _canAssign ? _assign : null,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFFFFFF),
                        ),
                      )
                    : const Icon(Icons.assignment_turned_in_outlined),
                label: const Text('Assign spool'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: const Color(
                    0xFF00C853,
                  ).withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          key: const ValueKey('assign-list'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_error != null) ...[
              _MessageBanner(message: _error!, kind: _MessageKind.error),
              const SizedBox(height: 16),
            ],
            if (_success != null) ...[
              _MessageBanner(message: _success!, kind: _MessageKind.success),
              const SizedBox(height: 8),
            ],
            for (final warning in _warnings) ...[
              _MessageBanner(message: warning, kind: _MessageKind.warning),
              const SizedBox(height: 8),
            ],
            DropdownButtonFormField<MobilePrinter>(
              key: ValueKey('printer-dropdown-${_printer?.id}'),
              initialValue: _printer,
              decoration: InputDecoration(
                labelText: 'Printer',
                prefixIcon: const Icon(Icons.print_outlined),
                suffixIcon: _printersLoading
                    ? const Padding(
                        padding: EdgeInsetsDirectional.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
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
              items: [
                for (final p in _printers)
                  DropdownMenuItem(value: p, child: Text(p.name)),
              ],
              hint: Text(_printerHint),
              onChanged: _busy || _printersLoading ? null : _onPrinterSelected,
            ),
            if (_printersError != null) ...[
              const SizedBox(height: 10),
              _MessageBanner(
                message: _printersError!,
                kind: _MessageKind.error,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : _loadPrinters,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
            ],
            if (_printer != null) ...[
              const SizedBox(height: 12),
              _SummaryLine(
                title: _printer!.name,
                subtitle: [
                  if (_printer!.model != null) _printer!.model!,
                  if (_printer!.serialNumber != null) _printer!.serialNumber!,
                ].join(' | '),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('assign-spool-code-field'),
              controller: _spoolController,
              decoration: const InputDecoration(
                labelText: 'Spool code',
                prefixIcon: Icon(Icons.qr_code_2),
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
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _resolveSpool(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _resolveSpool,
                  icon: const Icon(Icons.search),
                  label: const Text('Resolve spool'),
                ),
              ],
            ),
            if (_spool != null) ...[
              const SizedBox(height: 12),
              _SpoolSummaryCard(spool: _spool!),
              if (_spoolBlockReason != null) ...[
                const SizedBox(height: 8),
                _MessageBanner(
                  message: _spoolBlockReason!,
                  kind: _MessageKind.warning,
                ),
              ],
            ],
            const SizedBox(height: 16),
            _Section(
              title: 'Target slot',
              child: _slots.isEmpty
                  ? const Text(
                      'Resolve a printer to load slots.',
                      style: TextStyle(color: Color(0xFF71717A)),
                    )
                  : _isA1AmsLayout
                  ? _AmsSlotSelector(
                      slots: _amsSlots,
                      selected: _selectedSlot,
                      onSelected: (slot) {
                        if (!_busy) setState(() => _selectedSlot = slot);
                      },
                      busy: _busy,
                    )
                  : Column(
                      children: [
                        RadioGroup<MobileSlot>(
                          groupValue: _selectedSlot,
                          onChanged: (value) {
                            if (_busy || value == null) return;
                            setState(() => _selectedSlot = value);
                          },
                          child: Column(
                            children: [
                              for (final slot in _slots)
                                Material(
                                  type: MaterialType.transparency,
                                  child: RadioListTile<MobileSlot>(
                                    value: slot,
                                    enabled: !_busy,
                                    selected: slot == _selectedSlot,
                                    title: Text(slot.label),
                                    subtitle: slot.description.isEmpty
                                        ? null
                                        : Text(slot.description),
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: const Color(0xFF00C853),
                                    selectedTileColor: const Color(
                                      0xFF00C853,
                                    ).withValues(alpha: 0.08),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        border: Border.all(color: const Color(0xFF2E2E34)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: Color(0xFF71717A),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        border: Border.all(color: const Color(0xFF2E2E34)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF71717A)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpoolSummaryCard extends StatelessWidget {
  const _SpoolSummaryCard({required this.spool});

  final MobileSpool spool;

  @override
  Widget build(BuildContext context) {
    final swatch = _parseHexColor(spool.rgba);
    final infoLine = spool.remainingGrams != null
        ? '${spool.remainingGrams!.toStringAsFixed(1)} g remaining'
        : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        border: Border.all(color: const Color(0xFF2E2E34)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spool.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (spool.colorName != null &&
                      spool.colorName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      spool.colorName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ],
                  if (infoLine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      infoLine,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF71717A),
                      ),
                    ),
                  ],
                  if (spool.currentLocation != null &&
                      spool.currentLocation!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Assigned to ${spool.currentLocation!}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFCD34D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (swatch != null) ...[
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _MessageKind { success, warning, error }

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.kind});

  final String message;
  final _MessageKind kind;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color border;
    final Color textColor;
    final IconData icon;
    final Color iconColor;

    switch (kind) {
      case _MessageKind.error:
        background = const Color(0xFF2C1414);
        border = const Color(0xFF7F1D1D);
        textColor = const Color(0xFFFCA5A5);
        icon = Icons.error_outline_rounded;
        iconColor = const Color(0xFFF87171);
      case _MessageKind.success:
        background = const Color(0xFF0D2818);
        border = const Color(0xFF166534);
        textColor = const Color(0xFF86EFAC);
        icon = Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF4ADE80);
      case _MessageKind.warning:
        background = const Color(0xFF1A1400);
        border = const Color(0xFF713F12);
        textColor = const Color(0xFFFCD34D);
        icon = Icons.warning_amber_rounded;
        iconColor = const Color(0xFFFBBF24);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }
}

Color? _parseHexColor(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().replaceAll('#', '');
  if (s.length == 6) {
    final v = int.tryParse(s, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  if (s.length == 8) {
    final v = int.tryParse(s, radix: 16);
    if (v != null) {
      return Color.fromARGB(
        v & 0xFF,
        (v >> 24) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 8) & 0xFF,
      );
    }
  }
  return null;
}

// Normalized (x, y) of spool mount points, calibrated to Asset 2's coordinate system.
const _kAmsMounts = [
  (0.79, 0.20), // T1 – upper right
  (0.20, 0.20), // T2 – upper left
  (0.20, 0.80), // T3 – lower left
  (0.79, 0.80), // T4 – lower right
];

/// Graphical AMS slot selector for A1 machines.
/// Three SVG layers: body chassis (Asset 3) → dynamic spool painter (Asset 2
/// geometry) → indicator frame (Asset 1). Tapping the canvas selects the
/// nearest spool mount.
class _AmsSlotSelector extends StatelessWidget {
  const _AmsSlotSelector({
    required this.slots,
    required this.selected,
    required this.onSelected,
    this.busy = false,
  });

  final List<MobileSlot> slots;
  final MobileSlot? selected;
  final ValueChanged<MobileSlot> onSelected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final sorted = [...slots]..sort((a, b) => a.slot.compareTo(b.slot));

    return LayoutBuilder(
      builder: (context, constraints) {
        // Asset 2 canvas ratio drives container height so spool geometry
        // fractions derived from viewBox 979.5 × 452.97 map correctly.
        const imageAspect = 979.5 / 452.97;
        final w = constraints.maxWidth;
        final h = w / imageAspect;

        return GestureDetector(
          onTapUp: busy
              ? null
              : (details) {
                  final pos = details.localPosition;
                  MobileSlot? nearest;
                  double? bestSq;
                  for (
                    var i = 0;
                    i < sorted.length && i < _kAmsMounts.length;
                    i++
                  ) {
                    final cx = _kAmsMounts[i].$1 * w;
                    final cy = _kAmsMounts[i].$2 * h;
                    final dx = pos.dx - cx;
                    final dy = pos.dy - cy;
                    final d = dx * dx + dy * dy;
                    if (bestSq == null || d < bestSq) {
                      bestSq = d;
                      nearest = sorted[i];
                    }
                  }
                  if (nearest != null) onSelected(nearest);
                },
          child: SizedBox(
            width: w,
            height: h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Layer 3 – AMS body chassis (bottom)
                Positioned.fill(
                  child: Image.asset(
                    'assets/ui/ams_body.png',
                    fit: BoxFit.fill,
                    color: const Color.fromARGB(255, 209, 209, 209),
                    colorBlendMode: BlendMode.modulate,
                  ),
                ),
                // Layer 2 – dynamic filament fills (painted per-slot)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _AmsSpoolsPainter(
                      slots: sorted,
                      selected: selected,
                    ),
                  ),
                ),
                // Layer 1 – slot indicator frame (portrait, centered, non-interactive)
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

/// Full-canvas painter that draws filament spool shapes for all AMS slots.
/// Spool geometry is normalized from Asset 2 (viewBox 979.5 × 452.97):
/// each spool ≈ 40% of canvas width × 37.5% of canvas height, two banks of
/// two with flanges at top/bottom and a colored body between them.
/// A spool is rendered only when the slot is occupied OR selected.
class _AmsSpoolsPainter extends CustomPainter {
  const _AmsSpoolsPainter({required this.slots, this.selected});

  final List<MobileSlot> slots;
  final MobileSlot? selected;

  // Geometry fractions derived from Asset 2 coordinate system.
  static const _sw = 390.0 / 979.5; // spool width  ≈ 0.398 of canvas w
  static const _sh = 170.0 / 452.97; // spool height ≈ 0.375 of canvas h
  static const _fh = 11.49 / 170.0; // flange fraction of spool height ≈ 6.8%

  static const _flangeColor = Color(0xFF181818);
  static const _accent = Color(0xFF00C853);

  static Color? _hex(String? raw) {
    if (raw == null) return null;
    final h = raw.replaceAll('#', '').trim();
    if (h.length == 6) {
      final v = int.tryParse(h, radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    if (h.length == 8) {
      final v = int.tryParse(h, radix: 16);
      if (v != null) {
        return Color.fromARGB(
          v & 0xFF,
          (v >> 24) & 0xFF,
          (v >> 16) & 0xFF,
          (v >> 8) & 0xFF,
        );
      }
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final spoolW = size.width * _sw;
    final spoolH = size.height * _sh;
    final flangeH = spoolH * _fh;

    for (var i = 0; i < slots.length && i < _kAmsMounts.length; i++) {
      final slot = slots[i];
      final mount = _kAmsMounts[i];

      final isSel =
          selected != null &&
          selected!.slot == slot.slot &&
          selected!.amsId == slot.amsId;
      final occupied = slot.occupied || slot.physicalOccupied;

      if (!occupied && !isSel) continue;

      final cx = mount.$1 * size.width;
      final cy = mount.$2 * size.height;
      final left = cx - spoolW / 2;
      final top = cy - spoolH / 2;
      final bodyTop = top + flangeH;
      final bodyH = spoolH - flangeH * 2;

      // Hub background spanning full spool width.
      canvas.drawRect(
        Rect.fromLTWH(left, bodyTop, spoolW, bodyH),
        Paint()..color = const Color(0xFF1C1C1C),
      );

      if (occupied) {
        // Remaining % not exposed on assign screen — show full width.
        final color = _hex(slot.currentColor) ?? const Color(0xFF6B6B6B);
        canvas.drawRect(
          Rect.fromLTWH(left, bodyTop, spoolW, bodyH),
          Paint()..color = color,
        );

        final gp = Paint()
          ..color = Colors.black.withValues(alpha: 0.13)
          ..strokeWidth = 0.6
          ..style = PaintingStyle.stroke;
        for (var j = 1; j < 5; j++) {
          final y = bodyTop + bodyH * j / 5;
          canvas.drawLine(Offset(left, y), Offset(left + spoolW, y), gp);
        }

        canvas.drawRect(
          Rect.fromLTWH(left, bodyTop, spoolW, bodyH * 0.25),
          Paint()..color = Colors.white.withValues(alpha: 0.07),
        );
      } else {
        // Selected but empty – ghost placeholder.
        canvas.drawRect(
          Rect.fromLTWH(left, bodyTop, spoolW, bodyH),
          Paint()..color = _accent.withValues(alpha: 0.06),
        );
        canvas.drawRect(
          Rect.fromLTWH(left, bodyTop, spoolW, bodyH),
          Paint()
            ..color = _accent.withValues(alpha: 0.28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }

      final flangeColor = isSel
          ? _accent.withValues(alpha: 0.65)
          : _flangeColor;

      // Top flange.
      canvas.drawRect(
        Rect.fromLTWH(left, top, spoolW, flangeH),
        Paint()..color = flangeColor,
      );

      // Bottom flange.
      canvas.drawRect(
        Rect.fromLTWH(left, top + spoolH - flangeH, spoolW, flangeH),
        Paint()..color = flangeColor,
      );

      // Selection border.
      if (isSel) {
        canvas.drawRect(
          Rect.fromLTWH(left, top, spoolW, spoolH),
          Paint()
            ..color = _accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0,
        );
      }

      // Spool ID + material label inside spool body.
      final spoolNum = slot.assignedSpoolId;
      final subColor = occupied
          ? Colors.white.withValues(alpha: 0.58)
          : _accent.withValues(alpha: 0.50);

      TextPainter? numPainter;
      if (occupied && spoolNum != null) {
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

      final mat = slot.currentMaterial;
      TextPainter? matPainter;
      if (mat != null && mat.isNotEmpty) {
        matPainter = TextPainter(
          text: TextSpan(
            text: mat.toUpperCase(),
            style: TextStyle(
              color: subColor,
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

  @override
  bool shouldRepaint(covariant _AmsSpoolsPainter old) =>
      old.slots != slots || old.selected != selected;
}
