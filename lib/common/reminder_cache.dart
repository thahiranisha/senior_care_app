import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ReminderCache {
  static const _key = 'cached_reminders_v1';

  // in-memory "hash table"
  final Map<String, Map<String, dynamic>> _map = {};
  // key example: "$seniorId|$medId|$time"

  Map<String, Map<String, dynamic>> get all => _map;

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _map.clear();
    decoded.forEach((k, v) => _map[k] = Map<String, dynamic>.from(v as Map));
  }

  Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(_map));
  }

  void setAll(Map<String, Map<String, dynamic>> next) {
    _map
      ..clear()
      ..addAll(next);
  }

  void clear() => _map.clear();
}
