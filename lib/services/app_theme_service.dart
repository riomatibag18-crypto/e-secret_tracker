import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeService extends ChangeNotifier {
  AppThemeService._();

  static final AppThemeService instance = AppThemeService._();

  static const _themePreferenceKey = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themePreferenceKey);
    if (raw == 'light') {
      _themeMode = ThemeMode.light;
    } else if (raw == 'dark') {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    _themeMode = enabled ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePreferenceKey, enabled ? 'dark' : 'light');
  }
}
