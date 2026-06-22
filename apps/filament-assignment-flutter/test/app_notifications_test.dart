import 'package:assignfilament/src/app/theme.dart';
import 'package:assignfilament/src/ui/app_notifications.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('showAppNotification renders awesome snackbar content', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: bambuddyTheme,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAppNotification(
                    context,
                    kind: AppNotificationKind.success,
                    title: 'Assigned',
                    message: 'Spool #42 assigned to A2',
                  ),
                  child: const Text('Notify'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Notify'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.transparent);
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(snackBar.elevation, 0);

    final content = tester.widget<AwesomeSnackbarContent>(
      find.byType(AwesomeSnackbarContent),
    );
    expect(content.title, 'Assigned');
    expect(content.message, 'Spool #42 assigned to A2');
    expect(content.contentType, ContentType.success);
  });
}
