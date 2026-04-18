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
  Future<void> saveDraft(String conversationId, String draftText) async {
    await _initPrefs();
    try {
      final existingData = _prefs!.getString(_draftMessagesKey);
      Map<String, String> drafts = {};

      if (existingData != null) {
        drafts = Map<String, String>.from(json.decode(existingData));
      }

      if (draftText.trim().isEmpty) {
        // Remove draft if text is empty
        drafts.remove(conversationId);
      } else {
        drafts[conversationId] = draftText;
      }

      await _prefs!.setString(_draftMessagesKey, json.encode(drafts));
    } catch (e) {
      debugPrint('❌ Error saving draft');
    }
  }

  /// Get draft message for a conversation
  Future<String?> getDraft(String conversationId) async {
    await _initPrefs();
    try {
      final data = _prefs!.getString(_draftMessagesKey);
      if (data == null) return null;

      final drafts = Map<String, String>.from(json.decode(data));
      return drafts[conversationId];
    } catch (e) {
      debugPrint('❌ Error getting draft');
      return null;
    }
  }

  /// Remove draft for a conversation
  Future<void> removeDraft(String conversationId) async {
    await _initPrefs();
    try {
      final existingData = _prefs!.getString(_draftMessagesKey);
      if (existingData == null) return;

      final drafts = Map<String, String>.from(json.decode(existingData));
      drafts.remove(conversationId);

      await _prefs!.setString(_draftMessagesKey, json.encode(drafts));
    } catch (e) {
      debugPrint('❌ Error removing draft');
    }
  }

  /// Get all drafts
  Future<Map<String, String>> getAllDrafts() async {
    await _initPrefs();
    try {
      final data = _prefs!.getString(_draftMessagesKey);
      if (data == null) return {};

      return Map<String, String>.from(json.decode(data));
    } catch (e) {
      debugPrint('❌ Error getting all drafts');
      return {};
    }
  }
}
