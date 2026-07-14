import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_color_scheme.dart';
import '../utils/app_theme.dart';

class AppThemeNotifier extends ChangeNotifier {
  static final AppThemeNotifier instance = AppThemeNotifier._();
  AppThemeNotifier._();

  static const _prefsKey = 'app_theme_id';

  AppColorScheme _current = AppThemes.yellow;
  AppColorScheme get current => _current;

  /// Call once at startup (before runApp) to restore the saved theme.
  Future<void> loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefsKey);
      if (id != null) {
        _current = AppThemes.fromId(id);
        AppColors.applyScheme(_current);
      }
    } catch (_) {}
  }

  Future<void> setTheme(AppColorScheme scheme) async {
    if (_current.id == scheme.id) return;
    _current = scheme;
    AppColors.applyScheme(scheme);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, scheme.id);
    } catch (_) {}
  }
}
