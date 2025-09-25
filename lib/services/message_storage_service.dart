import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';

class MessageStorageService {
  static const String _messagesPrefix = 'messages_';
  static const String _conversationMetaPrefix = 'conversation_meta_';
  static const String _lastUpdatedPrefix = 'last_updated_';
  static const String _pinnedMessagePrefix = 'pinned_message_';
  static const String _starredMessagesPrefix = 'starred_messages_';
  // static const String _mediaPrefix = 'media_';

  // Singleton pattern
  static final MessageStorageService _instance =
      MessageStorageService._internal();
  factory MessageStorageService() => _instance;
  MessageStorageService._internal();

  SharedPreferences? _prefs;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Save messages for a conversation
  Future<void> saveMessages({
    required int conversationId,
    required List<MessageModel> messages,
    required ConversationMeta meta,
  }) async {
    await _initPrefs();

    try {
      // Convert messages to JSON
      final messagesJson = messages.map((msg) => msg.toJson()).toList();
      final messagesString = jsonEncode(messagesJson);

      // Save messages
      await _prefs!.setString(
        '${_messagesPrefix}$conversationId',
        messagesString,
      );

      // Save conversation metadata
      await _prefs!.setString(
        '${_conversationMetaPrefix}$conversationId',
        jsonEncode(meta.toJson()),
      );

      // Save last updated timestamp
      await _prefs!.setInt(
        '${_lastUpdatedPrefix}$conversationId',
        DateTime.now().millisecondsSinceEpoch,
      );

      // Debug: Log first few messages to verify sender IDs and reply data are preserved
      if (messages.isNotEmpty) {
        for (int i = 0; i < messages.length && i < 3; i++) {
          final msg = messages[i];
          final replyInfo = msg.replyToMessage != null
              ? 'replyTo=${msg.replyToMessage!.id}(${msg.replyToMessage!.senderName})'
              : 'no-reply';
          print(
            '💾 Message ${msg.id}: senderId=${msg.senderId}, senderName=${msg.senderName}, $replyInfo',
          );
        }
      }

      print(
        '💾 Saved ${messages.length} messages for conversation $conversationId',
      );
    } catch (e) {
      print('❌ Error saving messages for conversation $conversationId: $e');
    }
  }

