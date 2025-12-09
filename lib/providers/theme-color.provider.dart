import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app-colors.config.dart';

/// Provider for theme color state
final themeColorProvider = NotifierProvider<ThemeColorNotifier, ColorTheme>(() {
  return ThemeColorNotifier();
});

class ThemeColorNotifier extends Notifier<ColorTheme> {
  static const String _prefsKey = 'selected_app_color_theme';

  @override
  ColorTheme build() {
    // Load saved theme asynchronously
    Future.microtask(() => _loadSavedTheme());
    // Return default theme initially
    return AppColors.defaultTheme;
  }

  /// Load saved theme from SharedPreferences
  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_prefsKey);

      if (themeName != null) {
        final theme = AppColors.getThemeByName(themeName);
        if (theme != null) {
          state = theme;
        }
      }
    } catch (e) {
      // If loading fails, keep default theme
      debugPrint('Error loading saved theme: $e');
    }
  }

  /// Set and save theme color
  Future<void> setTheme(ColorTheme theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, theme.name);
      state = theme;
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }

  /// Get current theme
  ColorTheme get currentTheme => state;
}
