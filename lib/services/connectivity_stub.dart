// Non-web stub — navigator.onLine is checked via API health ping only.
bool getPlatformNavigatorOnline() => true;

void attachPlatformConnectivityListeners(void Function(bool isOnline) onChanged) {}
