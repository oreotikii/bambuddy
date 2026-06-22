import 'package:assignfilament/src/app/app_model.dart';
import 'package:assignfilament/src/app/theme.dart';
import 'package:assignfilament/src/ui/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('login screen uses the CRAV3D credential surface', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppModel(),
        child: MaterialApp(theme: bambuddyTheme, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('CRAV3D logo'), findsOneWidget);
    expect(find.text('CRAV3D'), findsNothing);
    expect(find.text('Bambuddy Assign'), findsOneWidget);
    expect(find.text('Internal connection'), findsOneWidget);
    expect(find.text('Stored on device'), findsOneWidget);
    expect(find.text('Sign in'), findsNWidgets(2));
    expect(find.text('Use your Bambuddy account to continue.'), findsOneWidget);
  });

  testWidgets('login fields expose labels and focused glow styling', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppModel(),
        child: MaterialApp(theme: bambuddyTheme, home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Server URL'), findsNothing);
    expect(find.text('API key'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('login-user-field')));
    await tester.pumpAndSettle();

    final focusedField = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('login-user-field-shell')),
    );
    final decoration = focusedField.decoration! as BoxDecoration;
    expect(decoration.border!.top.color, const Color(0xFF00C853));
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow!.first.color, const Color(0x5200C853));
  });
}
