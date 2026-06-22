import 'package:assignfilament/src/app/theme.dart';
import 'package:assignfilament/src/data/assignment_repository.dart';
import 'package:assignfilament/src/ui/assign_screen.dart';
import 'package:assignfilament/src/ui/weigh_screen.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Weight flow resolves a manually entered spool and updates grams',
    (tester) async {
      final repo = _FakeAssignmentRepository();

      await tester.pumpWidget(_testApp(WeighScreen(repository: repo)));

      expect(find.text('Update spool'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('spool-code-field')),
        'spool:42',
      );
      await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
      await tester.pumpAndSettle();

      expect(repo.resolvedSpoolCodes, ['spool:42']);
      expect(find.text('Polymaker'), findsOneWidget);
      expect(find.text('PLA'), findsOneWidget);
      expect(find.text('Black'), findsOneWidget);
      expect(_button(tester, 'Update spool').onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('weight-grams-field')),
        '870.5',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Update spool'));
      await tester.pumpAndSettle();

      expect(repo.weighCalls, hasLength(1));
      expect(repo.weighCalls.single.measuredWeight, 870.5);
      expect(repo.weighCalls.single.emptySpoolWeight, isNull);
      expect(repo.weighCalls.single.location, isNull);
      expect(find.text('Updated weight for spool #42'), findsNWidgets(2));
      _expectSuccessNotification(
        tester,
        title: 'Spool updated',
        message: 'Updated weight for spool #42',
      );
    },
  );

  testWidgets('Weight scan action uses the injected scanner callback', (
    tester,
  ) async {
    final repo = _FakeAssignmentRepository();

    await tester.pumpWidget(
      _testApp(
        WeighScreen(
          repository: repo,
          scannerLauncher: (_, _) async => 'spool:42',
        ),
      ),
    );

    await tester.tap(find.byTooltip('Scan spool'));
    await tester.pumpAndSettle();

    expect(repo.resolvedSpoolCodes, ['spool:42']);
    expect(find.text('Polymaker'), findsOneWidget);
    expect(find.text('PLA'), findsOneWidget);
  });

  testWidgets(
    'Assign flow resolves printer and spool, chooses a slot, and shows warnings',
    (tester) async {
      final repo = _FakeAssignmentRepository();

      await tester.pumpWidget(_testApp(AssignScreen(repository: repo)));

      expect(_button(tester, 'Assign spool').onPressed, isNull);

      await tester.pumpAndSettle();
      await _selectPrinter(tester, 'p1s-03');

      await tester.enterText(
        find.byKey(const ValueKey('assign-spool-code-field')),
        'spool:42',
      );
      await _ensureVisibleAndTap(tester, find.text('Resolve spool'));
      await tester.pumpAndSettle();

      await _scrollAssignTo(tester, find.text('A2'));
      await tester.tap(find.text('A2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign spool'));
      await tester.pumpAndSettle();

      expect(repo.resolvedPrinterCodes, isEmpty);
      expect(repo.resolvedSpoolCodes, ['spool:42']);
      expect(repo.slotFetches, [3]);
      expect(repo.assignCalls.single.slot, 1);
      expect(find.text('Assigned spool #42 to A2'), findsNWidgets(2));
      _expectSuccessNotification(
        tester,
        title: 'Assignment saved',
        message: 'Assigned spool #42 to A2',
      );
      expect(find.text('Material mismatch'), findsOneWidget);
    },
  );

  testWidgets('Assign scan actions use the injected scanner callback', (
    tester,
  ) async {
    final repo = _FakeAssignmentRepository();
    final scanned = <String>['printer:p1s-03', 'spool:42'];

    await tester.pumpWidget(
      _testApp(
        AssignScreen(
          repository: repo,
          scannerLauncher: (_, _) async => scanned.removeAt(0),
        ),
      ),
    );

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    await _scrollAssignTo(tester, find.text('Scan spool'));
    await tester.tap(find.text('Scan spool'));
    await tester.pumpAndSettle();

    expect(repo.resolvedPrinterCodes, ['printer:p1s-03']);
    expect(repo.resolvedSpoolCodes, ['spool:42']);
    expect(find.text('Polymaker PLA Black'), findsOneWidget);
  });

  testWidgets(
    'Assign flow confirms replace_existing conflicts and keeps warnings visible',
    (tester) async {
      final repo = _FakeAssignmentRepository()..conflictOnFirstAssign = true;

      await tester.pumpWidget(_testApp(AssignScreen(repository: repo)));

      await tester.pumpAndSettle();
      await _selectPrinter(tester, 'p1s-03');
      await tester.enterText(
        find.byKey(const ValueKey('assign-spool-code-field')),
        '42',
      );
      await _ensureVisibleAndTap(tester, find.text('Resolve spool'));
      await tester.pumpAndSettle();
      await _scrollAssignTo(tester, find.text('A2'));
      await tester.tap(find.text('A2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign spool'));
      await tester.pumpAndSettle();

      expect(find.text('Target slot already has a spool.'), findsOneWidget);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(repo.assignCalls, hasLength(2));
      expect(repo.assignCalls.last.replaceExisting, isTrue);
      expect(repo.assignCalls.last.moveExisting, isFalse);
      expect(find.text('Assigned spool #42 to A2'), findsNWidgets(2));
      _expectSuccessNotification(
        tester,
        title: 'Assignment saved',
        message: 'Assigned spool #42 to A2',
      );
      expect(find.text('Material mismatch'), findsOneWidget);
    },
  );
}

