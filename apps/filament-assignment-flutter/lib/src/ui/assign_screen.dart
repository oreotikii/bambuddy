import 'package:flutter/material.dart';

/// Assign screen — placeholder for the next pass.
/// Will port AssignActivity: QR scan (printer then spool) + select AMS slot +
/// POST the assignment via the mobile-assignment endpoints.
class AssignScreen extends StatelessWidget {
  const AssignScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign spool'),
        backgroundColor: cs.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_scanner, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Assign — coming next',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'QR scan (printer → spool), AMS-slot selection, and the mobile-assignment flow land in the next pass.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
