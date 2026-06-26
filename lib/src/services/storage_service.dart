import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class StorageService {
  static const _settingsKey = 'videoframex.settings';
  static const _historyKey = 'videoframex.history';

  Future<UserSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_settingsKey);
    if (value == null) return const UserSettings();
    try {
      return UserSettings.fromJson(jsonDecode(value) as Map<String, Object?>);
    } catch (_) {
      return const UserSettings();
    }
  }

  Future<void> saveSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<List<HistoryEntry>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_historyKey);
    if (value == null) return [];
    try {
      final rows = jsonDecode(value) as List<dynamic>;
      return rows
          .map((row) => HistoryEntry.fromJson(row as Map<String, Object?>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<HistoryEntry> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(history.map((entry) => entry.toJson()).toList()),
    );
  }
}
