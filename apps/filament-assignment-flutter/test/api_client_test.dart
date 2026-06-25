import 'package:assignfilament/src/data/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'production client can re-resolve the base URL before each request',
    () async {
      final requests = <String>[];
      var resolveCount = 0;
      final api = ApiClient(
        'https://print.crav3d.com',
        null,
        MockClient((request) async {
          requests.add(request.url.toString());
          return http.Response('{}', 200);
        }),
        token: 'token',
        baseUrlResolver: () async {
          resolveCount += 1;
          return 'http://192.168.1.10:8000';
        },
      );

      await api.get('/printers/');
      await api.get('/spoolman/inventory/spools');

      expect(resolveCount, 2);
      expect(requests, [
        'http://192.168.1.10:8000/api/v1/printers/',
        'http://192.168.1.10:8000/api/v1/spoolman/inventory/spools',
      ]);
      expect(api.baseUrl, 'http://192.168.1.10:8000');
    },
  );
}
