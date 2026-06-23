import 'package:assignfilament/main.dart';
import 'package:assignfilament/src/app/app_model.dart';
import 'package:assignfilament/src/app/theme.dart';
import 'package:assignfilament/src/ui/design_effects.dart';
import 'package:assignfilament/src/ui/main_scaffold.dart';
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

    final villain = tester.widget<Villain>(find.byType(Villain).first);
    expect(villain.villainAnimation.to, const Duration(milliseconds: 400));
    expect(
      villain.secondaryVillainAnimation?.to,
      const Duration(milliseconds: 400),
    );
  });

  testWidgets('main shell uses custom floaty navigation', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppModel(),
        child: MaterialApp(theme: bambuddyTheme, home: const MainScaffold()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(Villain), findsNothing);
    expect(find.byType(SmoothTabStage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(GlassContainer), findsNothing);

    for (final label in ['Status', 'Weigh', 'Assign']) {
      expect(find.text(label), findsWidgets);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Tooltip && widget.message == label,
        ),
        findsOneWidget,
      );
    }
    expect(find.byIcon(Icons.dashboard), findsWidgets);
    expect(find.byIcon(Icons.scale_outlined), findsWidgets);
    expect(find.byIcon(Icons.assignment_turned_in_outlined), findsWidgets);
    expect(find.byTooltip('Scan QR'), findsNothing);

    await tester.tap(find.byIcon(Icons.scale_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Weigh'), findsOneWidget);
    expect(find.byIcon(Icons.scale), findsWidgets);
    expect(find.byTooltip('Scan QR'), findsOneWidget);
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
