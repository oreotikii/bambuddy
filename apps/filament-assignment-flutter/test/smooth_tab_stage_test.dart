import 'package:assignfilament/src/ui/design_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('smooth tab stage animates every tab pane for 400ms', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: false);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: false),
            child: SmoothTabStage(
              index: 1,
              children: [
                Text('Status content'),
                Text('Weigh content'),
                Text('Assign content'),
              ],
            ),
          ),
        ),
      ),
    );

    final opacityAnimations = tester
        .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
        .toList();
    final slideAnimations = tester
        .widgetList<AnimatedSlide>(find.byType(AnimatedSlide))
        .toList();

    expect(opacityAnimations, hasLength(3));
    expect(slideAnimations, hasLength(3));
    expect(opacityAnimations.map((animation) => animation.opacity), [0, 0, 1]);
    expect(slideAnimations.map((animation) => animation.offset), [
      const Offset(0, 0.012),
      const Offset(0, 0.012),
      Offset.zero,
    ]);
    expect(opacityAnimations.map((animation) => animation.duration).toSet(), {
      const Duration(milliseconds: 400),
    });
    expect(slideAnimations.map((animation) => animation.duration).toSet(), {
      const Duration(milliseconds: 400),
    });

    await tester.pumpAndSettle();
  });
}
