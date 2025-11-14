import 'package:flutter/material.dart';
import '../db/repositories/messages_repository.dart';
import '../models/message_model.dart';

class MessageStorageHelpers {
  static final MessagesRepository _messagesRepo = MessagesRepository();

  /// Load pinned message from storage for a conversation
  static Future<int?> loadPinnedMessageFromStorage(int conversationId) async {
    try {
      // Try local DB first
      final pinnedMessageId = await _messagesRepo.getPinnedMessage(
        conversationId,
      );

      if (pinnedMessageId != null) {
        debugPrint('📌 Loaded pinned message $pinnedMessageId from local DB');
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
      // Try local DB first
      final starredMessages = await _messagesRepo.getStarredMessages(
        conversationId,
      );

      if (starredMessages.isNotEmpty) {
        debugPrint(
          '⭐ Loaded ${starredMessages.length} starred messages from local DB',
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
      // Use local DB repository
      return await _messagesRepo.updateOptimisticMessage(
        conversationId,
        optimisticId,
        serverId,
        messageData,
      );
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
