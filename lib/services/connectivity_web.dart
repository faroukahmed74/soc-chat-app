// Web connectivity hooks (dart:html).
import 'dart:html' as html;

bool getPlatformNavigatorOnline() {
  return html.window.navigator.onLine ?? true;
}

void attachPlatformConnectivityListeners(void Function(bool isOnline) onChanged) {
  html.window.onOnline.listen((_) => onChanged(true));
  html.window.onOffline.listen((_) => onChanged(false));
}
