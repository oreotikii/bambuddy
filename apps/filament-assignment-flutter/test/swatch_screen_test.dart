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
    // PLA+ material normalizes to its own PLA+ section.
    expect(find.text('PLA+'), findsOneWidget);
    expect(find.text('PLA SILK'), findsOneWidget);
    expect(find.text('PLA METALLIC'), findsOneWidget);
    // Pure PLA section must not appear (no PLA-material spool in fixture).
    expect(find.text('PLA'), findsNothing);
  });

  testWidgets('PLA MATTE appears as its own section separate from PLA', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {
            'id': 1,
            'rgba': '1A1A1A',
            'material': 'PLA MATTE',
            'brand': 'A',
            'color_name': 'Matte Black',
            'extra_colors': null,
          },
          {
            'id': 2,
            'rgba': 'FFFFFF',
            'material': 'PLA',
            'brand': 'A',
            'color_name': 'White',
            'extra_colors': null,
          },
        ]),
      ),
    );
    await tester.pump();
    expect(find.text('PLA MATTE'), findsOneWidget);
    expect(find.text('PLA'), findsOneWidget);
  });

  testWidgets('Screen renders all series types without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          // standard (PLA+ normalizes to PLA+ section)
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
    // PLA+ material normalizes to PLA+ section label.
    expect(find.text('PLA+'), findsOneWidget);
    expect(find.text('PLA SILK'), findsOneWidget);
    expect(find.text('PLA METALLIC'), findsOneWidget);
    expect(find.text('PLA GALAXY'), findsOneWidget);
  });

  testWidgets('Light chips appear before dark chips of same hue', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {'id': 1, 'rgba': '5C3317', 'material': 'PLA+', 'brand': 'A', 'color_name': 'Chocolate', 'extra_colors': null},
          {'id': 2, 'rgba': 'FFFFF0', 'material': 'PLA+', 'brand': 'A', 'color_name': 'Ivory', 'extra_colors': null},
        ]),
      ),
    );
    await tester.pump();
    expect(find.text('No spools in inventory'), findsNothing);

    final ivoryChip = find.byKey(const ValueKey('swatch-fffff0'));
    final chocChip = find.byKey(const ValueKey('swatch-5c3317'));
    expect(ivoryChip, findsOneWidget);
    expect(chocChip, findsOneWidget);
    // Ivory (higher lightness) is left of Chocolate in the flat grid.
    expect(
      tester.getTopLeft(ivoryChip).dx,
      lessThan(tester.getTopLeft(chocChip).dx),
    );
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

    // Tap the chip by its hex key (primary color is first extraColor: 111111).
    await tester.tap(find.byKey(const ValueKey('swatch-111111')));
    await tester.pumpAndSettle();

    expect(find.text('#111111'), findsOneWidget);
    expect(find.text('#d4af37'), findsOneWidget);
    expect(find.text('Color hex'), findsNothing);
    expect(find.text('Color 1'), findsOneWidget);
    expect(find.text('Color 2'), findsOneWidget);
  });

  testWidgets('PLA PRO spools appear in the PLA+ section', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {'id': 1, 'rgba': 'F6F6F0', 'material': 'PLA PRO', 'brand': 'A', 'color_name': 'White', 'extra_colors': null},
        ]),
      ),
    );
    await tester.pump();
    expect(find.text('PLA+'), findsOneWidget);
    expect(find.text('PLA PRO'), findsNothing);
  });

  testWidgets('Same hex from two brands produces one chip with two variants in modal', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {'id': 1, 'rgba': 'F0EDE4', 'material': 'PLA+', 'brand': 'Bambu Lab', 'color_name': 'Jade White', 'extra_colors': null},
          {'id': 2, 'rgba': 'F0EDE4', 'material': 'PLA+', 'brand': 'Polymaker', 'color_name': 'Pearl White', 'extra_colors': null},
        ]),
      ),
    );
    await tester.pump();
    // Only one chip should render (same hex).
    expect(find.byKey(const ValueKey('swatch-f0ede4')), findsOneWidget);
    // Open the modal.
    await tester.tap(find.byKey(const ValueKey('swatch-f0ede4')));
    await tester.pumpAndSettle();
    // Both brands must appear (once each).
    expect(find.text('Bambu Lab'), findsOneWidget);
    expect(find.text('Polymaker'), findsOneWidget);
    // For multi-variant chips the modal header shows the material, not primaryName,
    // so each color name appears exactly once (in its own variant row).
    expect(find.text('Jade White'), findsOneWidget);
    expect(find.text('Pearl White'), findsOneWidget);
    // Spool IDs.
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
  });

  testWidgets('Hash-prefixed extra_colors tokens are displayed as multi-color chip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {
            'id': 1,
            'rgba': '',
            'material': 'PLA SILK',
            'brand': 'A',
            'color_name': 'Duo',
            'extra_colors': '#FF0000,#0000FF',
          },
        ]),
      ),
    );
    await tester.pump();
    expect(find.text('No spools in inventory'), findsNothing);
    expect(find.byKey(const ValueKey('swatch-ff0000')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('swatch-ff0000')));
    await tester.pumpAndSettle();
    expect(find.text('#ff0000'), findsOneWidget);
    expect(find.text('#0000ff'), findsOneWidget);
  });

  testWidgets('STARLIGHT material detected as galaxy series without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {'id': 1, 'rgba': '6A0DAD', 'material': 'PLA STARLIGHT', 'brand': 'A', 'color_name': 'Purple Starlight', 'extra_colors': null},
        ]),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // PLA STARLIGHT normalizes to the PLA GALAXY section.
    expect(find.text('PLA GALAXY'), findsOneWidget);
  });

  testWidgets('extra_colors as a JSON array (not string) renders multi-color chip', (tester) async {
    // Spoolman multi_color_hexes arrives as a List via the inventory endpoint.
    await tester.pumpWidget(
      MaterialApp(
        home: SwatchScreen(testSpools: [
          {
            'id': 1,
            'rgba': '808080', // placeholder summary color set by Spoolman
            'material': 'PLA SILK',
            'brand': 'A',
            'color_name': 'Tri-Color',
            'extra_colors': ['ff0000', '0000ff', 'ffffff'], // JSON array
          },
        ]),
      ),
    );
    await tester.pump();
    // Chip key is the first extra_color (ff0000), not the placeholder rgba.
    expect(find.byKey(const ValueKey('swatch-ff0000')), findsOneWidget);
    // Placeholder gray must not appear as its own chip.
    expect(find.byKey(const ValueKey('swatch-808080')), findsNothing);

    // Modal shows the full color set (Color 1 / 2 / 3), not the placeholder.
    await tester.tap(find.byKey(const ValueKey('swatch-ff0000')));
    await tester.pumpAndSettle();
    expect(find.text('Color 1'), findsOneWidget);
    expect(find.text('Color 2'), findsOneWidget);
    expect(find.text('Color 3'), findsOneWidget);
    expect(find.text('#ff0000'), findsOneWidget);
    expect(find.text('#0000ff'), findsOneWidget);
    expect(find.text('#ffffff'), findsOneWidget);
  });

  testWidgets('gray placeholder spool derives multi-color from color_name when extra_colors absent', (tester) async {
    // Simulates a Numakers PLA SILK spool where the backend returns rgba='808080FF'
    // with no extra_colors field — colors are inferred from the descriptive name.
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {
            'id': 27,
            'rgba': '808080FF',
            'material': 'PLA SILK',
            'brand': 'Numakers',
            'color_name': 'Black-Gold',
            'extra_colors': null,
          },
        ]),
      ),
    );
    await tester.pump();
    // Chip key must be the first derived color (black), NOT the gray placeholder.
    expect(find.byKey(const ValueKey('swatch-1a1a1a')), findsOneWidget);
    expect(find.byKey(const ValueKey('swatch-808080')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('swatch-1a1a1a')));
    await tester.pumpAndSettle();
    expect(find.text('Color 1'), findsOneWidget);
    expect(find.text('Color 2'), findsOneWidget);
    expect(find.text('#1a1a1a'), findsOneWidget);
    expect(find.text('#c9a227'), findsOneWidget);
  });

  testWidgets('rgba placeholder with extra_colors does not corrupt single-hex swatch', (tester) async {
    // Spool with real rgba and NO extra_colors must still render as solid chip.
    await tester.pumpWidget(
      const MaterialApp(
        home: SwatchScreen(testSpools: [
          {
            'id': 1,
            'rgba': 'e63946',
            'material': 'PLA',
            'brand': 'A',
            'color_name': 'Red',
            'extra_colors': null,
          },
        ]),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('swatch-e63946')), findsOneWidget);
    // Modal shows the single hex row under label "Hex".
    await tester.tap(find.byKey(const ValueKey('swatch-e63946')));
    await tester.pumpAndSettle();
    expect(find.text('Hex'), findsOneWidget);
    expect(find.text('#e63946'), findsOneWidget);
    expect(find.text('Color 1'), findsNothing);
  });
}
