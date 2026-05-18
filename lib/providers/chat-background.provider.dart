import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted chat wallpaper config. `path == null` => use the default
/// bundled asset. `brightness` is a multiplier (0.3..1.0 where 1.0 is the
/// untouched image). `blur` enables a full-image blur.
class ChatBackgroundState {
  final String? path;
  final double brightness;
  final bool blur;

  const ChatBackgroundState({
    this.path,
    this.brightness = 1.0,
    this.blur = false,
  });

  ChatBackgroundState copyWith({
    String? path,
    bool clearPath = false,
    double? brightness,
    bool? blur,
  }) {
    return ChatBackgroundState(
      path: clearPath ? null : (path ?? this.path),
      brightness: brightness ?? this.brightness,
      blur: blur ?? this.blur,
    );
  }
}

final chatBackgroundProvider =
    NotifierProvider<ChatBackgroundNotifier, ChatBackgroundState>(() {
  return ChatBackgroundNotifier();
});

class ChatBackgroundNotifier extends Notifier<ChatBackgroundState> {
  static const String _pathKey = 'chat_background_path';
  static const String _brightnessKey = 'chat_background_brightness';
  static const String _blurKey = 'chat_background_blur';

  @override
  ChatBackgroundState build() {
    Future.microtask(_load);
    return const ChatBackgroundState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = ChatBackgroundState(
        path: prefs.getString(_pathKey),
        brightness: prefs.getDouble(_brightnessKey) ?? 1.0,
        blur: prefs.getBool(_blurKey) ?? false,
      );
    } catch (e) {
      debugPrint('Error loading chat background: $e');
    }
  }

  Future<void> setBackground(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pathKey, path);
      state = state.copyWith(path: path);
    } catch (e) {
      debugPrint('Error saving chat background: $e');
    }
  }

  Future<void> setBrightness(double value) async {
    final clamped = value.clamp(0.3, 1.0);
    state = state.copyWith(brightness: clamped);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_brightnessKey, clamped);
    } catch (e) {
      debugPrint('Error saving chat background brightness: $e');
    }
  }

  Future<void> setBlur(bool enabled) async {
    state = state.copyWith(blur: enabled);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_blurKey, enabled);
    } catch (e) {
      debugPrint('Error saving chat background blur: $e');
    }
  }

  Future<void> resetBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pathKey);
      await prefs.remove(_brightnessKey);
      await prefs.remove(_blurKey);
      state = const ChatBackgroundState();
    } catch (e) {
      debugPrint('Error resetting chat background: $e');
    }
  }
}
