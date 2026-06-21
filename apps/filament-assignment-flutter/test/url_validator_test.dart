import 'package:flutter_test/flutter_test.dart';

import 'package:assignfilament/src/core/url_validator.dart';

void main() {
  group('UrlValidator.normalize', () {
    test('accepts valid http/https with host', () {
      expect(UrlValidator.normalize('https://bambuddy.local'), 'https://bambuddy.local');
      expect(UrlValidator.normalize('http://192.168.1.10'), 'http://192.168.1.10');
      expect(UrlValidator.normalize('https://host:8443'), 'https://host:8443');
      expect(UrlValidator.normalize('https://host/bambuddy'), 'https://host/bambuddy');
      expect(UrlValidator.normalize('https://host/bambuddy/'), 'https://host/bambuddy');
    });

    test('trims and lowercases scheme (host is canonicalized by Uri)', () {
      expect(UrlValidator.normalize('  HTTPS://Host  '), 'https://host');
    });

    test('rejects missing scheme / host', () {
      expect(UrlValidator.normalize(null), isNull);
      expect(UrlValidator.normalize('bambuddy.local'), isNull);
      expect(UrlValidator.normalize('ftp://host'), isNull);
      expect(UrlValidator.normalize('not a url at all'), isNull);
    });

    test('rejects query and fragment', () {
      expect(UrlValidator.normalize('https://host?x=1'), isNull);
      expect(UrlValidator.normalize('https://host#frag'), isNull);
    });
  });

  test('isValid mirrors normalize', () {
    expect(UrlValidator.isValid('https://bambuddy.local'), isTrue);
    expect(UrlValidator.isValid('ftp://host'), isFalse);
  });
}
