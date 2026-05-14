import 'package:flutter/material.dart';

/// App color theme definitions
class AppColors {
  /// Teal theme
  static const ColorTheme teal = ColorTheme(
    name: 'Teal',
    primary: Color(0xFF00897B), // Teal 600
    primaryLight: Color(0xFF4DB6AC), // Teal 300
    primaryExtraLight: Color(0xFFB2DFDB), // Teal 100
    primaryPlusLight: Color(0xFFC9E8E6), // Teal — between 50 and 100
    primaryUltraLight: Color(0xFFE0F2F1), // Teal 50
    primaryDark: Color(0xFF00695C), // Teal 800
    accent: Color(0xFF00ACC1), // Cyan 600
  );

  /// Pink theme
  static const ColorTheme pink = ColorTheme(
    name: 'Pink',
    primary: Color(0xFFE91E63), // Pink 500
    primaryLight: Color(0xFFF48FB1), // Pink 300
    primaryExtraLight: Color(0xFFF8BBD0), // Pink 100
    primaryPlusLight: Color(0xFFFACFDE), // Pink — between 50 and 100
    primaryUltraLight: Color(0xFFFCE4EC), // Pink 50
    primaryDark: Color(0xFFC2185B), // Pink 700
    accent: Color(0xFFEC407A), // Pink 400
  );

  /// Purple theme
  static const ColorTheme purple = ColorTheme(
    name: 'Purple',
    primary: Color(0xFF9C27B0), // Purple 500
    primaryLight: Color(0xFFBA68C8), // Purple 300
    primaryExtraLight: Color(0xFFE1BEE7), // Purple 100
    primaryPlusLight: Color(0xFFEAD1EE), // Purple — between 50 and 100
    primaryUltraLight: Color(0xFFF3E5F5), // Purple 50
    primaryDark: Color(0xFF7B1FA2), // Purple 700
    accent: Color(0xFFAB47BC), // Purple 400
  );

  /// Indigo theme
  static const ColorTheme indigo = ColorTheme(
    name: 'Indigo',
    primary: Color(0xFF3F51B5), // Indigo 500
    primaryLight: Color(0xFF7986CB), // Indigo 300
    primaryExtraLight: Color(0xFFc1cdf7), // Indigo 100
    primaryPlusLight: Color(0xFFD4DBF7), // Indigo — between 50 and 100
    primaryUltraLight: Color(0xFFE8EAF6), // Indigo 50
    primaryDark: Color(0xFF303F9F), // Indigo 700
    accent: Color(0xFF5C6BC0), // Indigo 400
  );

  /// Blue theme
  static const ColorTheme blue = ColorTheme(
    name: 'Blue',
    primary: Color(0xFF2196F3), // Blue 500
    primaryLight: Color(0xFF64B5F6), // Blue 300
    primaryExtraLight: Color(0xFFBBDEFB), // Blue 100
    primaryPlusLight: Color(0xFFCFE8FC), // Blue — between 50 and 100
    primaryUltraLight: Color(0xFFE3F2FD), // Blue 50
    primaryDark: Color(0xFF1976D2), // Blue 700
    accent: Color(0xFF42A5F5), // Blue 400
  );

  /// Green theme
  static const ColorTheme green = ColorTheme(
    name: 'Green',
    primary: Color(0xFF4CAF50), // Green 500
    primaryLight: Color(0xFF81C784), // Green 300
    primaryExtraLight: Color(0xFFC8E6C9), // Green 100
    primaryPlusLight: Color(0xFFD8EDD9), // Green — between 50 and 100
    primaryUltraLight: Color(0xFFE8F5E9), // Green 50
    primaryDark: Color(0xFF388E3C), // Green 700
    accent: Color(0xFF66BB6A), // Green 400
  );

  /// Orange theme
  static const ColorTheme orange = ColorTheme(
    name: 'Orange',
    primary: Color(0xFFFF9800), // Orange 500
    primaryLight: Color(0xFFFFB74D), // Orange 300
    primaryExtraLight: Color(0xFFFFE0B2), // Orange 100
    primaryPlusLight: Color(0xFFFFE9C9), // Orange — between 50 and 100
    primaryUltraLight: Color(0xFFFFF3E0), // Orange 50
    primaryDark: Color(0xFFF57C00), // Orange 700
    accent: Color(0xFFFFA726), // Orange 400
  );

