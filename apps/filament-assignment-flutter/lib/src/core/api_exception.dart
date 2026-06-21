import 'dart:convert';

/// Raised by [ApiClient] on a non-2xx response or network failure.
/// [isUnauthorized] is true for HTTP 401/403, which the UI uses to bounce the
/// user back to setup (bad API key). Ported from ApiException.java.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? responseBody;

  ApiException(this.message, this.statusCode, [this.responseBody]);

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

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
