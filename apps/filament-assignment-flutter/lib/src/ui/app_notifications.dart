import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';

enum AppNotificationKind { success, failure, warning, help }

SnackBar buildAppNotificationSnackBar({
  required AppNotificationKind kind,
  required String title,
  required String message,
  Duration duration = const Duration(seconds: 4),
}) {
  return SnackBar(
    elevation: 0,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    duration: duration,
    content: AwesomeSnackbarContent(
      title: title,
      message: message,
      contentType: _contentTypeFor(kind),
    ),
  );
}

void showAppNotification(
  BuildContext context, {
  required AppNotificationKind kind,
  required String title,
  required String message,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      buildAppNotificationSnackBar(kind: kind, title: title, message: message),
    );
}

ContentType _contentTypeFor(AppNotificationKind kind) {
  switch (kind) {
    case AppNotificationKind.success:
      return ContentType.success;
    case AppNotificationKind.failure:
      return ContentType.failure;
    case AppNotificationKind.warning:
      return ContentType.warning;
    case AppNotificationKind.help:
      return ContentType.help;
  }
}
