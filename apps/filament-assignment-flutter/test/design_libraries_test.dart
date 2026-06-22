import 'package:assignfilament/main.dart';
import 'package:assignfilament/src/app/app_model.dart';
import 'package:assignfilament/src/app/theme.dart';
import 'package:assignfilament/src/ui/design_effects.dart';
import 'package:assignfilament/src/ui/main_scaffold.dart';
import 'package:floaty_nav_bar/floaty_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_villains/villain.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('app installs villain route observer', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(const BambuddyAssignApp());
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      app.navigatorObservers?.whereType<VillainTransitionObserver>(),
      isNotEmpty,
    );
  });

  testWidgets('main shell uses floaty navigation and smooth tab motion', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppModel(),
        child: MaterialApp(theme: bambuddyTheme, home: const MainScaffold()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.byType(Villain), findsNothing);
    expect(find.byType(IndexedStack), findsNothing);
    final tabOpacityFinder = find.descendant(
      of: find.byType(SmoothTabStage),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedOpacity &&
            widget.duration == const Duration(milliseconds: 800) &&
            widget.curve == Curves.easeInOutCubic,
      ),
    );
    final tabSlideFinder = find.descendant(
      of: find.byType(SmoothTabStage),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedSlide &&
            widget.duration == const Duration(milliseconds: 800) &&
            widget.curve == Curves.easeInOutCubic,
      ),
    );
    expect(tabOpacityFinder, findsNWidgets(3));
    expect(tabSlideFinder, findsNWidgets(3));
    expect(find.byType(FloatyTabWidget), findsNWidgets(3));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(GlassContainer), findsNothing);

    final tabWidgets = tester
        .widgetList<FloatyTabWidget>(find.byType(FloatyTabWidget))
        .toList();
    expect(tabWidgets.map((tab) => tab.floatyTab.isSelected), [
      true,
      false,
      false,
    ]);
    expect(tabWidgets.map((tab) => tab.shape.runtimeType).toSet(), {
      CircleShape,
    });
    expect(tabWidgets.map((tab) => tab.floatyTab.title), [
      'Status',
      'Weigh',
      'Assign',
    ]);
    expect(tabWidgets[0].floatyTab.floatyActionButton, isNull);
    expect(tabWidgets[1].floatyTab.floatyActionButton?.tooltip, 'Scan QR');
    expect(tabWidgets[2].floatyTab.floatyActionButton?.tooltip, 'Scan QR');
    _expectSeparatedTabs(tester);
    for (final label in ['Status', 'Weigh', 'Assign']) {
      final tooltip = tester.widget<Tooltip>(
        find.byWidgetPredicate(
          (widget) => widget is Tooltip && widget.message == label,
        ),
      );
      expect(tooltip.child, isA<Padding>());
      final iconPadding = tooltip.child! as Padding;
      expect(
        iconPadding.padding,
        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      );
    }
    expect(find.text('Status'), findsOneWidget);
    expect(find.byTooltip('Scan QR'), findsNothing);

    await tester.tap(find.byIcon(Icons.scale_outlined));
    await tester.pumpAndSettle();

    final weighTabs = tester
        .widgetList<FloatyTabWidget>(find.byType(FloatyTabWidget))
        .toList();
    expect(weighTabs.map((tab) => tab.floatyTab.isSelected), [
      false,
      true,
      false,
    ]);
    expect(weighTabs.map((tab) => tab.shape.runtimeType).toSet(), {
      CircleShape,
    });
    _expectSeparatedTabs(tester);
    expect(find.text('Weigh'), findsOneWidget);
    expect(find.byTooltip('Scan QR'), findsOneWidget);

    final opacityAnimations = tester
        .widgetList<AnimatedOpacity>(tabOpacityFinder)
        .toList();
    final slideAnimations = tester
        .widgetList<AnimatedSlide>(tabSlideFinder)
        .toList();

    expect(
      opacityAnimations.every(
        (animation) =>
            animation.duration == const Duration(milliseconds: 800) &&
            animation.curve == Curves.easeInOutCubic,
      ),
      isTrue,
    );
    expect(
      slideAnimations.every(
        (animation) =>
            animation.duration == const Duration(milliseconds: 800) &&
            animation.curve == Curves.easeInOutCubic,
      ),
      isTrue,
    );
  });

  testWidgets('smooth tab motion is disabled for reduced-motion users', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: SmoothTabStage(
              index: 1,
              children: [Text('Status content'), Text('Weigh content')],
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Status content'), findsNothing);
    expect(find.text('Weigh content'), findsOneWidget);
    expect(find.byType(Villain), findsNothing);
    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(find.byType(AnimatedSlide), findsNothing);
  });
}

void _expectSeparatedTabs(WidgetTester tester) {
  final tabElements = find.byType(FloatyTabWidget).evaluate().toList();
  expect(tabElements, hasLength(3));

  for (var i = 0; i < tabElements.length - 1; i += 1) {
    final current = tabElements[i].renderObject! as RenderBox;
    final next = tabElements[i + 1].renderObject! as RenderBox;
    final currentRight =
        current.localToGlobal(Offset.zero).dx + current.size.width;
    final nextLeft = next.localToGlobal(Offset.zero).dx;

    expect(nextLeft - currentRight, greaterThanOrEqualTo(8));
  }
}
