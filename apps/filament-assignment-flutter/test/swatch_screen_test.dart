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

  testWidgets('PLA SILK and PLA METALLIC appear as separate sections from PLA+', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {'id': 1, 'rgba': 'F6F6F0', 'material': 'PLA+', 'brand': 'A', 'color_name': 'Cool White', 'extra_colors': null},
          {'id': 2, 'rgba': 'B87333', 'material': 'PLA SILK', 'brand': 'A', 'color_name': 'Silk Copper', 'extra_colors': null},
          {'id': 3, 'rgba': '3C91E6', 'material': 'PLA METALLIC', 'brand': 'A', 'color_name': 'Titanium Blue', 'extra_colors': null},
        ]),
      ),
    );
    await tester.pump();
    expect(find.text('PLA+'), findsOneWidget);
    expect(find.text('PLA SILK'), findsOneWidget);
    expect(find.text('PLA METALLIC'), findsOneWidget);
    // Ensure PLA SILK is NOT collapsed into PLA+
    expect(find.text('PLA'), findsNothing);
  });

  testWidgets('Screen renders all series types without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          // standard
          {'id': 1, 'rgba': 'F6F6F0', 'material': 'PLA+', 'brand': 'A', 'color_name': 'White', 'extra_colors': null},
          // silk single
          {'id': 2, 'rgba': 'B87333', 'material': 'PLA SILK', 'brand': 'A', 'color_name': 'Copper', 'extra_colors': null},
          // silk multi-color
          {'id': 3, 'rgba': '', 'material': 'PLA SILK', 'brand': 'A', 'color_name': 'Black-Gold', 'extra_colors': '111111,D4AF37'},
          // metallic
          {'id': 4, 'rgba': '3C91E6', 'material': 'PLA METALLIC', 'brand': 'A', 'color_name': 'Titanium Blue', 'extra_colors': null},
          // galaxy
          {'id': 5, 'rgba': '111111', 'material': 'PLA GALAXY', 'brand': 'A', 'color_name': 'Galaxy Black', 'extra_colors': null},
        ]),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('PLA+'), findsOneWidget);
    expect(find.text('PLA SILK'), findsOneWidget);
    expect(find.text('PLA METALLIC'), findsOneWidget);
    expect(find.text('PLA GALAXY'), findsOneWidget);
  });

  testWidgets('Chips with same hue appear before chips with darker lightness', (tester) async {
    // ivory (FFFFF0, very light) and chocolate (5C3317, very dark) — both warm/yellow-orange hue
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {'id': 1, 'rgba': '5C3317', 'material': 'PLA+', 'brand': 'A', 'color_name': 'Chocolate', 'extra_colors': null},
          {'id': 2, 'rgba': 'FFFFF0', 'material': 'PLA+', 'brand': 'A', 'color_name': 'Ivory', 'extra_colors': null},
        ]),
      ),
    );
    await tester.pump();
    // Both chips render — screen is not empty.
    expect(find.text('No spools in inventory'), findsNothing);
    // Ivory name appears before Chocolate in the widget tree (light → dark).
    // Same hue band → same row → same y. Light (Ivory, higher HSL L) appears to the left (lower x).
    expect(tester.getTopLeft(find.text('Ivory')).dx,
        lessThan(tester.getTopLeft(find.text('Chocolate')).dx));
  });

  testWidgets('Detail modal shows individual color rows for multi-color chip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {
            'id': 3,
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
    // Tap the chip — the SizedBox wrapping the chip is 52x* so we tap the label.
    await tester.tap(find.text('Black-Gold'));
    await tester.pumpAndSettle();
    // Expect two separate color rows.
    expect(find.text('#111111'), findsOneWidget);
    expect(find.text('#d4af37'), findsOneWidget);
    // 'Color hex' label must NOT appear (replaced by 'Color 1', 'Color 2').
    expect(find.text('Color hex'), findsNothing);
    expect(find.text('Color 1'), findsOneWidget);
    expect(find.text('Color 2'), findsOneWidget);
  });
}
