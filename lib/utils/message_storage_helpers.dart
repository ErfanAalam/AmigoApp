import 'package:flutter/material.dart';
import '../services/message_storage_service.dart';
import '../models/message_model.dart';

class MessageStorageHelpers {
  static final MessageStorageService _storageService = MessageStorageService();

  /// Load pinned message from storage for a conversation
  static Future<int?> loadPinnedMessageFromStorage(int conversationId) async {
    try {
      final pinnedMessageId = await _storageService.getPinnedMessage(
        conversationId,
      );

      if (pinnedMessageId != null) {
        debugPrint('📌 Loaded pinned message $pinnedMessageId from storage');
        return pinnedMessageId;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error loading pinned message from storage: $e');
      return null;
    }
  }

  /// Load starred messages from storage for a conversation
  static Future<Set<int>> loadStarredMessagesFromStorage(
    int conversationId,
  ) async {
    try {
      final starredMessages = await _storageService.getStarredMessages(
        conversationId,
      );

      if (starredMessages.isNotEmpty) {
        debugPrint(
          '⭐ Loaded ${starredMessages.length} starred messages from storage',
        );
        return starredMessages;
      }
      return <int>{};
    } catch (e) {
      debugPrint('❌ Error loading starred messages from storage: $e');
      return <int>{};
    }
  }

  /// Update optimistic message in local storage with server ID (for sender's own messages)
  /// Returns the updated message if successful, null otherwise
  static Future<MessageModel?> updateOptimisticMessageInStorage(
    int conversationId,
    int? optimisticId,
    int? serverId,
    Map<String, dynamic> messageData,
  ) async {
    if (optimisticId == null || serverId == null) return null;

    try {
      // Get current cached messages
      final cachedData = await _storageService.getCachedMessages(
        conversationId,
      );

      if (cachedData == null || cachedData.messages.isEmpty) {
        debugPrint('⚠️ No cached messages found to update');
        return null;
      }

      // Find the optimistic message in cached data
      final messageIndex = cachedData.messages.indexWhere(
        (msg) => msg.id == optimisticId,
      );

      if (messageIndex == -1) {
        debugPrint('⚠️ Optimistic message $optimisticId not found in cache');
        return null;
      }

      // Create updated message with server ID
      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final originalMessage = cachedData.messages[messageIndex];

      // Handle reply messages specifically
      final messageType = messageData['type'];
      String messageBody;

      if (messageType == 'message_reply') {
        // For reply messages, use new_message as the body
        messageBody = data['new_message'] ?? originalMessage.body;
      } else {
        messageBody = data['body'] ?? originalMessage.body;
      }

      final updatedMessage = MessageModel(
        id: serverId, // Use server ID instead of optimistic ID
        body: messageBody,
        type: data['type'] ?? originalMessage.type,
        senderId: originalMessage.senderId,
        conversationId: originalMessage.conversationId,
        createdAt:
            data['created_at'] ??
            messageData['timestamp'] ??
            originalMessage.createdAt,
        editedAt: data['edited_at'] ?? originalMessage.editedAt,
        metadata: data['metadata'] ?? originalMessage.metadata,
        attachments: data['attachments'] ?? originalMessage.attachments,
        deleted: data['deleted'] == true,
        senderName: originalMessage.senderName,
        senderProfilePic: originalMessage.senderProfilePic,
        replyToMessage:
            originalMessage.replyToMessage, // Preserve reply relationship
        replyToMessageId: originalMessage.replyToMessageId,
      );

      // Update the message in the cached messages list
      final updatedMessages = List<MessageModel>.from(cachedData.messages);
      updatedMessages[messageIndex] = updatedMessage;

      // Save updated messages back to storage
      await _storageService.saveMessages(
        conversationId: conversationId,
        messages: updatedMessages,
        meta: cachedData.meta,
      );

      debugPrint(
        '✅ Updated message ID from $optimisticId to $serverId in local storage',
      );

      return updatedMessage;
    } catch (e) {
      debugPrint('❌ Error updating optimistic message in storage: $e');
      return null;
    }
  }

  /// Create confirmed message from optimistic message data
  /// Returns the confirmed message model
  static MessageModel createConfirmedMessage(
    int messageId,
    Map<String, dynamic> messageData,
    MessageModel originalMessage,
    Map<String, String?> senderInfo,
  ) {
    final data = messageData['data'] as Map<String, dynamic>? ?? {};
    final senderId = data['sender_id'] != null
        ? _parseToInt(data['sender_id'])
        : originalMessage.senderId;

    final senderName = senderInfo['name'] ?? originalMessage.senderName;
    final senderProfilePic =
        senderInfo['profile_pic'] ?? originalMessage.senderProfilePic;

    return MessageModel(
      id: data['id'] ?? data['messageId'] ?? messageId,
      body: data['body'] ?? originalMessage.body,
      type: data['type'] ?? originalMessage.type,
      senderId: senderId,
      conversationId: originalMessage.conversationId,
      createdAt: data['created_at'] ?? originalMessage.createdAt,
      editedAt: data['edited_at'],
      metadata: data['metadata'],
      attachments: data['attachments'],
      deleted: data['deleted'] == true,
      senderName: senderName,
      senderProfilePic: senderProfilePic,
      replyToMessage:
          originalMessage.replyToMessage, // Preserve reply relationship
      replyToMessageId: originalMessage.replyToMessageId,
    );
  }

  /// Parse dynamic value to int
  static int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
