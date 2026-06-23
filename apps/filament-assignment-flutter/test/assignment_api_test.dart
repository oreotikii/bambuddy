import 'dart:convert';

import 'package:assignfilament/src/core/api_exception.dart';
import 'package:assignfilament/src/data/api_client.dart';
import 'package:assignfilament/src/data/assignment_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('resolvePrinter encodes the code query and parses the printer', () async {
    late http.Request request;
    final api = AssignmentApi(
      ApiClient(
        'https://bambuddy.test',
        'secret-key',
        MockClient((req) async {
          request = req;
          return http.Response(
            jsonEncode({
              'ok': true,
              'printer': {
                'id': 3,
                'name': 'p1s-03',
                'serial_number': '00M09A123456789',
                'model': 'P1S',
                'connected': true,
                'status': 'IDLE',
              },
            }),
            200,
          );
        }),
      ),
    );

    final printer = await api.resolvePrinter('printer:p1s-03');

    expect(
      request.url.toString(),
      'https://bambuddy.test/api/v1/mobile-assignment/resolve-printer?code=printer%3Ap1s-03',
    );
    expect(request.headers['X-API-Key'], 'secret-key');
    expect(printer.id, 3);
    expect(printer.name, 'p1s-03');
    expect(printer.serialNumber, '00M09A123456789');
  });

  test(
    'fetchPrinterSlots builds the printer_id query and parses slot state',
    () async {
      late http.Request request;
      final api = AssignmentApi(
        ApiClient(
          'https://bambuddy.test',
          'secret-key',
          MockClient((req) async {
            request = req;
            return http.Response(
              jsonEncode({
                'ok': true,
                'printer': {'id': 3, 'name': 'p1s-03'},
                'inventory_mode': 'spoolman',
                'slots': [
                  {
                    'printer_id': 3,
                    'ams_id': 0,
                    'slot': 1,
                    'tray_id': 1,
                    'label': 'A2',
                    'unit_name': 'AMS A',
                    'is_external': false,
                    'is_ams_ht': false,
                    'occupied': true,
                    'physical_occupied': true,
                    'assigned_spool_id': 42,
                    'assigned_source': 'spoolman',
                    'current_material': 'PLA',
                    'current_color': '000000',
                    'current_color_name': 'Black',
                    'state': 0,
                  },
                ],
              }),
              200,
            );
          }),
        ),
      );

      final slots = await api.fetchPrinterSlots(3);

      expect(
        request.url.toString(),
        'https://bambuddy.test/api/v1/mobile-assignment/printer-slots?printer_id=3',
      );
      expect(slots.single.label, 'A2');
      expect(slots.single.occupied, isTrue);
      expect(slots.single.assignedSpoolId, 42);
    },
  );

  test('assignSpool posts the expected body and parses warnings', () async {
    late http.Request request;
    final api = AssignmentApi(
      ApiClient(
        'https://bambuddy.test',
        'secret-key',
        MockClient((req) async {
          request = req;
          return http.Response(
            jsonEncode({
              'ok': true,
              'assignment': {
                'printer_id': 3,
                'printer_name': 'p1s-03',
                'ams_id': 0,
                'slot': 1,
                'tray_id': 1,
                'slot_label': 'A2',
                'spool_id': 42,
                'inventory_mode': 'spoolman',
                'location': 'p1s-03 - AMS A Slot 2',
                'material': 'PLA',
                'color': '000000',
              },
              'warnings': ['Material mismatch'],
            }),
            200,
          );
        }),
      ),
    );

    final result = await api.assignSpool(
      printerId: 3,
      spoolId: 42,
      amsId: 0,
      slot: 1,
      replaceExisting: true,
    );

    expect(request.method, 'POST');
    expect(
      request.url.toString(),
      'https://bambuddy.test/api/v1/mobile-assignment/assign',
    );
    expect(jsonDecode(request.body), {
      'printer_id': 3,
      'spool_id': 42,
      'ams_id': 0,
      'slot': 1,
      'replace_existing': true,
      'move_existing': false,
    });
    expect(result.assignment.slotLabel, 'A2');
    expect(result.warnings, ['Material mismatch']);
  });

  test(
    'assignSpool turns confirmable 409 details into a conflict exception',
    () async {
      final api = AssignmentApi(
        ApiClient(
          'https://bambuddy.test',
          'secret-key',
          MockClient((req) async {
            return http.Response(
              jsonEncode({
                'detail': {
                  'ok': false,
                  'code': 'TARGET_SLOT_OCCUPIED',
                  'message': 'Target slot already has a spool.',
                  'can_confirm': true,
                  'confirm_field': 'replace_existing',
                },
              }),
              409,
            );
          }),
        ),
      );

      final call = api.assignSpool(
        printerId: 3,
        spoolId: 42,
        amsId: 0,
        slot: 1,
      );

      await expectLater(
        call,
        throwsA(
          isA<AssignmentConflictException>()
              .having((e) => e.code, 'code', 'TARGET_SLOT_OCCUPIED')
              .having(
                (e) => e.message,
                'message',
                'Target slot already has a spool.',
              )
              .having(
                (e) => e.confirmField,
                'confirmField',
                'replace_existing',
              ),
        ),
      );
    },
  );

  test(
    'updateSpoolWeigh patches only the provided fields to the weigh endpoint',
    () async {
      late http.Request request;
      final api = AssignmentApi(
        ApiClient(
          'https://bambuddy.test',
          'secret-key',
          MockClient((req) async {
            request = req;
            return http.Response(jsonEncode({'ok': true}), 200);
          }),
        ),
      );

      await api.updateSpoolWeigh(
        42,
        measuredWeight: 870.5,
        emptySpoolWeight: 210,
        location: 'Shelf 3',
      );

      expect(request.method, 'PATCH');
      expect(
        request.url.toString(),
        'https://bambuddy.test/api/v1/spoolman/inventory/spools/42/weigh',
      );
      expect(
        jsonDecode(request.body),
        {
          'measured_weight': 870.5,
          'empty_spool_weight': 210,
          'location': 'Shelf 3',
        },
      );
    },
  );

  test('unassignSpool sends DELETE to the spoolman slot-assignment endpoint', () async {
    late http.Request request;
    final api = AssignmentApi(
      ApiClient(
        'https://bambuddy.test',
        'secret-key',
        MockClient((req) async {
          request = req;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      ),
    );

    await api.unassignSpool(42);

    expect(request.method, 'DELETE');
    expect(
      request.url.toString(),
      'https://bambuddy.test/api/v1/spoolman/inventory/slot-assignments/42',
    );
  });

  test('resetSlot sends POST to the correct printer/ams/tray/reset endpoint', () async {
    late http.Request request;
    final api = AssignmentApi(
      ApiClient(
        'https://bambuddy.test',
        'secret-key',
        MockClient((req) async {
          request = req;
          return http.Response(jsonEncode({}), 200);
        }),
      ),
    );

    await api.resetSlot(3, 0, 1);

    expect(request.method, 'POST');
    expect(
      request.url.toString(),
      'https://bambuddy.test/api/v1/printers/3/ams/0/tray/1/reset',
    );
  });

  test('resolveSpool preserves unauthorized API exceptions', () async {
    final api = AssignmentApi(
      ApiClient(
        'https://bambuddy.test',
        'secret-key',
        MockClient((req) async => http.Response('', 401)),
      ),
    );

    final call = api.resolveSpool('spool:42');

    await expectLater(
      call,
      throwsA(
        isA<ApiException>().having(
          (e) => e.isUnauthorized,
          'unauthorized',
          true,
        ),
      ),
    );
  });
}
