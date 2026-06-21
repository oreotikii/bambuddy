import 'package:flutter/material.dart';

/// Weigh screen — placeholder for the next pass.
/// Will port WeighActivity: manual weight entry + WeighMath + PATCH /spools/{id}/weigh.
class WeighScreen extends StatelessWidget {
  const WeighScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weigh spool'),
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
              Icon(Icons.scale_outlined, size: 64, color: cs.onSurfaceVariant),
              const SizedBox(height: 16),
              Text('Weigh — coming next',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Manual weight entry, empty-spool tare, and remaining-weight calc (PATCH /spools/{id}/weigh) land in the next pass.',
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
