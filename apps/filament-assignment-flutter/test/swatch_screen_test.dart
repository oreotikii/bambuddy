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
}
