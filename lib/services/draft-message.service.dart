import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DraftMessageService {
  static const String _draftMessagesKey = 'draft_messages';

  // Singleton pattern
  static final DraftMessageService _instance = DraftMessageService._internal();
  factory DraftMessageService() => _instance;
  DraftMessageService._internal();

  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save draft message for a conversation
  Future<void> saveDraft(int conversationId, String draftText) async {
    await _initPrefs();
    try {
      final existingData = _prefs!.getString(_draftMessagesKey);
      Map<String, String> drafts = {};

      if (existingData != null) {
        drafts = Map<String, String>.from(json.decode(existingData));
      }

      if (draftText.trim().isEmpty) {
        // Remove draft if text is empty
        drafts.remove(conversationId.toString());
      } else {
        drafts[conversationId.toString()] = draftText;
      }

      await _prefs!.setString(_draftMessagesKey, json.encode(drafts));
    } catch (e) {
      debugPrint('❌ Error saving draft');
    }
  }

  /// Get draft message for a conversation
  Future<String?> getDraft(int conversationId) async {
    await _initPrefs();
    try {
      final data = _prefs!.getString(_draftMessagesKey);
      if (data == null) return null;

      final drafts = Map<String, String>.from(json.decode(data));
      return drafts[conversationId.toString()];
    } catch (e) {
      debugPrint('❌ Error getting draft');
      return null;
    }
  }

  /// Remove draft for a conversation
  Future<void> removeDraft(int conversationId) async {
    await _initPrefs();
    try {
      final existingData = _prefs!.getString(_draftMessagesKey);
      if (existingData == null) return;

      final drafts = Map<String, String>.from(json.decode(existingData));
      drafts.remove(conversationId.toString());

      await _prefs!.setString(_draftMessagesKey, json.encode(drafts));
    } catch (e) {
      debugPrint('❌ Error removing draft');
    }
  }

  /// Get all drafts
  Future<Map<int, String>> getAllDrafts() async {
    await _initPrefs();
    try {
      final data = _prefs!.getString(_draftMessagesKey);
      if (data == null) return {};

      final draftsMap = Map<String, String>.from(json.decode(data));
      return draftsMap.map((key, value) => MapEntry(int.parse(key), value));
    } catch (e) {
      debugPrint('❌ Error getting all drafts');
      return {};
    }
  }
}
