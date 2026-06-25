import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../core/url_validator.dart';

typedef BaseUrlProbe = Future<bool> Function(String baseUrl, Duration timeout);

class BaseUrlResolver {
  BaseUrlResolver({
    required this.externalBaseUrl,
    this.internalBaseUrl,
    BaseUrlProbe? probe,
    this.probeTimeout = const Duration(milliseconds: 750),
  }) : _probe = probe ?? probeBambuddyBaseUrl;

  static const probePath = '/api/v1/auth/login';

  final String externalBaseUrl;
  final String? internalBaseUrl;
  final Duration probeTimeout;
  final BaseUrlProbe _probe;

  Future<String?> resolve() async {
    final external = UrlValidator.normalize(externalBaseUrl);
    if (external == null) return null;

    final internal = UrlValidator.normalize(internalBaseUrl);
    if (internal == null || internal == external) return external;

    final useInternal = await _probe(internal, probeTimeout);
    return useInternal ? internal : external;
  }
}

Future<bool> probeBambuddyBaseUrl(String baseUrl, Duration timeout) async {
  final client = IOClient(HttpClient()..connectionTimeout = timeout);
  try {
    final uri = Uri.parse('$baseUrl${BaseUrlResolver.probePath}');
    final request = http.Request('HEAD', uri)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json';
    final response = await client.send(request).timeout(timeout);
    await response.stream.drain<void>().timeout(timeout);
    return true;
  } catch (_) {
    return false;
  } finally {
    client.close();
  }
}
