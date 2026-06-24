import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Full-screen sheet that lets the user tap a captured image to sample a color.
/// Returns the sampled [Color] when the user confirms, or null on cancel.
Future<Color?> showCameraColorPicker(BuildContext context, File imageFile) {
  return Navigator.of(context).push<Color>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _CameraColorPickerPage(imageFile: imageFile),
    ),
  );
}

class _CameraColorPickerPage extends StatefulWidget {
  const _CameraColorPickerPage({required this.imageFile});
  final File imageFile;

  @override
  State<_CameraColorPickerPage> createState() => _CameraColorPickerPageState();
}

class _CameraColorPickerPageState extends State<_CameraColorPickerPage> {
  img.Image? _decoded;
  Color? _picked;
  Offset? _indicator; // position in widget space of the last tap

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await widget.imageFile.readAsBytes();
    var decoded = img.decodeImage(bytes);
    if (decoded != null) decoded = img.bakeOrientation(decoded);
    if (mounted) setState(() => _decoded = decoded);
  }

  void _onTap(TapDownDetails details, BoxConstraints constraints) {
    final decoded = _decoded;
    if (decoded == null) return;

    final widgetW = constraints.maxWidth;
    final widgetH = constraints.maxHeight;
    final imgW = decoded.width.toDouble();
    final imgH = decoded.height.toDouble();

    // Compute where the image is rendered within the widget (BoxFit.contain).
    double dispW, dispH, offX, offY;
    if (imgW / imgH > widgetW / widgetH) {
      dispW = widgetW;
      dispH = widgetW * imgH / imgW;
      offX = 0;
      offY = (widgetH - dispH) / 2;
    } else {
      dispH = widgetH;
      dispW = widgetH * imgW / imgH;
      offX = (widgetW - dispW) / 2;
      offY = 0;
    }

    final tapX = details.localPosition.dx - offX;
    final tapY = details.localPosition.dy - offY;
    if (tapX < 0 || tapY < 0 || tapX > dispW || tapY > dispH) return;

    final pixX = (tapX / dispW * imgW).round().clamp(0, decoded.width - 1);
    final pixY = (tapY / dispH * imgH).round().clamp(0, decoded.height - 1);

    final pixel = decoded.getPixel(pixX, pixY);
    final color = Color.fromARGB(
      255,
      pixel.r.toInt().clamp(0, 255),
      pixel.g.toInt().clamp(0, 255),
      pixel.b.toInt().clamp(0, 255),
    );

    setState(() {
      _indicator = details.localPosition;
      _picked = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pick color',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: _decoded == null
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) => _onTap(d, constraints),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(widget.imageFile, fit: BoxFit.contain),
                            if (_indicator != null && picked != null)
                              Positioned(
                                left: _indicator!.dx - 22,
                                top: _indicator!.dy - 22,
                                child: _ColorIndicator(color: picked),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          _ConfirmBar(
            picked: picked,
            onConfirm: picked == null
                ? null
                : () => Navigator.pop(context, picked),
          ),
        ],
      ),
    );
  }
}

class _ColorIndicator extends StatelessWidget {
  const _ColorIndicator({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, spreadRadius: 1),
        ],
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.picked, required this.onConfirm});
  final Color? picked;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final picked = this.picked;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottomPad),
      color: const Color(0xFF18181B),
      child: Row(
        children: [
          if (picked != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: picked,
                border: Border.all(color: const Color(0xFF3F3F46), width: 2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '#${_toHex(picked)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ] else
            const Text(
              'Tap the image to sample a color',
              style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
            ),
          const Spacer(),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.black,
              disabledBackgroundColor:
                  const Color(0xFF00C853).withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Use color',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

String _toHex(Color c) =>
    (c.r * 255).round().toRadixString(16).padLeft(2, '0') +
    (c.g * 255).round().toRadixString(16).padLeft(2, '0') +
    (c.b * 255).round().toRadixString(16).padLeft(2, '0');