Widget _testApp(Widget home) {
  return MaterialApp(theme: bambuddyTheme, home: home);
}

ElevatedButton _button(WidgetTester tester, String label) {
  return tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, label).first,
  );
}

void _expectSuccessNotification(
  WidgetTester tester, {
  required String title,
  required String message,
}) {
  final content = tester.widget<AwesomeSnackbarContent>(
    find.byType(AwesomeSnackbarContent),
  );
  expect(content.title, title);
  expect(content.message, message);
  expect(content.contentType, ContentType.success);
}

Future<void> _ensureVisibleAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _scrollAssignTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _selectPrinter(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('printer-dropdown-null')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

class _FakeAssignmentRepository implements AssignmentRepository {
  final resolvedPrinterCodes = <String>[];
  final resolvedSpoolCodes = <String>[];
  final slotFetches = <int>[];
  final assignCalls = <_AssignCall>[];
  final weighCalls = <_WeighCall>[];

  bool conflictOnFirstAssign = false;

  @override
  Future<MobilePrinter> resolvePrinter(String code) async {
    resolvedPrinterCodes.add(code);
    return const MobilePrinter(
      id: 3,
      name: 'p1s-03',
      serialNumber: '00M09A123456789',
      model: 'P1S',
      connected: true,
      status: 'IDLE',
    );
  }

  @override
  Future<List<MobilePrinter>> fetchPrinters() async => const [
    MobilePrinter(
      id: 3,
      name: 'p1s-03',
      serialNumber: '00M09A123456789',
      model: 'P1S',
      connected: true,
      status: 'IDLE',
    ),
    MobilePrinter(id: 5, name: 'p1s-05', model: 'P1S'),
  ];

  @override
  Future<MobileSpool> resolveSpool(String code) async {
    resolvedSpoolCodes.add(code);
    return const MobileSpool(
      id: 42,
      inventoryMode: 'spoolman',
      material: 'PLA',
      brand: 'Polymaker',
      colorName: 'Black',
      remainingGrams: 870.5,
      currentLocation: 'Shelf 1',
    );
  }

  @override
  Future<List<MobileSlot>> fetchPrinterSlots(int printerId) async {
    slotFetches.add(printerId);
    return const [
      MobileSlot(
        printerId: 3,
        amsId: 0,
        slot: 0,
        trayId: 0,
        label: 'A1',
        unitName: 'AMS A',
      ),
      MobileSlot(
        printerId: 3,
        amsId: 0,
        slot: 1,
        trayId: 1,
        label: 'A2',
        unitName: 'AMS A',
        occupied: true,
        assignedSpoolId: 21,
      ),
    ];
  }

  @override
  Future<MobileAssignResult> assignSpool({
    required int printerId,
    required int spoolId,
    required int amsId,
    required int slot,
    bool replaceExisting = false,
    bool moveExisting = false,
  }) async {
    assignCalls.add(
      _AssignCall(
        printerId: printerId,
        spoolId: spoolId,
        amsId: amsId,
        slot: slot,
        replaceExisting: replaceExisting,
        moveExisting: moveExisting,
      ),
    );
    if (conflictOnFirstAssign && assignCalls.length == 1) {
      throw const AssignmentConflictException(
        code: 'TARGET_SLOT_OCCUPIED',
        message: 'Target slot already has a spool.',
        confirmField: 'replace_existing',
      );
    }
    return const MobileAssignResult(
      assignment: MobileAssignment(
        printerId: 3,
        printerName: 'p1s-03',
        amsId: 0,
        slot: 1,
        trayId: 1,
        slotLabel: 'A2',
        spoolId: 42,
        inventoryMode: 'spoolman',
        location: 'p1s-03 - AMS A Slot 2',
        material: 'PLA',
        color: '000000',
      ),
      warnings: ['Material mismatch'],
    );
  }

  @override
  Future<List<String>> fetchSpoolLocations() async => const ['Shelf 1'];

  @override
  Future<MobileSpoolDetail> fetchSpoolDetail(int spoolId) async {
    return const MobileSpoolDetail(coreWeight: 250, storageLocation: 'Shelf 1');
  }

  @override
  Future<void> updateSpoolWeigh(
    int spoolId, {
    double? measuredWeight,
    double? emptySpoolWeight,
    String? location,
  }) async {
    weighCalls.add(
      _WeighCall(
        measuredWeight: measuredWeight,
        emptySpoolWeight: emptySpoolWeight,
        location: location,
      ),
    );
  }
}

class _WeighCall {
  const _WeighCall({this.measuredWeight, this.emptySpoolWeight, this.location});

  final double? measuredWeight;
  final double? emptySpoolWeight;
  final String? location;
}

class _AssignCall {
  const _AssignCall({
    required this.printerId,
    required this.spoolId,
    required this.amsId,
    required this.slot,
    required this.replaceExisting,
    required this.moveExisting,
  });

  final int printerId;
  final int spoolId;
  final int amsId;
  final int slot;
  final bool replaceExisting;
  final bool moveExisting;
}
