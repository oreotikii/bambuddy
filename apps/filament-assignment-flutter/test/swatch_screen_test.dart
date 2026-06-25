import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assignfilament/src/ui/swatch_screen.dart';

void main() {
  testWidgets('SwatchScreen renders empty state with no spools', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SwatchScreen(testSpools: [])),
    );
    await tester.pump();
    expect(find.text('No spools in inventory'), findsOneWidget);
  });

  testWidgets('Multi-color spool (empty rgba, extra_colors set) appears in PLA SILK section', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {
            'id': 10,
            'rgba': '',
            'material': 'PLA SILK',
            'brand': 'Test',
            'color_name': 'Black-Gold',
            'extra_colors': '111111,D4AF37',
          },
        ]),
      ),
    );
    await tester.pump();
    // Section header for PLA SILK must appear.
    expect(find.text('PLA SILK'), findsOneWidget);
    // Must NOT show empty state.
    expect(find.text('No spools in inventory'), findsNothing);
  });
}
