import 'dart:convert';

/// Raised by [ApiClient] on a non-2xx response or network failure.
/// Ported from ApiException.java.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? responseBody;

  ApiException(this.message, this.statusCode, [this.responseBody]);

  /// True for a genuine authentication failure (HTTP 401) — the bearer token is
  /// missing, expired, or invalid. The UI should prompt for re-login.
  bool get isUnauthorized => statusCode == 401;

  /// True when the session is valid but lacks the required permission/scope
  /// (HTTP 403, e.g. `can_control_printer`). The session is still
  /// authenticated, so the UI should surface a permission error rather than
  /// wiping credentials and forcing re-login.
  bool get isForbidden => statusCode == 403;

  /// Best-effort extraction of a FastAPI "detail" message from the body.
  String detailMessage() {
    final detail = _detailRaw();
    if (detail == null) return message;
    if (detail is String) return detail;
    if (detail is Map<String, dynamic>) {
      final msg = detail['message'];
      if (msg is String && msg.isNotEmpty) return msg;
      final code = detail['code'];
      if (code is String && code.isNotEmpty) return code;
      return message;
    }
    return detail.toString();
  }

  /// Parsed "detail" field as a Map, or null. Used for assignment-conflict
  /// payloads (code, can_confirm, confirm_field).
  Map<String, dynamic>? detailObject() {
    final detail = _detailRaw();
    return detail is Map<String, dynamic> ? detail : null;
  }

  dynamic _detailRaw() {
    if (responseBody == null || responseBody!.isEmpty) return null;
    try {
      final obj = jsonDecode(responseBody!) as Map<String, dynamic>;
      return obj['detail'];
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
