import 'dart:convert';

import 'package:jpg_slimming/models/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 設定儲存服務
class SettingsService {
  static const _key = 'app_settings';

  /// 讀取設定
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  /// 儲存設定
  static Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}
