// Stub used on non-web platforms to satisfy conditional imports.
Future<bool> requestPermission() async => false;

Future<void> showNotification(String title, String body, String? payload) async {}

Future<void> showInAppBanner(String title, String body, {int durationMs = 4000}) async {}