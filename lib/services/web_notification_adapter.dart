import 'dart:html' as html;

/// Web-only notification adapter using the browser Notification API.
/// No-ops if the API is unsupported or permissions are denied.
Future<bool> requestPermission() async {
  if (!html.Notification.supported) return false;
  final current = html.Notification.permission; // 'default' | 'granted' | 'denied'
  if (current == 'granted') return true;
  final result = await html.Notification.requestPermission();
  return result == 'granted';
}

Future<void> showNotification(String title, String body, String? payload) async {
  if (!html.Notification.supported) return;

  if (html.Notification.permission != 'granted') {
    final granted = await requestPermission();
    if (!granted) return;
  }

  // Use a generic PWA icon if available; safe to omit if missing.
  final iconPath = '/icons/Icon-192.png';

  final notification = html.Notification(
    title,
    body: body,
    icon: iconPath,
    tag: payload ?? 'general',
  );
  // Optionally handle clicks by opening a relevant URL if needed.
}

/// Lightweight in-app banner/toast for web as a fallback to browser popups.
/// Creates a DOM element overlay that auto-fades after a short duration.
Future<void> showInAppBanner(String title, String body, {int durationMs = 4000}) async {
  try {
    final doc = html.document;
    final containerId = 'soc-banner-container';
    html.Element? container = doc.getElementById(containerId);
    if (container == null) {
      container = html.DivElement()
        ..id = containerId
        ..style.position = 'fixed'
        ..style.right = '16px'
        ..style.bottom = '16px'
        ..style.zIndex = '9999'
        ..style.display = 'flex'
        ..style.flexDirection = 'column'
        ..style.gap = '8px';
      doc.body?.append(container);
    }

    final banner = html.DivElement()
      ..style.backgroundColor = 'rgba(20,20,20,0.92)'
      ..style.color = '#fff'
      ..style.padding = '12px 16px'
      ..style.borderRadius = '8px'
      ..style.boxShadow = '0 6px 16px rgba(0,0,0,0.25)'
      ..style.fontFamily = 'system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, Helvetica Neue, Arial, sans-serif'
      ..style.maxWidth = '360px'
      ..style.transition = 'opacity 280ms ease-out'
      ..style.opacity = '1';

    final titleEl = html.DivElement()
      ..text = title
      ..style.fontWeight = '600'
      ..style.fontSize = '14px'
      ..style.marginBottom = '4px';

    final bodyEl = html.DivElement()
      ..text = body
      ..style.fontSize = '13px'
      ..style.opacity = '0.92';

    banner.append(titleEl);
    banner.append(bodyEl);

    container.append(banner);

    // Auto-fade and remove
    Future.delayed(Duration(milliseconds: durationMs - 280), () {
      banner.style.opacity = '0';
      Future.delayed(const Duration(milliseconds: 280), () {
        banner.remove();
      });
    });
  } catch (_) {
    // Silent fallback; avoid throwing in web builds
  }
}