import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _notificationsKey = 'notifications_enabled';

  bool _notificationsEnabled = true;

  bool get notificationsEnabled => _notificationsEnabled;

  SettingsService() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
      notifyListeners();
    } catch (e) {
      _notificationsEnabled = true;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      _notificationsEnabled = enabled;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_notificationsKey, enabled);
    } catch (e) {
      // ignore persistence errors
    }
  }

  void toggleNotifications() {
    setNotificationsEnabled(!notificationsEnabled);
  }
}
