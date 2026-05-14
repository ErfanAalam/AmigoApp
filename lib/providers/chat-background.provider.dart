import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted chat wallpaper path. `null` => use the default bundled asset.
final chatBackgroundProvider =
    NotifierProvider<ChatBackgroundNotifier, String?>(() {
  return ChatBackgroundNotifier();
});

class ChatBackgroundNotifier extends Notifier<String?> {
  static const String _prefsKey = 'chat_background_path';

  @override
  String? build() {
    Future.microtask(_load);
    return null;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getString(_prefsKey);
    } catch (e) {
      debugPrint('Error loading chat background: $e');
    }
  }

  Future<void> setBackground(String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, path);
      state = path;
    } catch (e) {
      debugPrint('Error saving chat background: $e');
    }
  }

  Future<void> resetBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      state = null;
    } catch (e) {
      debugPrint('Error resetting chat background: $e');
    }
  }
}
