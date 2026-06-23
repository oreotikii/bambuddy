import 'dart:convert';

import 'package:assignfilament/src/app/theme.dart';
import 'package:assignfilament/src/data/api_client.dart';
import 'package:assignfilament/src/ui/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'Status cards normalize finished state and show only assigned AMS spools',
    (tester) async {
      final client = _StatusClient(
        status: {
          'id': 3,
          'name': 'P1S 03',
          'connected': true,
          'state': 'FINISHING',
          'progress': 100,
          'temperatures': {'nozzle': 212.4, 'bed': 63.7},
          'ams': [
            {
              'id': 0,
              'is_ams_ht': false,
              'tray': [
                {
                  'id': 0,
                  'tray_color': '00FF00',
                  'tray_type': 'PETG',
                  'state': 0,
                },
                {'id': 1, 'tray_color': 'FF5500', 'tray_type': 'PLA'},
              ],
            },
          ],
          'vt_tray': [],
        },
        assignments: [
          {'printer_id': 3, 'ams_id': 0, 'tray_id': 1, 'spoolman_spool_id': 42},
        ],
        spools: [
          {
            'id': 42,
            'brand': 'Polymaker',
            'material': 'PLA',
            'subtype': 'Matte',
            'rgba': 'FF5500FF',
            'label_weight': 1000,
            'weight_used': 125,
          },
        ],
      );

      await tester.pumpWidget(
        _testApp(HomeScreen(apiClientFactory: client.api)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Finished'), findsOneWidget);
      expect(find.text('Finishing'), findsNothing);
      expect(find.text('PETG'), findsNothing);
      expect(find.text('AMS1 · T2'), findsOneWidget);
      expect(find.byKey(const ValueKey('slot-swatch-42')), findsOneWidget);
      expect(find.text('#42'), findsOneWidget);
      expect(find.text('PLA'), findsOneWidget);
      expect(find.text('875 g'), findsOneWidget);
      expect(find.text('Filament ID 42'), findsNothing);
      expect(find.text('Polymaker'), findsNothing);
      expect(find.text('Matte'), findsNothing);
      expect(find.text('212°C / 64°C'), findsNothing);
      expect(
        find.byKey(const ValueKey('nozzle-temperature-chip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bed-temperature-chip')),
        findsOneWidget,
      );
      _expectStateLabelStyleChip(
        tester,
        key: const ValueKey('nozzle-temperature-chip'),
        background: const Color(0xFFEA580C).withValues(alpha: 0.13),
      );
      _expectStateLabelStyleChip(
        tester,
        key: const ValueKey('bed-temperature-chip'),
        background: const Color(0xFF2563EB).withValues(alpha: 0.13),
      );

      _expectFilamentRowOrder(tester, 'AMS1 · T2', '#42', 'PLA', '875 g', 42);

      final rowSwatch = tester.widget<Container>(
        find.byKey(const ValueKey('slot-swatch-42')),
      );
      final rowDecoration = rowSwatch.decoration! as BoxDecoration;
      expect(rowDecoration.color, const Color(0xFFFF5500));

      await tester.tap(find.text('#42'));
      await tester.pumpAndSettle();

      expect(find.text('Filament details'), findsOneWidget);
      expect(find.text('Polymaker'), findsOneWidget);
      expect(find.text('PLA'), findsNWidgets(2));
      expect(find.text('Matte'), findsOneWidget);
      expect(find.text('AMS1 · T2'), findsNWidgets(2));

      final swatch = tester.widget<Container>(
        find.byKey(const ValueKey('filament-detail-swatch-42')),
      );
      final decoration = swatch.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFFF5500));
    },
  );

  testWidgets(
    'Status cards show external spool assignments and can unassign them',
    (tester) async {
      final client = _StatusClient(
        printer: {'id': 7, 'name': 'P1S External', 'model': 'P1S'},
        status: {
          'id': 7,
          'name': 'P1S External',
          'connected': true,
          'state': 'IDLE',
          'temperatures': {'nozzle': 25, 'bed': 24},
          'ams': [],
          'vt_tray': [],
        },
        assignments: [
          {
            'printer_id': 7,
            'ams_id': 255,
            'tray_id': 0,
            'spoolman_spool_id': 77,
          },
        ],
        spools: [
          {
            'id': 77,
            'brand': 'Overture',
            'material': 'TPU',
            'subtype': '95A',
            'rgba': '111827FF',
            'label_weight': 1000,
            'weight_used': 240,
          },
        ],
      );

      await tester.pumpWidget(
        _testApp(HomeScreen(apiClientFactory: client.api)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('External Spool'), findsOneWidget);
      expect(find.byKey(const ValueKey('slot-swatch-77')), findsOneWidget);
      expect(find.text('#77'), findsOneWidget);
      expect(find.text('TPU'), findsOneWidget);
      expect(find.text('760 g'), findsOneWidget);
      expect(find.text('Filament ID 77'), findsNothing);
      expect(find.text('Overture'), findsNothing);
      expect(find.text('95A'), findsNothing);

      _expectFilamentRowOrder(
        tester,
        'External Spool',
        '#77',
        'TPU',
        '760 g',
        77,
      );

      await tester.tap(find.text('#77'));
      await tester.pumpAndSettle();

      expect(find.text('Filament details'), findsOneWidget);
      expect(find.text('External Spool'), findsNWidgets(2));
      expect(find.text('Overture'), findsOneWidget);
      expect(find.text('TPU'), findsNWidgets(2));
      expect(find.text('95A'), findsOneWidget);

      await tester.tap(find.text('Unassign filament'));
      await tester.pumpAndSettle();

      expect(find.text('Unassign filament?'), findsOneWidget);
      await tester.tap(find.text('Unassign'));
      await tester.pumpAndSettle();

      expect(
        client.requests,
        contains(
          'DELETE https://bambuddy.test/api/v1/spoolman/inventory/slot-assignments/77',
        ),
      );
      expect(
        find.text('Unassigned spool #77 from External Spool.'),
        findsOneWidget,
      );
      expect(find.text('Overture'), findsNothing);
      expect(find.text('#77'), findsNothing);
    },
  );

  testWidgets('Status cards autosize long printer titles', (tester) async {
    const longName = 'Warehouse North Production Printer With A Very Long Name';
    final client = _StatusClient(
      printer: {'id': 9, 'name': longName, 'model': 'A1'},
      status: {
        'id': 9,
        'name': longName,
        'connected': true,
        'state': 'IDLE',
        'temperatures': {'nozzle': 25, 'bed': 24},
        'ams': [],
        'vt_tray': [],
      },
      assignments: const [],
      spools: const [],
    );

    await tester.pumpWidget(_testApp(HomeScreen(apiClientFactory: client.api)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    expect(_autoSizePrinterTitle(longName), findsOneWidget);
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('Idle'), findsOneWidget);
    _expectModelChip(tester, key: const ValueKey('model-chip-9'));

    final titleRect = tester.getRect(_autoSizePrinterTitle(longName));
    final modelRect = tester.getRect(find.text('A1'));
    final statusRect = tester.getRect(find.text('Idle'));

    expect(statusRect.top, greaterThan(titleRect.bottom));
    expect(titleRect.right, greaterThan(statusRect.right));
    expect((statusRect.center.dy - modelRect.center.dy).abs(), lessThan(6));
  });

  testWidgets('Status page refreshes when refresh nonce changes', (
    tester,
  ) async {
    final client = _StatusClient(
      status: {
        'id': 3,
        'name': 'P1S 03',
        'connected': true,
        'state': 'IDLE',
        'temperatures': {'nozzle': 25, 'bed': 24},
        'ams': [],
        'vt_tray': [],
      },
      assignments: const [],
      spools: const [],
    );

    await tester.pumpWidget(_testApp(HomeScreen(apiClientFactory: client.api)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    final initialPrinterRequests = client.requests
        .where(
          (request) => request == 'GET https://bambuddy.test/api/v1/printers/',
        )
        .length;

    await tester.pumpWidget(
      _testApp(HomeScreen(apiClientFactory: client.api, refreshNonce: 1)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();

    final refreshedPrinterRequests = client.requests
        .where(
          (request) => request == 'GET https://bambuddy.test/api/v1/printers/',
        )
        .length;
    expect(refreshedPrinterRequests, initialPrinterRequests + 1);
  });
}

Widget _testApp(Widget home) {
  return MaterialApp(theme: bambuddyTheme, home: home);
}

void _expectStateLabelStyleChip(
  WidgetTester tester, {
  required Key key,
  required Color background,
}) {
  final chip = tester.widget<Container>(find.byKey(key));
  expect(chip.padding, const EdgeInsets.symmetric(horizontal: 10, vertical: 3));

  final decoration = chip.decoration! as BoxDecoration;
  expect(decoration.color, background);
  expect(decoration.borderRadius, BorderRadius.circular(999));
}

void _expectModelChip(WidgetTester tester, {required Key key}) {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget);
  final chip = tester.widget<Container>(finder);
  expect(chip.padding, const EdgeInsets.symmetric(horizontal: 10, vertical: 3));

  final decoration = chip.decoration! as BoxDecoration;
  expect(decoration.borderRadius, BorderRadius.circular(999));
}

void _expectFilamentRowOrder(
  WidgetTester tester,
  String slot,
  String spoolId,
  String type,
  String weight,
  int swatchId,
) {
  final slotX = tester.getTopLeft(find.text(slot).first).dx;
  final swatchX = tester
      .getTopLeft(find.byKey(ValueKey('slot-swatch-$swatchId')).first)
      .dx;
  final spoolX = tester.getTopLeft(find.text(spoolId).first).dx;
  final typeX = tester.getTopLeft(find.text(type).first).dx;
  final weightX = tester.getTopLeft(find.text(weight).first).dx;

  expect(slotX, lessThan(swatchX));
  expect(swatchX, lessThan(spoolX));
  expect(spoolX, lessThan(typeX));
  expect(typeX, lessThan(weightX));
}

Finder _autoSizePrinterTitle(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget.runtimeType.toString() != 'AutoSizeText') {
      return false;
    }
    try {
      final autoSizeText = widget as dynamic;
      return autoSizeText.data == text &&
          autoSizeText.maxLines == 1 &&
          autoSizeText.minFontSize == 12 &&
          autoSizeText.overflow == TextOverflow.ellipsis &&
          autoSizeText.wrapWords == false;
    } catch (_) {
      return false;
    }
  });
}

class _StatusClient {
  _StatusClient({
    Map<String, dynamic>? printer,
    required this.status,
    required this.assignments,
    required this.spools,
  }) : printer = printer ?? {'id': 3, 'name': 'P1S 03', 'model': 'P1S'};

  final Map<String, dynamic> printer;
  final Map<String, dynamic> status;
  List<Map<String, dynamic>> assignments;
  final List<Map<String, dynamic>> spools;
  final requests = <String>[];

  Future<ApiClient> api() async {
    return ApiClient(
      'https://bambuddy.test',
      'test-key',
      MockClient((request) async {
        requests.add('${request.method} ${request.url}');
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/printers/') {
          return _json([printer]);
        }
        if (request.method == 'GET' &&
            path == '/api/v1/printers/${printer['id']}/status') {
          return _json(status);
        }
        if (request.method == 'GET' &&
            path == '/api/v1/spoolman/inventory/slot-assignments/all') {
          return _json(assignments);
        }
        if (request.method == 'GET' &&
            path == '/api/v1/spoolman/inventory/spools') {
          return _json(spools);
        }
        if (request.method == 'DELETE' &&
            path.startsWith('/api/v1/spoolman/inventory/slot-assignments/')) {
          final spoolId = int.parse(path.split('/').last);
          assignments = assignments
              .where((a) => a['spoolman_spool_id'] != spoolId)
              .toList(growable: false);
          return _json({'ok': true});
        }
        return http.Response('Not found', 404);
      }),
    );
  }

  http.Response _json(Object data) {
    return http.Response(
      jsonEncode(data),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