  /// Get cached messages for a conversation (optimized for speed)
  Future<CachedConversationData?> getCachedMessages(int conversationId) async {
    await _initPrefs();

    try {
      // Quick check if data exists before parsing
      if (!_prefs!.containsKey('${_messagesPrefix}$conversationId') ||
          !_prefs!.containsKey('${_conversationMetaPrefix}$conversationId')) {
        return null;
      }

      final messagesString = _prefs!.getString(
        '${_messagesPrefix}$conversationId',
      );
      final metaString = _prefs!.getString(
        '${_conversationMetaPrefix}$conversationId',
      );
      final lastUpdated = _prefs!.getInt(
        '${_lastUpdatedPrefix}$conversationId',
      );

      if (messagesString == null ||
          messagesString.isEmpty ||
          metaString == null ||
          metaString.isEmpty) {
        return null;
      }

      // Parse messages (this is the time-consuming part)
      final messagesJson = jsonDecode(messagesString) as List;
      final messages = messagesJson
          .map((json) => MessageModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Parse metadata
      final meta = ConversationMeta.fromJson(
        jsonDecode(metaString) as Map<String, dynamic>,
      );

      // Debug: Log first few messages to verify sender IDs and reply data are preserved in cache
      if (messages.isNotEmpty) {
        for (int i = 0; i < messages.length && i < 2; i++) {
          // Reduced to 2 for speed
          final msg = messages[i];
          final replyInfo = msg.replyToMessage != null
              ? 'replyTo=${msg.replyToMessage!.id}(${msg.replyToMessage!.senderName})'
              : 'no-reply';
          print(
            '📱 Cached Message ${msg.id}: senderId=${msg.senderId}, senderName=${msg.senderName}, $replyInfo',
          );
        }
      }

      print(
        '⚡ Fast retrieved ${messages.length} cached messages for conversation $conversationId',
      );

      return CachedConversationData(
        messages: messages,
        meta: meta,
        lastUpdated: lastUpdated != null
            ? DateTime.fromMillisecondsSinceEpoch(lastUpdated)
            : null,
      );
    } catch (e) {
      print(
        '❌ Error retrieving cached messages for conversation $conversationId: $e',
      );
      return null;
    }
  }

  /// Add new messages to existing cache (for pagination or new messages)
  Future<void> addMessagesToCache({
    required int conversationId,
    required List<MessageModel> newMessages,
    required ConversationMeta updatedMeta,
    bool insertAtBeginning = true,
  }) async {
    await _initPrefs();

    try {
      // Get existing messages
      final existing = await getCachedMessages(conversationId);
      List<MessageModel> allMessages = [];

      if (existing != null) {
        if (insertAtBeginning) {
          // Add older messages at the beginning (for pagination)
          allMessages = [...newMessages, ...existing.messages];
        } else {
          // Add newer messages at the end (for smart sync)
          allMessages = [...existing.messages, ...newMessages];
        }
      } else {
        allMessages = newMessages;
      }

      // Remove duplicates based on message ID (preserve newer versions)
      final uniqueMessages = <int, MessageModel>{};
      for (final message in allMessages) {
        uniqueMessages[message.id] = message;
      }

      final finalMessages = uniqueMessages.values.toList();
      // Sort by creation date to maintain chronological order
      finalMessages.sort(
        (a, b) =>
            DateTime.parse(a.createdAt).compareTo(DateTime.parse(b.createdAt)),
      );

      await saveMessages(
        conversationId: conversationId,
        messages: finalMessages,
        meta: updatedMeta,
      );

      final action = insertAtBeginning ? 'older' : 'newer';
      print(
        '➕ Added ${newMessages.length} $action messages to cache for conversation $conversationId',
      );
    } catch (e) {
      print(
        '❌ Error adding messages to cache for conversation $conversationId: $e',
      );
    }
  }

  /// Add a single new message to cache
  Future<void> addMessageToCache({
    required int conversationId,
    required MessageModel newMessage,
    required ConversationMeta updatedMeta,
    bool insertAtBeginning = true,
  }) async {
    await addMessagesToCache(
      conversationId: conversationId,
      newMessages: [newMessage],
      updatedMeta: updatedMeta,
      insertAtBeginning: insertAtBeginning,
    );
  }

  /// Check if conversation exists in cache
  Future<bool> hasConversation(int conversationId) async {
    await _initPrefs();
    return _prefs!.containsKey('${_messagesPrefix}$conversationId');
  }

  /// Check if cache is stale (older than specified minutes)
  Future<bool> isCacheStale(
    int conversationId, {
    int maxAgeMinutes = 30,
  }) async {
    await _initPrefs();

    final lastUpdated = _prefs!.getInt('${_lastUpdatedPrefix}$conversationId');
    if (lastUpdated == null) return true;

    final cacheAge = DateTime.now().millisecondsSinceEpoch - lastUpdated;
    final maxAgeMs = maxAgeMinutes * 60 * 1000;

    return cacheAge > maxAgeMs;
  }

  /// Clear cache for a specific conversation
  Future<void> clearConversationCache(int conversationId) async {
    await _initPrefs();

    await Future.wait([
      _prefs!.remove('${_messagesPrefix}$conversationId'),
      _prefs!.remove('${_conversationMetaPrefix}$conversationId'),
      _prefs!.remove('${_lastUpdatedPrefix}$conversationId'),
      _prefs!.remove('${_pinnedMessagePrefix}$conversationId'),
      _prefs!.remove('${_starredMessagesPrefix}$conversationId'),
    ]);

    print('🗑️ Cleared cache for conversation $conversationId');
  }

  /// Clear all message caches
  Future<void> clearAllCache() async {
    await _initPrefs();

    final keys = _prefs!
        .getKeys()
        .where(
          (key) =>
              key.startsWith(_messagesPrefix) ||
              key.startsWith(_conversationMetaPrefix) ||
              key.startsWith(_lastUpdatedPrefix) ||
              key.startsWith(_pinnedMessagePrefix) ||
              key.startsWith(_starredMessagesPrefix),
        )
        .toList();

    for (final key in keys) {
      await _prefs!.remove(key);
    }

    print('🗑️ Cleared all message caches');
  }

  /// Get cache statistics
  Future<CacheStats> getCacheStats() async {
    await _initPrefs();

    final keys = _prefs!.getKeys();
    final messageKeys = keys
        .where((key) => key.startsWith(_messagesPrefix))
        .toList();

    int totalMessages = 0;
    for (final key in messageKeys) {
      try {
        final messagesString = _prefs!.getString(key);
        if (messagesString != null) {
          final messagesJson = jsonDecode(messagesString) as List;
          totalMessages += messagesJson.length;
        }
      } catch (e) {
        // Skip corrupted entries
      }
    }

    return CacheStats(
      cachedConversations: messageKeys.length,
      totalCachedMessages: totalMessages,
    );
  }

  /// Save pinned message ID for a conversation
  Future<void> savePinnedMessage({
    required int conversationId,
    required int? pinnedMessageId,
  }) async {
    await _initPrefs();

    try {
      if (pinnedMessageId != null) {
        await _prefs!.setInt(
          '${_pinnedMessagePrefix}$conversationId',
          pinnedMessageId,
        );
        print(
          '📌 Saved pinned message $pinnedMessageId for conversation $conversationId',
        );
      } else {
        await _prefs!.remove('${_pinnedMessagePrefix}$conversationId');
        print('📌 Removed pinned message for conversation $conversationId');
      }
    } catch (e) {
      print(
        '❌ Error saving pinned message for conversation $conversationId: $e',
      );
    }
  }

  /// Get pinned message ID for a conversation
  Future<int?> getPinnedMessage(int conversationId) async {
    await _initPrefs();

    try {
      final pinnedMessageId = _prefs!.getInt(
        '${_pinnedMessagePrefix}$conversationId',
      );
      if (pinnedMessageId != null) {
        print(
          '📌 Retrieved pinned message $pinnedMessageId for conversation $conversationId',
        );
      }
      return pinnedMessageId;
    } catch (e) {
      print(
        '❌ Error retrieving pinned message for conversation $conversationId: $e',
      );
      return null;
    }
  }

  /// Clear pinned message for a specific conversation
  Future<void> clearPinnedMessage(int conversationId) async {
    await _initPrefs();

    try {
      await _prefs!.remove('${_pinnedMessagePrefix}$conversationId');
      print('📌 Cleared pinned message for conversation $conversationId');
    } catch (e) {
      print(
        '❌ Error clearing pinned message for conversation $conversationId: $e',
      );
    }
  }

  /// Save starred messages for a conversation
  Future<void> saveStarredMessages({
    required int conversationId,
    required Set<int> starredMessageIds,
  }) async {
    await _initPrefs();

    try {
      final starredList = starredMessageIds.toList();
      await _prefs!.setString(
        '${_starredMessagesPrefix}$conversationId',
        jsonEncode(starredList),
      );
      print(
        '⭐ Saved ${starredList.length} starred messages for conversation $conversationId',
      );
    } catch (e) {
      print(
        '❌ Error saving starred messages for conversation $conversationId: $e',
      );
    }
  }

  /// Get starred messages for a conversation
  Future<Set<int>> getStarredMessages(int conversationId) async {
    await _initPrefs();

    try {
      final starredString = _prefs!.getString(
        '${_starredMessagesPrefix}$conversationId',
      );

      if (starredString == null || starredString.isEmpty) {
        return <int>{};
      }

      final starredList = jsonDecode(starredString) as List;
      final starredSet = starredList.cast<int>().toSet();

      print(
        '⭐ Retrieved ${starredSet.length} starred messages for conversation $conversationId',
      );

      return starredSet;
    } catch (e) {
      print(
        '❌ Error retrieving starred messages for conversation $conversationId: $e',
      );
      return <int>{};
    }
  }

  /// Add a message to starred messages
  Future<void> starMessage({
    required int conversationId,
    required int messageId,
  }) async {
    await _initPrefs();

    try {
      final currentStarred = await getStarredMessages(conversationId);
      currentStarred.add(messageId);

      await saveStarredMessages(
        conversationId: conversationId,
        starredMessageIds: currentStarred,
      );

      print('⭐ Starred message $messageId in conversation $conversationId');
    } catch (e) {
      print(
        '❌ Error starring message $messageId in conversation $conversationId: $e',
      );
    }
  }

  /// Remove a message from starred messages
  Future<void> unstarMessage({
    required int conversationId,
    required int messageId,
  }) async {
    await _initPrefs();

    try {
      final currentStarred = await getStarredMessages(conversationId);
      currentStarred.remove(messageId);

      await saveStarredMessages(
        conversationId: conversationId,
        starredMessageIds: currentStarred,
      );

      print('⭐ Unstarred message $messageId in conversation $conversationId');
    } catch (e) {
      print(
        '❌ Error unstarring message $messageId in conversation $conversationId: $e',
      );
    }
  }

  /// Toggle star status of a message
  Future<bool> toggleStarMessage({
    required int conversationId,
    required int messageId,
  }) async {
    await _initPrefs();

    try {
      final currentStarred = await getStarredMessages(conversationId);
      final isCurrentlyStarred = currentStarred.contains(messageId);

      if (isCurrentlyStarred) {
        currentStarred.remove(messageId);
      } else {
        currentStarred.add(messageId);
      }

      await saveStarredMessages(
        conversationId: conversationId,
        starredMessageIds: currentStarred,
      );

      final action = isCurrentlyStarred ? 'Unstarred' : 'Starred';
      print('⭐ $action message $messageId in conversation $conversationId');

      return !isCurrentlyStarred; // Return new star status
    } catch (e) {
      print(
        '❌ Error toggling star for message $messageId in conversation $conversationId: $e',
      );
      return false;
    }
  }

  /// Clear starred messages for a specific conversation
  Future<void> clearStarredMessages(int conversationId) async {
    await _initPrefs();

    try {
      await _prefs!.remove('${_starredMessagesPrefix}$conversationId');
      print('⭐ Cleared starred messages for conversation $conversationId');
    } catch (e) {
      print(
        '❌ Error clearing starred messages for conversation $conversationId: $e',
      );
    }
  }

  /// Validate that reply messages are properly stored and can be retrieved
  Future<bool> validateReplyMessageStorage(int conversationId) async {
    try {
      final cachedData = await getCachedMessages(conversationId);
      if (cachedData == null) {
        print('⚠️ No cached data found for validation');
        return false;
      }

      int replyMessagesCount = 0;
      int validReplyMessagesCount = 0;

      for (final message in cachedData.messages) {
        if (message.replyToMessage != null ||
            message.replyToMessageId != null) {
          replyMessagesCount++;

          // Check if reply data is complete
          if (message.replyToMessage != null) {
            final replyMsg = message.replyToMessage!;
            if (replyMsg.id > 0 &&
                replyMsg.body.isNotEmpty &&
                replyMsg.senderName.isNotEmpty) {
              validReplyMessagesCount++;
              print(
                '✅ Valid reply message ${message.id} -> ${replyMsg.id} (${replyMsg.senderName}): "${replyMsg.body.length > 30 ? replyMsg.body.substring(0, 30) + "..." : replyMsg.body}"',
              );
            } else {
              print(
                '⚠️ Invalid reply message ${message.id} -> incomplete reply data',
              );
            }
          } else if (message.replyToMessageId != null) {
            print(
              '📝 Reply message ${message.id} has replyToMessageId: ${message.replyToMessageId}',
            );
            validReplyMessagesCount++; // Count as valid if ID is present
          }
        }
      }

      print(
        '🔍 Reply message validation: $validReplyMessagesCount/$replyMessagesCount reply messages are valid',
      );

      return replyMessagesCount == 0 ||
          validReplyMessagesCount == replyMessagesCount;
    } catch (e) {
      print('❌ Error validating reply message storage: $e');
      return false;
    }
  }

  /// Get all reply messages in a conversation (for debugging)
  Future<List<MessageModel>> getReplyMessages(int conversationId) async {
    try {
      final cachedData = await getCachedMessages(conversationId);
      if (cachedData == null) return [];

      final replyMessages = cachedData.messages
          .where(
            (msg) => msg.replyToMessage != null || msg.replyToMessageId != null,
          )
          .toList();

      print(
        '💬 Found ${replyMessages.length} reply messages in conversation $conversationId',
      );
      return replyMessages;
    } catch (e) {
      print('❌ Error getting reply messages: $e');
      return [];
    }
  }

  /// Remove a specific message from cache
  Future<void> removeMessageFromCache({
    required int conversationId,
    required List<int> messageIds,
  }) async {
    await _initPrefs();

    try {
      // Get existing messages
      final existing = await getCachedMessages(conversationId);
      if (existing == null) {
        print('⚠️ No cached messages found for conversation $conversationId');
        return;
      }

      // Remove the message with the specified ID
      final updatedMessages = existing.messages
          .where((message) => !messageIds.contains(message.id))
          .toList();

      // Check if any message was actually removed
      if (updatedMessages.length == existing.messages.length) {
        print(
          '⚠️ Message $messageIds not found in cache for conversation $conversationId',
        );
        return;
      }

      // Update the total count in metadata
      final updatedMeta = existing.meta.copyWith(
        totalCount: existing.meta.totalCount - 1,
      );

      // Save the updated messages back to cache
      await saveMessages(
        conversationId: conversationId,
        messages: updatedMessages,
        meta: updatedMeta,
      );

      print(
        '🗑️ Removed message $messageIds from cache for conversation $conversationId',
      );
    } catch (e) {
      print(
        '❌ Error removing message $messageIds from cache for conversation $conversationId: $e',
      );
    }
  }

  /// Update message read/delivery status
  Future<void> updateMessageStatus({
    required int conversationId,
    required int messageId,
    bool? isDelivered,
    bool? isRead,
  }) async {
    await _initPrefs();

    try {
      final messagesString = _prefs!.getString(
        '${_messagesPrefix}$conversationId',
      );
      if (messagesString == null) return;

      final List<dynamic> messagesJson = jsonDecode(messagesString);
      final List<MessageModel> messages = messagesJson
          .map((json) => MessageModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // Find and update the message
      final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
      if (messageIndex != -1) {
        final currentMessage = messages[messageIndex];
        final updatedMessage = currentMessage.copyWith(
          isDelivered: isDelivered ?? currentMessage.isDelivered,
          // isRead: isRead ?? currentMessage.isRead,
        );

        messages[messageIndex] = updatedMessage;

        // Save updated messages
        final updatedMessagesJson = messages
            .map((msg) => msg.toJson())
            .toList();
        final updatedMessagesString = jsonEncode(updatedMessagesJson);

        await _prefs!.setString(
          '${_messagesPrefix}$conversationId',
          updatedMessagesString,
        );
      }
    } catch (e) {
      print(
        '❌ Error updating message status for message $messageId in conversation $conversationId: $e',
      );
    }
  }
}

/// Metadata about a cached conversation
class ConversationMeta {
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPreviousPage;

  ConversationMeta({
    required this.totalCount,
    required this.currentPage,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory ConversationMeta.fromResponse(ConversationHistoryResponse response) {
    return ConversationMeta(
      totalCount: response.totalCount,
      currentPage: response.currentPage,
      totalPages: response.totalPages,
      hasNextPage: response.hasNextPage,
      hasPreviousPage: response.hasPreviousPage,
    );
  }

  factory ConversationMeta.fromJson(Map<String, dynamic> json) {
    return ConversationMeta(
      totalCount: json['totalCount'] ?? 0,
      currentPage: json['currentPage'] ?? 1,
      totalPages: json['totalPages'] ?? 1,
      hasNextPage: json['hasNextPage'] ?? false,
      hasPreviousPage: json['hasPreviousPage'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalCount': totalCount,
      'currentPage': currentPage,
      'totalPages': totalPages,
      'hasNextPage': hasNextPage,
      'hasPreviousPage': hasPreviousPage,
    };
  }

  ConversationMeta copyWith({
    int? totalCount,
    int? currentPage,
    int? totalPages,
    bool? hasNextPage,
    bool? hasPreviousPage,
  }) {
    return ConversationMeta(
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
    );
  }
}

/// Cached conversation data
class CachedConversationData {
  final List<MessageModel> messages;
  final ConversationMeta meta;
  final DateTime? lastUpdated;

  CachedConversationData({
    required this.messages,
    required this.meta,
    this.lastUpdated,
  });
}

/// Cache statistics
class CacheStats {
  final int cachedConversations;
  final int totalCachedMessages;

  CacheStats({
    required this.cachedConversations,
    required this.totalCachedMessages,
  });
}
