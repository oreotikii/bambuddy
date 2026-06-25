import 'package:assignfilament/src/data/base_url_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BaseUrlResolver', () {
    test('uses internal URL when the probe succeeds', () async {
      final resolver = BaseUrlResolver(
        externalBaseUrl: 'https://print.crav3d.com',
        internalBaseUrl: 'http://192.168.1.10:8000',
        probe: (_, _) async => true,
      );

      await expectLater(
        resolver.resolve(),
        completion('http://192.168.1.10:8000'),
      );
    });

    test('falls back to external URL when the probe fails', () async {
      final resolver = BaseUrlResolver(
        externalBaseUrl: 'https://print.crav3d.com',
        internalBaseUrl: 'http://192.168.1.10:8000',
        probe: (_, _) async => false,
      );

      await expectLater(
        resolver.resolve(),
        completion('https://print.crav3d.com'),
      );
    });

    test('falls back to external URL when internal URL is invalid', () async {
      var probeCalled = false;
      final resolver = BaseUrlResolver(
        externalBaseUrl: 'https://print.crav3d.com',
        internalBaseUrl: '192.168.1.10:8000',
        probe: (_, _) async {
          probeCalled = true;
          return true;
        },
      );

      await expectLater(
        resolver.resolve(),
        completion('https://print.crav3d.com'),
      );
      expect(probeCalled, isFalse);
    });

    test('returns null when external URL is invalid', () async {
      final resolver = BaseUrlResolver(
        externalBaseUrl: 'not a url',
        internalBaseUrl: 'http://192.168.1.10:8000',
        probe: (_, _) async => true,
      );

      await expectLater(resolver.resolve(), completion(isNull));
    });

    test('normalizes base URLs before returning a selection', () async {
      final resolver = BaseUrlResolver(
        externalBaseUrl: 'https://print.crav3d.com/',
        internalBaseUrl: 'http://192.168.1.10:8000/',
        probe: (_, _) async => true,
      );

      await expectLater(
        resolver.resolve(),
        completion('http://192.168.1.10:8000'),
      );
    });
  });
}
