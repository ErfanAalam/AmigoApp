import 'package:flutter/material.dart';

/// App color theme definitions
class AppColors {
  /// Teal theme
  static const ColorTheme teal = ColorTheme(
    name: 'Teal',
    primary: Color(0xFF00897B), // Teal 600
    primaryLight: Color(0xFF4DB6AC), // Teal 300
    primaryDark: Color(0xFF00695C), // Teal 800
    accent: Color(0xFF00ACC1), // Cyan 600
  );

  /// Pink theme
  static const ColorTheme pink = ColorTheme(
    name: 'Pink',
    primary: Color(0xFFE91E63), // Pink 500
    primaryLight: Color(0xFFF48FB1), // Pink 300
    primaryDark: Color(0xFFC2185B), // Pink 700
    accent: Color(0xFFEC407A), // Pink 400
  );

  /// Purple theme
  static const ColorTheme purple = ColorTheme(
    name: 'Purple',
    primary: Color(0xFF9C27B0), // Purple 500
    primaryLight: Color(0xFFBA68C8), // Purple 300
    primaryDark: Color(0xFF7B1FA2), // Purple 700
    accent: Color(0xFFAB47BC), // Purple 400
  );

  /// Indigo theme
  static const ColorTheme indigo = ColorTheme(
    name: 'Indigo',
    primary: Color(0xFF3F51B5), // Indigo 500
    primaryLight: Color(0xFF7986CB), // Indigo 300
    primaryDark: Color(0xFF303F9F), // Indigo 700
    accent: Color(0xFF5C6BC0), // Indigo 400
  );

  /// Blue theme
  static const ColorTheme blue = ColorTheme(
    name: 'Blue',
    primary: Color(0xFF2196F3), // Blue 500
    primaryLight: Color(0xFF64B5F6), // Blue 300
    primaryDark: Color(0xFF1976D2), // Blue 700
    accent: Color(0xFF42A5F5), // Blue 400
  );

  /// Green theme
  static const ColorTheme green = ColorTheme(
    name: 'Green',
    primary: Color(0xFF4CAF50), // Green 500
    primaryLight: Color(0xFF81C784), // Green 300
    primaryDark: Color(0xFF388E3C), // Green 700
    accent: Color(0xFF66BB6A), // Green 400
  );

  /// Orange theme
  static const ColorTheme orange = ColorTheme(
    name: 'Orange',
    primary: Color(0xFFFF9800), // Orange 500
    primaryLight: Color(0xFFFFB74D), // Orange 300
    primaryDark: Color(0xFFF57C00), // Orange 700
    accent: Color(0xFFFFA726), // Orange 400
  );

  /// Red theme
  static const ColorTheme red = ColorTheme(
    name: 'Red',
    primary: Color(0xFFF44336), // Red 500
    primaryLight: Color(0xFFE57373), // Red 300
    primaryDark: Color(0xFFD32F2F), // Red 700
    accent: Color(0xFFEF5350), // Red 400
  );

  /// Amber theme
  static const ColorTheme amber = ColorTheme(
    name: 'Amber',
    primary: Color(0xFFFFC107), // Amber 500
    primaryLight: Color(0xFFFFD54F), // Amber 300
    primaryDark: Color(0xFFFFA000), // Amber 700
    accent: Color(0xFFFFCA28), // Amber 400
  );

  /// Cyan theme
  static const ColorTheme cyan = ColorTheme(
    name: 'Cyan',
    primary: Color(0xFF00BCD4), // Cyan 500
    primaryLight: Color(0xFF4DD0E1), // Cyan 300
    primaryDark: Color(0xFF0097A7), // Cyan 700
    accent: Color(0xFF26C6DA), // Cyan 400
  );

  /// Deep Purple theme
  static const ColorTheme deepPurple = ColorTheme(
    name: 'Deep Purple',
    primary: Color(0xFF673AB7), // Deep Purple 500
    primaryLight: Color(0xFF9575CD), // Deep Purple 300
    primaryDark: Color(0xFF512DA8), // Deep Purple 700
    accent: Color(0xFF7E57C2), // Deep Purple 400
  );

  /// Dark Black theme
  static const ColorTheme darkBlack = ColorTheme(
    name: 'Dark Black',
    primary: Color(0xFF000000), // Dark Black 500
    primaryLight: Color(0xFF333333), // Dark Black 300
    primaryDark: Color(0xFF000000), // Dark Black 700
    accent: Color(0xFF111111), // Dark Black 400
  );

  /// All available color themes
  static const List<ColorTheme> allThemes = [
    teal,
    pink,
    purple,
    indigo,
    blue,
    green,
    orange,
    red,
    amber,
    cyan,
    deepPurple,
    darkBlack,
  ];

  /// Get theme by name
  static ColorTheme? getThemeByName(String name) {
    try {
      return allThemes.firstWhere(
        (theme) => theme.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  } 

  /// Default theme (Teal)
  static const ColorTheme defaultTheme = indigo;
}

/// Color theme data class
class ColorTheme {
  final String name;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color accent;

  const ColorTheme({
    required this.name,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primary': primary.value,
      'primaryLight': primaryLight.value,
      'primaryDark': primaryDark.value,
      'accent': accent.value,
    };
  }

  /// Create from JSON
  factory ColorTheme.fromJson(Map<String, dynamic> json) {
    return ColorTheme(
      name: json['name'] as String,
      primary: Color(json['primary'] as int),
      primaryLight: Color(json['primaryLight'] as int),
      primaryDark: Color(json['primaryDark'] as int),
      accent: Color(json['accent'] as int),
    );
  }
}
