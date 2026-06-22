import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../core/api_exception.dart';
import 'session_store.dart';

/// Result of a credentials [ApiClient.login].
class LoginResult {
  const LoginResult({this.accessToken, this.requires2fa = false});

  /// The bearer access token, or null when [requires2fa] is true / login failed.
  final String? accessToken;

  /// True when the account requires 2FA, which silent sign-in can't satisfy.
  final bool requires2fa;
}

enum _ReloginOutcome { success, failed, transient, notCredentialsMode }

/// Async HTTP client for the Bambuddy REST API. The base URL comes from
/// SessionStore. Production auth is a bearer token sent as
/// `Authorization: Bearer <token>`; when it expires (HTTP 401) the client
/// silently re-logs in with the stored credentials and retries the request once.
/// A definitive HTTP 401 (credentials that could not be refreshed) raises an
/// [ApiException] whose [ApiException.isUnauthorized] is true (→ reconfigure).
/// HTTP 403 (valid auth, insufficient permission/scope) sets
/// [ApiException.isForbidden] and must NOT wipe credentials.
class ApiClient {
  ApiClient(this.baseUrl, this._apiKey, this._client, {String? token})
    : _token = token;

  final String baseUrl;
  final String? _apiKey;
  String? _token;
  final http.Client _client;

  static const String _prefix = '/api/v1';

  static http.Client _defaultClient() {
    final inner = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    return IOClient(inner);
  }

  /// Builds a client from the baked base URL and the cached bearer token.
  /// (The API-key constructor parameter is retained only for tests; production
  /// auth is always the credentials bearer token.)
  static Future<ApiClient> create() async {
    final base = await SessionStore.getBaseUrl();
    if (base == null) {
      throw StateError('No Bambuddy base URL configured');
    }
    final token = await SessionStore.getAccessToken();
    return ApiClient(base, null, _defaultClient(), token: token);
  }

  /// Sign in with username/password (no auth header). Throws [ApiException] on
  /// HTTP/network errors. Returns a [LoginResult]; [LoginResult.requires2fa] is
  /// true for 2FA-protected accounts, which silent sign-in cannot complete.
  static Future<LoginResult> login(
    String baseUrl,
    String username,
    String password,
  ) async {
    final uri = Uri.parse('$baseUrl$_prefix/auth/login');
    final client = _defaultClient();
    try {
      final req = http.Request('POST', uri)
        ..followRedirects = false
        ..headers['Accept'] = 'application/json'
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode({'username': username, 'password': password});
      final streamed = await client
          .send(req)
          .timeout(const Duration(seconds: 12));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw ApiException(
          'HTTP ${resp.statusCode}',
          resp.statusCode,
          resp.body,
        );
      }
      final data = resp.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(resp.body) as Map<String, dynamic>;
      final requires2fa = data['requires_2fa'] == true;
      final token = data['access_token'] as String?;
      return LoginResult(
        accessToken: requires2fa ? null : token,
        requires2fa: requires2fa,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> get(String path) =>
      _request('GET', path).then(_asObject);

  Future<List<dynamic>> getArray(String path) =>
      _request('GET', path).then(_asArray);

  Future<List<dynamic>> getList(String path) =>
      _request('GET', path).then(_asArray);

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) => _request('POST', path, body).then(_asObject);

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _request('PATCH', path, body).then(_asObject);

  Future<Map<String, dynamic>> delete(String path) =>
      _request('DELETE', path).then(_asObject);

  Future<_Response> _request(
    String method,
    String path, [
    Map<String, dynamic>? body,
    bool isRetry = false,
  ]) async {
    final uri = Uri.parse('$baseUrl$_prefix$path');
    try {
      final req = http.Request(method, uri)
        ..followRedirects = false
        ..headers['Accept'] = 'application/json';
      _applyAuth(req);
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      final streamed = await _client
          .send(req)
          .timeout(const Duration(seconds: 12));
      final resp = await http.Response.fromStream(streamed);
      // Bearer token expired → silently refresh once and retry.
      if (resp.statusCode == 401 && !isRetry) {
        final outcome = await _tryRelogin();
        if (outcome == _ReloginOutcome.success) {
          return _request(method, path, body, true);
        }
        if (outcome == _ReloginOutcome.transient) {
          throw ApiException(
            'Session expired; could not refresh (offline).',
            0,
          );
        }
      }
      return _Response(resp.statusCode, resp.body);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e', 0);
    }
  }

  void _applyAuth(http.Request req) {
    if (_token != null) {
      req.headers['Authorization'] = 'Bearer $_token';
    } else if (_apiKey != null) {
      req.headers['X-API-Key'] = _apiKey;
    }
  }

  /// Silent re-login using the stored credentials. Skipped only for direct
  /// test/legacy clients constructed with an API-key parameter.
  Future<_ReloginOutcome> _tryRelogin() async {
    if (_token == null && _apiKey != null) {
      return _ReloginOutcome.notCredentialsMode;
    }
    String? user;
    String? pass;
    try {
      user = await SessionStore.getUsername();
      pass = await SessionStore.getPassword();
    } catch (_) {
      return _ReloginOutcome.notCredentialsMode;
    }
    if (user == null || pass == null) return _ReloginOutcome.notCredentialsMode;
    try {
      final res = await ApiClient.login(baseUrl, user, pass);
      if (res.requires2fa || res.accessToken == null) {
        return _ReloginOutcome.failed;
      }
      await SessionStore.setAccessToken(res.accessToken!);
      _token = res.accessToken;
      return _ReloginOutcome.success;
    } on ApiException catch (e) {
      return e.statusCode == 0
          ? _ReloginOutcome.transient
          : _ReloginOutcome.failed;
    } catch (_) {
      return _ReloginOutcome.transient;
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
