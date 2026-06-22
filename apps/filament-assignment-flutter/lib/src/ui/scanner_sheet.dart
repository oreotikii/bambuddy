import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

typedef CodeScannerLauncher =
    Future<String?> Function(BuildContext context, String title);

Future<String?> showCodeScanner(BuildContext context, String title) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ScannerSheet(title: title),
  );
}

class ScannerSheet extends StatefulWidget {
  const ScannerSheet({required this.title, super.key});

  final String title;

  @override
  State<ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<ScannerSheet>
    with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  final _manualController = TextEditingController();
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      torchEnabled: false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.stop());
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      _handled = true;
      unawaited(_controller.stop());
      Navigator.of(context).pop(value);
      return;
    }
  }

  void _submitManual() {
    final value = _manualController.text.trim();
    if (value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 280,
              child: MobileScanner(
                controller: _controller,
                onDetect: _handleCapture,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _manualController,
            decoration: const InputDecoration(
              labelText: 'Manual code',
              prefixIcon: Icon(Icons.keyboard_outlined),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submitManual(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _submitManual,
            icon: const Icon(Icons.check),
            label: const Text('Use code'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
