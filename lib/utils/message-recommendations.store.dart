import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<String> kDefaultMessageRecommendations = [
  'Hi',
  'Hello',
  'Done',
  'Bye',
  'Ok',
  'Thanks',
  'Sure',
  'Yes',
  'No',
  'Maybe',
];

class MessageRecommendationsStore {
  static const String _prefsKey = 'message_recommendations';
  static const String _enabledKey = 'message_recommendations_enabled';

  static Future<bool> loadEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (e) {
      debugPrint('Error loading quick replies enabled flag: $e');
      return false;
    }
  }

  static Future<void> saveEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled);
    } catch (e) {
      debugPrint('Error saving quick replies enabled flag: $e');
    }
  }

  static Future<List<String>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) {
        return List<String>.from(kDefaultMessageRecommendations);
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading message recommendations: $e');
    }
    return List<String>.from(kDefaultMessageRecommendations);
  }

  static Future<void> save(List<String> values) async {
    try {
      final cleaned = values
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(cleaned));
    } catch (e) {
      debugPrint('Error saving message recommendations: $e');
    }
  }
}
