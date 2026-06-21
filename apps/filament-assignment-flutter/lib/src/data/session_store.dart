import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import '../core/url_validator.dart';

/// Stores the app's local session: the saved Bambuddy base URL, the API key
/// used to authenticate all REST calls, and a 4-digit PIN that locally locks
/// the app. The PIN is stored as a salted SHA-256 hash so the raw digits never
/// touch disk. A build may instead bake the PIN in (AppConfig), in which case
/// every install shares the same PIN and first-run setup is skipped.
///
/// Ported from SessionStore.java + ServerStore.java. Secrets live in
/// flutter_secure_storage (Android Keystore) instead of plain SharedPreferences.
class SessionStore {
  SessionStore._();

  static const _kApiKey = 'api_key';
  static const _kBaseUrl = 'base_url';
  static const _kPinHash = 'pin_hash';
  static const _kPinSalt = 'pin_salt';

  static final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ---- base URL ----

  static Future<String?> getBaseUrl() async {
    if (AppConfig.isBaseUrlBaked) return AppConfig.bakedBaseUrl;
    final url = await _storage.read(key: _kBaseUrl);
    if (url == null || url.isEmpty) return null;
    return UrlValidator.isValid(url) ? url : null;
  }

  static Future<void> setBaseUrl(String url) =>
      _storage.write(key: _kBaseUrl, value: url);

  static Future<void> clearBaseUrl() => _storage.delete(key: _kBaseUrl);

  static Future<bool> isBaseUrlBaked() async => AppConfig.isBaseUrlBaked;

  // ---- API key ----

  static Future<String?> getApiKey() async {
    if (AppConfig.isKeyBaked) return AppConfig.bakedApiKey;
    final key = await _storage.read(key: _kApiKey);
    return (key == null || key.isEmpty) ? null : key;
  }

  static Future<void> setApiKey(String apiKey) =>
      _storage.write(key: _kApiKey, value: apiKey);

  static Future<void> clearCredentials() => _storage.delete(key: _kApiKey);

  // ---- PIN ----

  static Future<bool> isPinSet() async {
    if (AppConfig.isPinBaked) return true;
    final hash = await _storage.read(key: _kPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Store a 4-digit PIN (hashed). No-op when a PIN is baked into the build.
  static Future<void> setPin(String pin) async {
    if (AppConfig.isPinBaked) return;
    var salt = await _storage.read(key: _kPinSalt);
    if (salt == null || salt.isEmpty) {
      salt = _newSalt();
      await _storage.write(key: _kPinSalt, value: salt);
    }
    await _storage.write(key: _kPinHash, value: _hashPin(salt, pin));
  }

  static Future<bool> checkPin(String pin) async {
    if (AppConfig.isPinBaked) return _constTimeEquals(AppConfig.bakedPin, pin);
    final stored = await _storage.read(key: _kPinHash);
    final salt = await _storage.read(key: _kPinSalt);
    if (stored == null || salt == null) return false;
    return _constTimeEquals(stored, _hashPin(salt, pin));
  }

  /// Clears the per-device hash; a baked PIN is unaffected.
  static Future<void> clearPin() async {
    await _storage.delete(key: _kPinHash);
    await _storage.delete(key: _kPinSalt);
  }

  // ---- lifecycle ----

  /// True when a base URL and API key are both configured.
  static Future<bool> isConfigured() async =>
      (await getBaseUrl()) != null && (await getApiKey()) != null;

  static String _hashPin(String salt, String pin) {
    final digest = sha256.convert(utf8.encode('$salt:$pin'));
    return digest.toString();
  }

  static bool _constTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  static String _newSalt() {
    final rng = Random.secure();
    final a = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final b = rng.nextInt(0x7fffffff).toRadixString(16);
    return '$a$b';
  }
}
