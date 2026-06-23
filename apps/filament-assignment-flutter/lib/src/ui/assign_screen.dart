import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../data/api_client.dart';
import '../data/assignment_repository.dart';
import 'scanner_sheet.dart';

class AssignScreen extends StatefulWidget {
  const AssignScreen({super.key, this.repository, this.scannerLauncher});

  final AssignmentRepository? repository;
  final CodeScannerLauncher? scannerLauncher;

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
        _selectedSlot = slots.isEmpty ? null : slots.first;
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
    });
    try {
      final spool = await (await _repo()).resolveSpool(code);
      if (!mounted) return;
      setState(() => _spool = spool);
    } on ApiException catch (e) {
      _setError(e.detailMessage());
    } catch (e) {
      _setError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
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
      setState(() {
        _success = success;
        _warnings = result.warnings;
      });
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
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm assignment'),
          content: Text(conflict.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
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
      _error = null;
      _success = null;
      _warnings = const [];
    });
  }

  bool get _canAssign =>
      _printer != null && _spool != null && _selectedSlot != null && !_busy;

  String get _printerHint {
    if (_printersLoading) return 'Loading printers…';
    if (_printersError != null) return 'Could not load printers';
    if (_printers.isEmpty) return 'No printers available';
    return 'Select a printer';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign'),
        backgroundColor: cs.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
              _SummaryLine(
                title: _spool!.displayName,
                subtitle: [
                  'Spool #${_spool!.id}',
                  if (_spool!.remainingGrams != null)
                    '${_spool!.remainingGrams!.toStringAsFixed(1)} g remaining',
                  if (_spool!.currentLocation != null) _spool!.currentLocation!,
                ].join(' | '),
              ),
            ],
            const SizedBox(height: 16),
            _Section(
              title: 'Target slot',
              child: _slots.isEmpty
                  ? Text(
                      'Resolve a printer to load slots.',
                      style: TextStyle(color: cs.onSurfaceVariant),
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
                                RadioListTile<MobileSlot>(
                                  value: slot,
                                  enabled: !_busy,
                                  selected: slot == _selectedSlot,
                                  title: Text(slot.label),
                                  subtitle: slot.description.isEmpty
                                      ? null
                                      : Text(slot.description),
                                  contentPadding: EdgeInsets.zero,
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
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
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
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
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
    final cs = Theme.of(context).colorScheme;
    final background = switch (kind) {
      _MessageKind.success => cs.primaryContainer,
      _MessageKind.warning => cs.tertiaryContainer,
      _MessageKind.error => cs.errorContainer,
    };
    final foreground = switch (kind) {
      _MessageKind.success => cs.onPrimaryContainer,
      _MessageKind.warning => cs.onTertiaryContainer,
      _MessageKind.error => cs.onErrorContainer,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: foreground)),
      ),
    );
  }
}
