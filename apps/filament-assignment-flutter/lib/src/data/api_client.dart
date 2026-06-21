import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../core/api_exception.dart';
import 'session_store.dart';

/// Async HTTP client for the Bambuddy REST API. The base URL comes from
/// SessionStore; the stored API key is attached as X-API-Key on every request.
/// HTTP 401/403 raise an ApiException whose [ApiException.isUnauthorized] is
/// true. Ported from ApiClient.java.
class ApiClient {
  ApiClient._(this.baseUrl, this.apiKey, this._client);

  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  static const String _prefix = '/api/v1';

  /// Builds a client from the currently-configured base URL + API key.
  static Future<ApiClient> create() async {
    final base = await SessionStore.getBaseUrl();
    final key = await SessionStore.getApiKey();
    if (base == null) {
      throw StateError('No Bambuddy base URL configured');
    }
    if (key == null) {
      throw StateError('No API key configured');
    }
    final inner = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    return ApiClient._(base, key, IOClient(inner));
  }

  Future<Map<String, dynamic>> get(String path) =>
      _request('GET', path).then(_asObject);

  Future<List<dynamic>> getArray(String path) =>
      _request('GET', path).then(_asArray);

  Future<List<dynamic>> getList(String path) =>
      _request('GET', path).then(_asArray);

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body).then(_asObject);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body).then(_asObject);

  Future<_Response> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final uri = Uri.parse('$baseUrl$_prefix$path');
    try {
      final req = http.Request(method, uri);
      req.headers['X-API-Key'] = apiKey;
      req.headers['Accept'] = 'application/json';
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      final streamed = await _client.send(req).timeout(
            const Duration(seconds: 12),
          );
      final resp = await http.Response.fromStream(streamed);
      return _Response(resp.statusCode, resp.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  void close() => _client.close();

  /// Append a URL-encoded query parameter to a path.
  static String withQuery(String path, String key, String value) {
    final sep = path.contains('?') ? '&' : '?';
    return '$path$sep$key=${Uri.encodeQueryComponent(value)}';
  }

  Map<String, dynamic> _asObject(_Response r) {
    r._ensureOk();
    if (r.body.isEmpty) return {};
    try {
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Invalid JSON response', r.statusCode, r.body);
    }
  }

  List<dynamic> _asArray(_Response r) {
    r._ensureOk();
    if (r.body.isEmpty) return [];
    try {
      return jsonDecode(r.body) as List<dynamic>;
    } catch (_) {
      throw ApiException('Invalid JSON response', r.statusCode, r.body);
    }
  }
}

class _Response {
  _Response(this.statusCode, this.body);

  final int statusCode;
  final String body;

  void _ensureOk() {
    if (statusCode == 401 || statusCode == 403) {
      throw ApiException('Unauthorized', statusCode, body);
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw ApiException('HTTP $statusCode', statusCode, body);
    }
  }
}
