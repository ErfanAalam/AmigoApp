import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LastMessageStorageService {
  static const String _lastMessagesKey = 'last_messages';
  static const String _groupLastMessagesKey = 'group_last_messages';

  static LastMessageStorageService? _instance;
  static LastMessageStorageService get instance {
    _instance ??= LastMessageStorageService._();
    return _instance!;
  }

  LastMessageStorageService._();

  /// Store last message for a DM conversation
  Future<void> storeLastMessage(
    int conversationId,
    Map<String, dynamic> messageData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString(_lastMessagesKey);
      Map<String, dynamic> lastMessages = {};

      if (existingData != null) {
        lastMessages = json.decode(existingData) as Map<String, dynamic>;
      }

      // Store the message data
      lastMessages[conversationId.toString()] = {
        'id': messageData['id'] ?? messageData['media_message_id'] ?? 0,
        'body': messageData['body'] ?? '',
        'type': messageData['type'] ?? 'text',
        'sender_id': messageData['sender_id'] ?? messageData['user_id'] ?? 0,
        'created_at':
            messageData['created_at'] ?? DateTime.now().toIso8601String(),
        'conversation_id': conversationId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(_lastMessagesKey, json.encode(lastMessages));
      print(
        '✅ Stored last message for conversation $conversationId: ${messageData['body']}',
      );
    } catch (e) {
      print('❌ Error storing last message: $e');
    }
  }

  /// Store last message for a group conversation
  Future<void> storeGroupLastMessage(
    int conversationId,
    Map<String, dynamic> messageData,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString(_groupLastMessagesKey);
      Map<String, dynamic> lastMessages = {};

      if (existingData != null) {
        lastMessages = json.decode(existingData) as Map<String, dynamic>;
      }

      // Store the message data
      lastMessages[conversationId.toString()] = {
        'id': messageData['id'] ?? messageData['media_message_id'] ?? 0,
        'body': messageData['body'] ?? '',
        'type': messageData['type'] ?? 'text',
        'sender_id': messageData['sender_id'] ?? messageData['user_id'] ?? 0,
        'sender_name': messageData['sender_name'] ?? '',
        'created_at':
            messageData['created_at'] ?? DateTime.now().toIso8601String(),
        'conversation_id': conversationId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString(_groupLastMessagesKey, json.encode(lastMessages));
      print(
        '✅ Stored group last message for conversation $conversationId: ${messageData['body']}',
      );
    } catch (e) {
      print('❌ Error storing group last message: $e');
    }
  }

  /// Get last message for a DM conversation
  Future<Map<String, dynamic>?> getLastMessage(int conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_lastMessagesKey);

      if (data != null) {
        final lastMessages = json.decode(data) as Map<String, dynamic>;
        return lastMessages[conversationId.toString()];
      }
      return null;
    } catch (e) {
      print('❌ Error getting last message: $e');
      return null;
    }
  }

  /// Get last message for a group conversation
  Future<Map<String, dynamic>?> getGroupLastMessage(int conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_groupLastMessagesKey);

      if (data != null) {
        final lastMessages = json.decode(data) as Map<String, dynamic>;
        return lastMessages[conversationId.toString()];
      }
      return null;
    } catch (e) {
      print('❌ Error getting group last message: $e');
      return null;
    }
  }

  /// Get all last messages for DM conversations
  Future<Map<int, Map<String, dynamic>>> getAllLastMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_lastMessagesKey);

      if (data != null) {
        final lastMessages = json.decode(data) as Map<String, dynamic>;
        return lastMessages.map(
          (key, value) =>
              MapEntry(int.parse(key), Map<String, dynamic>.from(value as Map)),
        );
      }
      return {};
    } catch (e) {
      print('❌ Error getting all last messages: $e');
      return {};
    }
  }

  /// Get all last messages for group conversations
  Future<Map<int, Map<String, dynamic>>> getAllGroupLastMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_groupLastMessagesKey);

      if (data != null) {
        final lastMessages = json.decode(data) as Map<String, dynamic>;
        return lastMessages.map(
          (key, value) =>
              MapEntry(int.parse(key), Map<String, dynamic>.from(value as Map)),
        );
      }
      return {};
    } catch (e) {
      print('❌ Error getting all group last messages: $e');
      return {};
    }
  }

  /// Clear last message for a specific conversation
  Future<void> clearLastMessage(int conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString(_lastMessagesKey);

      if (existingData != null) {
        final lastMessages = json.decode(existingData) as Map<String, dynamic>;
        lastMessages.remove(conversationId.toString());
        await prefs.setString(_lastMessagesKey, json.encode(lastMessages));
      }
    } catch (e) {
      print('❌ Error clearing last message: $e');
    }
  }

  /// Clear last message for a specific group conversation
  Future<void> clearGroupLastMessage(int conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingData = prefs.getString(_groupLastMessagesKey);

      if (existingData != null) {
        final lastMessages = json.decode(existingData) as Map<String, dynamic>;
        lastMessages.remove(conversationId.toString());
        await prefs.setString(_groupLastMessagesKey, json.encode(lastMessages));
      }
    } catch (e) {
      print('❌ Error clearing group last message: $e');
    }
  }

  /// Clear all last messages (used during logout)
  Future<void> clearAllLastMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastMessagesKey);
      await prefs.remove(_groupLastMessagesKey);
      print('✅ Cleared all last messages from storage');
    } catch (e) {
      print('❌ Error clearing all last messages: $e');
    }
  }

  /// Update last message from WebSocket message
  Future<void> updateLastMessageFromWebSocket(
    Map<String, dynamic> message,
  ) async {
    try {
      final conversationId = message['conversation_id'] as int?;
      if (conversationId == null) return;

      final messageType = message['type'] as String?;
      final data = message['data'] as Map<String, dynamic>? ?? {};

      // Handle different message types
      if (messageType == 'message' || messageType == 'media') {
        // Extract message details with proper handling for media messages
        String messageBody = data['body'] ?? '';
        String messageTypeValue = data['type'] ?? messageType ?? 'text';
        int senderId = data['sender_id'] ?? 0;
        int messageId = data['id'] ?? 0;
        String createdAt =
            data['created_at'] ??
            message['timestamp'] ??
            DateTime.now().toIso8601String();

        // If body is empty and it's a media message, extract from nested data
        if (messageBody.isEmpty && data['data'] != null) {
          final nestedData = data['data'] as Map<String, dynamic>;
          messageBody =
              nestedData['message_type'] ?? nestedData['file_name'] ?? '';
          messageTypeValue =
              nestedData['message_type'] ?? messageType ?? 'media';
          senderId = nestedData['user_id'] ?? senderId;
          messageId =
              nestedData['media_message_id'] ??
              data['media_message_id'] ??
              messageId;
          createdAt = nestedData['created_at'] ?? createdAt;
        }

        final messageData = {
          'id': messageId,
          'body': messageBody,
          'type': messageTypeValue,
          'sender_id': senderId,
          'created_at': createdAt,
          'conversation_id': conversationId,
        };

        // Store based on conversation type (you might need to determine this)
        // For now, we'll store in both and let the UI decide which to use
        await storeLastMessage(conversationId, messageData);
        await storeGroupLastMessage(conversationId, messageData);
      }
    } catch (e) {
      print('❌ Error updating last message from WebSocket: $e');
    }
  }
}
