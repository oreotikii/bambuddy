import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import 'base_url_resolver.dart';

/// Stores the app's local session for credentials (B+) sign-in: the signed-in
/// user's username + password, and a cached short-lived bearer access token.
///
/// The password is stored (in flutter_secure_storage — Android Keystore / iOS
/// Keychain) so [ApiClient] can silently re-login when the 24h, non-refreshable
/// token expires. That is the trade-off for "sign in once". The base URL is
/// baked into the build (see [AppConfig]); it is not stored here.
class SessionStore {
  SessionStore._();

  static const _kUsername = 'username';
  static const _kPassword = 'password';
  static const _kAccessToken = 'access_token';

  static final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ---- base URL (baked) ----

  static Future<String?> getBaseUrl() async {
    return BaseUrlResolver(
      externalBaseUrl: AppConfig.bakedBaseUrl,
      internalBaseUrl: AppConfig.bakedInternalBaseUrl,
    ).resolve();
  }

  // ---- credentials ----

  static Future<String?> getUsername() async {
    final v = await _storage.read(key: _kUsername);
    return (v == null || v.isEmpty) ? null : v;
  }

  static Future<void> setUsername(String username) =>
      _storage.write(key: _kUsername, value: username);

  static Future<String?> getPassword() async {
    final v = await _storage.read(key: _kPassword);
    return (v == null || v.isEmpty) ? null : v;
  }

  static Future<void> setPassword(String password) =>
      _storage.write(key: _kPassword, value: password);

  static Future<String?> getAccessToken() async {
    final v = await _storage.read(key: _kAccessToken);
    return (v == null || v.isEmpty) ? null : v;
  }

  static Future<void> setAccessToken(String token) =>
      _storage.write(key: _kAccessToken, value: token);

  static Future<bool> hasCredentials() async =>
      (await getUsername()) != null && (await getPassword()) != null;

  /// Clears the stored username, password, and access token (a sign-out).
  static Future<void> clearCredentials() async {
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kPassword);
    await _storage.delete(key: _kAccessToken);
  }

  /// True when the user has signed in (username + password stored).
  static Future<bool> isConfigured() async => hasCredentials();
}
