import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/session_store.dart';

/// Which screen the app should show, computed from the sign-in + lock state:
/// splash → login → (biometric) locked → main.
enum AppGate { splash, login, locked, main }

/// Reactive app state: whether the user is signed in, plus a biometric
/// app-lock.
///
/// The lock re-arms when the app is backgrounded (AppLifecycleState.paused —
/// "minimised") OR after [_idleTimeout] (10 min) of inactivity. Resuming then
/// shows the biometric [LockScreen]. User activity is reported via
/// [pingActivity] from a top-level input listener. Auth itself is credentials
/// sign-in (no PIN, no API key); the bearer token is refreshed transparently
/// by [ApiClient] when it expires.
class AppModel extends ChangeNotifier with WidgetsBindingObserver {
  static const Duration _idleTimeout = Duration(minutes: 10);

  bool _initialized = false;
  bool _signedIn = false;
  bool _locked = true;
  Timer? _idleTimer;

  bool get signedIn => _signedIn;
  bool get locked => _locked;

  AppGate get gate {
    if (!_initialized) return AppGate.splash;
    if (!_signedIn) return AppGate.login;
    if (_locked) return AppGate.locked;
    return AppGate.main;
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _signedIn = await SessionStore.isConfigured();
    _initialized = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounded → require biometric unlock on next entry.
    if (state == AppLifecycleState.paused && _signedIn && !_locked) {
      _idleTimer?.cancel();
      _locked = true;
      notifyListeners();
    } else if (state == AppLifecycleState.resumed && _signedIn && !_locked) {
      _startIdleTimer();
    }
  }

  /// Called after a successful sign-in — go straight to the app (the user just
  /// authenticated with their password, so no biometric gate is needed).
  Future<void> completeLogin() async {
    _idleTimer?.cancel();
    _signedIn = await SessionStore.isConfigured();
    _locked = false;
    _startIdleTimer();
    notifyListeners();
  }

  /// Biometric unlock succeeded — dismiss the lock gate.
  void unlock() {
    _locked = false;
    _startIdleTimer();
    notifyListeners();
  }

  /// Report user activity; resets the inactivity auto-lock window.
  void pingActivity() {
    if (_signedIn && !_locked) _startIdleTimer();
  }

  void _startIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, () {
      if (_signedIn && !_locked) {
        _locked = true;
        notifyListeners();
      }
    });
  }

  /// Sign out — clear stored credentials and return to the login screen.
  Future<void> signOut() async {
    _idleTimer?.cancel();
    await SessionStore.clearCredentials();
    _signedIn = false;
    _locked = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
