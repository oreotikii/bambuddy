import 'package:flutter/widgets.dart';

import '../data/session_store.dart';

/// Which screen the app should show. Computed from [configured] + [locked],
/// mirroring the original activity flow: setup → pin → home.
enum AppGate { splash, setup, pin, main }

/// Reactive app state: configuration status + the 4-digit PIN app-lock.
///
/// The lock re-arms when the app is backgrounded (AppLifecycleState.paused),
/// matching AppLock + ProcessLifecycleOwner in the original Java app.
class AppModel extends ChangeNotifier with WidgetsBindingObserver {
  bool _initialized = false;
  bool _configured = false;
  bool _locked = true;

  bool get initialized => _initialized;
  bool get configured => _configured;
  bool get locked => _locked;

  AppGate get gate {
    if (!_initialized) return AppGate.splash;
    if (!_configured) return AppGate.setup;
    if (_locked) return AppGate.pin;
    return AppGate.main;
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _configured = await SessionStore.isConfigured();
    _initialized = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App moved fully to background → require the PIN on next entry.
    if (state == AppLifecycleState.paused && _configured && !_locked) {
      _locked = true;
      notifyListeners();
    }
  }

  /// Called after a successful setup/connect — require the PIN gate next.
  Future<void> completeSetup() async {
    _configured = await SessionStore.isConfigured();
    _locked = true;
    notifyListeners();
  }

  void unlock() {
    _locked = false;
    notifyListeners();
  }

  /// Re-arm the PIN gate immediately (the in-app "Lock" button).
  void lockNow() {
    _locked = true;
    notifyListeners();
  }

  /// Clears user-entered base URL + API key (baked values are untouched) and
  /// returns the user to setup.
  Future<void> logoutToSetup() async {
    await SessionStore.clearCredentials();
    await SessionStore.clearBaseUrl();
    _configured = false;
    _locked = true;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