  /// Red theme
  static const ColorTheme red = ColorTheme(
    name: 'Red',
    primary: Color(0xFFF44336), // Red 500
    primaryLight: Color(0xFFE57373), // Red 300
    primaryExtraLight: Color(0xFFFFCDD2), // Red 100
    primaryPlusLight: Color(0xFFFFDCE0), // Red — between 50 and 100
    primaryUltraLight: Color(0xFFFFEBEE), // Red 50
    primaryDark: Color(0xFFD32F2F), // Red 700
    accent: Color(0xFFEF5350), // Red 400
  );

  /// Amber theme
  static const ColorTheme amber = ColorTheme(
    name: 'Amber',
    primary: Color(0xFFFFC107), // Amber 500
    primaryLight: Color(0xFFFFD54F), // Amber 300
    primaryExtraLight: Color(0xFFFFECB3), // Amber 100
    primaryPlusLight: Color(0xFFFFF2CA), // Amber — between 50 and 100
    primaryUltraLight: Color(0xFFFFF8E1), // Amber 50
    primaryDark: Color(0xFFFFA000), // Amber 700
    accent: Color(0xFFFFCA28), // Amber 400
  );

  /// Cyan theme
  static const ColorTheme cyan = ColorTheme(
    name: 'Cyan',
    primary: Color(0xFF00BCD4), // Cyan 500
    primaryLight: Color(0xFF4DD0E1), // Cyan 300
    primaryExtraLight: Color(0xFFB2EBF2), // Cyan 100
    primaryPlusLight: Color(0xFFC9F1F6), // Cyan — between 50 and 100
    primaryUltraLight: Color(0xFFE0F7FA), // Cyan 50
    primaryDark: Color(0xFF0097A7), // Cyan 700
    accent: Color(0xFF26C6DA), // Cyan 400
  );

  /// Deep Purple theme
  static const ColorTheme deepPurple = ColorTheme(
    name: 'Deep Purple',
    primary: Color(0xFF673AB7), // Deep Purple 500
    primaryLight: Color(0xFF9575CD), // Deep Purple 300
    primaryExtraLight: Color(0xFFD1C4E9), // Deep Purple 100
    primaryPlusLight: Color(0xFFDFD5EF), // Deep Purple — between 50 and 100
    primaryUltraLight: Color(0xFFEDE7F6), // Deep Purple 50
    primaryDark: Color(0xFF512DA8), // Deep Purple 700
    accent: Color(0xFF7E57C2), // Deep Purple 400
  );

  /// Dark Black theme
  static const ColorTheme darkBlack = ColorTheme(
    name: 'Dark Black',
    primary: Color(0xFF000000), // Dark Black 500
    primaryLight: Color(0xFF333333), // Dark Black 300
    primaryExtraLight: Color(0xFFE0E0E0), // Grey 300 (between 100 and 333)
    primaryPlusLight: Color(0xFFECECEC), // Grey — between ultra and extra
    primaryUltraLight: Color(0xFFF5F5F5), // Grey 100 (near-white)
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
  final Color primaryExtraLight;
  final Color primaryPlusLight;
  final Color primaryUltraLight;
  final Color primaryDark;
  final Color accent;

  const ColorTheme({
    required this.name,
    required this.primary,
    required this.primaryLight,
    required this.primaryExtraLight,
    required this.primaryPlusLight,
    required this.primaryUltraLight,
    required this.primaryDark,
    required this.accent,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'primary': primary.value,
      'primaryLight': primaryLight.value,
      'primaryExtraLight': primaryExtraLight.value,
      'primaryPlusLight': primaryPlusLight.value,
      'primaryUltraLight': primaryUltraLight.value,
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
      primaryExtraLight: Color(json['primaryExtraLight'] as int),
      primaryPlusLight: Color(json['primaryPlusLight'] as int),
      primaryUltraLight: Color(json['primaryUltraLight'] as int),
      primaryDark: Color(json['primaryDark'] as int),
      accent: Color(json['accent'] as int),
    );
  }
}
