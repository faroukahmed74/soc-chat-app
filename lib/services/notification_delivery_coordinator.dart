import 'package:shared_preferences/shared_preferences.dart';

class NotificationDeliveryCoordinator {
  static const _prefKey = 'notification_background_authority';
  static bool _backgroundAuthority = false;
  static bool _initialized = false;

  static Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _backgroundAuthority = prefs.getBool(_prefKey) ?? false;
    _initialized = true;
  }

  static Future<void> setBackgroundAuthority(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    _backgroundAuthority = enabled;
    await prefs.setBool(_prefKey, enabled);
  }

  static Future<bool> isBackgroundAuthorityActive() async {
    await _ensureInitialized();
    return _backgroundAuthority;
  }

  static bool get cachedBackgroundAuthority => _backgroundAuthority;
}

