import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPreferencesService {
  static const String _pinnedChatsKey = 'pinned_chats';
  static const String _mutedChatsKey = 'muted_chats';
  static const String _favoriteChatsKey = 'favorite_chats';
  static const String _deletedChatsKey = 'deleted_chats';
  static const int maxPinnedChats = 3;

  // Singleton pattern
  static final ChatPreferencesService _instance =
      ChatPreferencesService._internal();
  factory ChatPreferencesService() => _instance;
  ChatPreferencesService._internal();

  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Pinned Chats
  Future<List<int>> getPinnedChats() async {
    await _initPrefs();
    final pinnedJson = _prefs!.getString(_pinnedChatsKey);
    if (pinnedJson == null) return [];
    return List<int>.from(json.decode(pinnedJson));
  }

  Future<bool> pinChat(int conversationId) async {
    await _initPrefs();
    final pinnedChats = await getPinnedChats();

    if (pinnedChats.contains(conversationId)) return false;
    if (pinnedChats.length >= maxPinnedChats) return false;

    pinnedChats.add(conversationId);
    await _prefs!.setString(_pinnedChatsKey, json.encode(pinnedChats));
    return true;
  }

  Future<void> unpinChat(int conversationId) async {
    await _initPrefs();
    final pinnedChats = await getPinnedChats();
    pinnedChats.remove(conversationId);
    await _prefs!.setString(_pinnedChatsKey, json.encode(pinnedChats));
  }

  Future<bool> isChatPinned(int conversationId) async {
    final pinnedChats = await getPinnedChats();
    return pinnedChats.contains(conversationId);
  }

  Future<int> getPinnedChatsCount() async {
    final pinnedChats = await getPinnedChats();
    return pinnedChats.length;
  }

  // Muted Chats
  Future<List<int>> getMutedChats() async {
    await _initPrefs();
    final mutedJson = _prefs!.getString(_mutedChatsKey);
    if (mutedJson == null) return [];
    return List<int>.from(json.decode(mutedJson));
  }

  Future<void> muteChat(int conversationId) async {
    await _initPrefs();
    final mutedChats = await getMutedChats();
    if (!mutedChats.contains(conversationId)) {
      mutedChats.add(conversationId);
      await _prefs!.setString(_mutedChatsKey, json.encode(mutedChats));
    }
  }

  Future<void> unmuteChat(int conversationId) async {
    await _initPrefs();
    final mutedChats = await getMutedChats();
    mutedChats.remove(conversationId);
    await _prefs!.setString(_mutedChatsKey, json.encode(mutedChats));
  }

  Future<bool> isChatMuted(int conversationId) async {
    final mutedChats = await getMutedChats();
    return mutedChats.contains(conversationId);
  }

  // Favorite Chats
  Future<List<int>> getFavoriteChats() async {
    await _initPrefs();
    final favoriteJson = _prefs!.getString(_favoriteChatsKey);
    if (favoriteJson == null) return [];
    return List<int>.from(json.decode(favoriteJson));
  }

  Future<void> favoriteChat(int conversationId) async {
    await _initPrefs();
    final favoriteChats = await getFavoriteChats();
    if (!favoriteChats.contains(conversationId)) {
      favoriteChats.add(conversationId);
      await _prefs!.setString(_favoriteChatsKey, json.encode(favoriteChats));
    }
  }

  Future<void> unfavoriteChat(int conversationId) async {
    await _initPrefs();
    final favoriteChats = await getFavoriteChats();
    favoriteChats.remove(conversationId);
    await _prefs!.setString(_favoriteChatsKey, json.encode(favoriteChats));
  }

  Future<bool> isChatFavorite(int conversationId) async {
    final favoriteChats = await getFavoriteChats();
    return favoriteChats.contains(conversationId);
  }

  // Deleted Chats
  Future<List<Map<String, dynamic>>> getDeletedChats() async {
    await _initPrefs();
    final deletedJson = _prefs!.getString(_deletedChatsKey);
    if (deletedJson == null) return [];
    return List<Map<String, dynamic>>.from(json.decode(deletedJson));
  }

  Future<void> deleteChat(
    int conversationId,
    Map<String, dynamic> conversationData,
  ) async {
    await _initPrefs();
    final deletedChats = await getDeletedChats();

    // Add timestamp for deletion
    conversationData['deleted_at'] = DateTime.now().toIso8601String();
    conversationData['conversation_id'] = conversationId;

    // Remove if already exists and add to beginning
    deletedChats.removeWhere(
      (chat) => chat['conversation_id'] == conversationId,
    );
    deletedChats.insert(0, conversationData);

    await _prefs!.setString(_deletedChatsKey, json.encode(deletedChats));

    // Also remove from pinned, muted, and favorite lists
    await unpinChat(conversationId);
    await unmuteChat(conversationId);
    await unfavoriteChat(conversationId);
  }

  Future<void> restoreChat(int conversationId) async {
    await _initPrefs();
    final deletedChats = await getDeletedChats();
    deletedChats.removeWhere(
      (chat) => chat['conversation_id'] == conversationId,
    );
    await _prefs!.setString(_deletedChatsKey, json.encode(deletedChats));
  }

  Future<bool> isChatDeleted(int conversationId) async {
    final deletedChats = await getDeletedChats();
    return deletedChats.any(
      (chat) => chat['conversation_id'] == conversationId,
    );
  }

  // Clear all preferences (for testing or logout)
  Future<void> clearAllPreferences() async {
    await _initPrefs();
    await _prefs!.remove(_pinnedChatsKey);
    await _prefs!.remove(_mutedChatsKey);
    await _prefs!.remove(_favoriteChatsKey);
    await _prefs!.remove(_deletedChatsKey);
  }
}
