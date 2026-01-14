import 'package:shared_preferences/shared_preferences.dart';

class SosAlertCache {
  static const _kPrefix = 'dismissed_sos_alert_';

  Future<bool> isDismissed(String alertId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kPrefix$alertId') ?? false;
  }

  Future<void> dismiss(String alertId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kPrefix$alertId', true);
  }
}
