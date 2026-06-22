import 'package:assignfilament/src/app/app_model.dart';
import 'package:assignfilament/src/app/theme.dart';
import 'package:assignfilament/src/ui/lock_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:provider/provider.dart';

void main() {
  late LocalAuthPlatform originalLocalAuthPlatform;

  setUp(() {
    originalLocalAuthPlatform = LocalAuthPlatform.instance;
  });

  tearDown(() {
    LocalAuthPlatform.instance = originalLocalAuthPlatform;
  });

  testWidgets('lock screen uses the CRAV3D biometric surface', (tester) async {
    _mockLocalAuth(supported: false);
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppModel(),
        child: MaterialApp(theme: bambuddyTheme, home: const LockScreen()),
      ),
    );
    await _pumpLockScreenReady(tester);

    expect(find.bySemanticsLabel('CRAV3D logo'), findsOneWidget);
    expect(find.text('CRAV3D'), findsNothing);
    expect(find.text('App locked'), findsOneWidget);
    expect(find.text('Verify with device security'), findsOneWidget);
    expect(find.text('Unlock with device security'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byKey(const ValueKey('lock-device-orb')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(
      find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('pin_digit_box_');
      }),
      findsNothing,
    );
  });

  testWidgets('reports unavailable device auth without crashing', (
    tester,
  ) async {
    _mockLocalAuth(supported: false);
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppModel(),
        child: MaterialApp(theme: bambuddyTheme, home: const LockScreen()),
      ),
    );
    await _pumpLockScreenReady(tester);

    expect(
      find.text('Device unlock is not available on this device.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('successful device auth unlocks the app model', (tester) async {
    _mockLocalAuth(supported: true, authenticated: true);
    FlutterSecureStorage.setMockInitialValues({});
    final model = _UnlockTrackingAppModel();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppModel>.value(
        value: model,
        child: MaterialApp(theme: bambuddyTheme, home: const LockScreen()),
      ),
    );
    await _pumpLockScreenReady(tester);
    await _pumpUntilUnlocked(tester, model);
    if (!model.unlocked) {
      await tester.tap(find.byKey(const ValueKey('lock-unlock-button')));
      await _pumpUntilUnlocked(tester, model);
    }

    expect(model.unlocked, isTrue);
  });

  testWidgets('keeps the lock gate proportions compact', (tester) async {
    _mockLocalAuth(supported: false);
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppModel(),
        child: MaterialApp(theme: bambuddyTheme, home: const LockScreen()),
      ),
    );
    await _pumpLockScreenReady(tester);

    final logoSize = tester.getSize(find.bySemanticsLabel('CRAV3D logo'));
    final prompt = tester.widget<Text>(
      find.text('Verify with device security'),
    );
    final orbSize = tester.getSize(
      find.byKey(const ValueKey('lock-device-orb')),
    );

    expect(logoSize.width, lessThanOrEqualTo(220));
    expect(prompt.style?.fontSize, 22);
    expect(orbSize.width, 104);
  });

  testWidgets('handles transient narrow layout constraints without crashing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(40, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _mockLocalAuth(supported: false);
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppModel(),
        child: MaterialApp(theme: bambuddyTheme, home: const LockScreen()),
      ),
    );
    await _pumpLockScreenReady(tester);

    expect(tester.takeException(), isNull);
  });
}

void _mockLocalAuth({required bool supported, bool authenticated = false}) {
  LocalAuthPlatform.instance = _FakeLocalAuthPlatform(
    supported: supported,
    authenticated: authenticated,
  );
}

Future<void> _pumpLockScreenReady(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('Unlock with device security').evaluate().isNotEmpty ||
        find.text('Waiting for device unlock').evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _pumpUntilUnlocked(
  WidgetTester tester,
  _UnlockTrackingAppModel model,
) async {
  for (var i = 0; i < 10 && !model.unlocked; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _UnlockTrackingAppModel extends AppModel {
  bool unlocked = false;

  @override
  void unlock() {
    unlocked = true;
    notifyListeners();
  }
}

class _FakeLocalAuthPlatform extends LocalAuthPlatform {
  _FakeLocalAuthPlatform({
    required this.supported,
    required this.authenticated,
  });

  final bool supported;
  final bool authenticated;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async => authenticated;

  @override
  Future<bool> deviceSupportsBiometrics() async => supported;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => supported
      ? <BiometricType>[BiometricType.fingerprint]
      : <BiometricType>[];

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> stopAuthentication() async => true;
}
