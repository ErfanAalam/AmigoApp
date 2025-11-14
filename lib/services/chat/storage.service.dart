import 'package:flutter/material.dart';

import '../../models/message_model.dart';
import '../../db/repositories/messages_repository.dart';

class ChatStorageService {
  // Singleton pattern
  static final ChatStorageService _instance = ChatStorageService._internal();
  factory ChatStorageService() => _instance;
  ChatStorageService._internal();

  final MessagesRepository _messagesRepo = MessagesRepository();

  // Method to synchronize chat data
  Future<void> storeMessageSqlite(
    int conversationId,
    Map<String, dynamic> message,
  ) async {
    // Run storage operation in background
    final cachedData = await _messagesRepo.getCachedMessages(conversationId);
    final conversationMeta = cachedData?.meta;

    final data = message['data'] as Map<String, dynamic>? ?? {};
    final messageBody = data['body'] as String? ?? '';
    final senderId = _parseToInt(data['sender_id'] ?? data['senderId']);
    final messageId = _parseToInt(data['id']);
    final optimisticId = _parseToInt(
      data['optimistic_id'] ?? data['optimisticId'],
    );
    final senderName = data['sender_name'] ?? 'Unknown User';

    // Handle reply message data
    MessageModel? replyToMessage;
    int? replyToMessageId;

    // Check for reply data in metadata first (server format)
    final metadata = data['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata['reply_to'] != null) {
      final replyToData = metadata['reply_to'] as Map<String, dynamic>;
      replyToMessageId = _parseToInt(replyToData['message_id']);

      // Create reply message from metadata
      replyToMessage = MessageModel(
        id: replyToMessageId,
        body: replyToData['body'] ?? '',
        type: 'text',
        senderId: _parseToInt(replyToData['sender_id']),
        conversationId: conversationId,
        createdAt: replyToData['created_at'] ?? '',
        deleted: false,
        senderName: replyToData['sender_name'] ?? 'Unknown User',
      );
    } else if (data['reply_to_message'] != null) {
      replyToMessage = MessageModel.fromJson(
        data['reply_to_message'] as Map<String, dynamic>,
      );
    } else if (data['reply_to_message_id'] != null) {
      replyToMessageId = _parseToInt(data['reply_to_message_id']);
      try {
        final existing = await _messagesRepo.getMessageById(replyToMessageId);
        if (existing != null) {
          replyToMessage = existing;
        }
      } catch (e) {
        debugPrint('⚠️ Reply message lookup failed: $e');
      }
    }
    // else if (data['reply_to_message_id'] != null) {
    //   replyToMessageId = _parseToInt(data['reply_to_message_id']);
    //   // Find the replied message in our local messages
    //   try {
    //     replyToMessage = _messages.firstWhere(
    //       (msg) => msg.id == replyToMessageId,
    //     );
    //   } catch (e) {
    //     debugPrint(
    //       '⚠️ Reply message not found in local messages: $replyToMessageId',
    //     );
    //   }
    // }
    // If we have an optimistic_id from the server echo, reconcile the
    // previously stored optimistic message instead of inserting a duplicate.
    // This handles the case when the conversation screen is not open to run
    // the in-UI reconciliation, preventing temporary duplicates on open.
    if (optimisticId != 0 && messageId != 0) {
      try {
        final updated = await _messagesRepo.updateOptimisticMessage(
          conversationId,
          optimisticId,
          messageId,
          message,
        );

        // Only return early if reconciliation really happened
        if (updated != null) {
          // Also keep conversation meta fresh if available
          if (conversationMeta != null) {
            await _messagesRepo.saveConversationMeta(
              conversationId,
              conversationMeta.copyWith(
                totalCount: conversationMeta.totalCount,
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('❌ Error reconciling optimistic message: $e');
      }
    }

    final newMessage = MessageModel(
      id: messageId,
      body: messageBody,
      type: data['type'] ?? 'text',
      senderId: senderId,
      conversationId: conversationId,
      createdAt:
          data['created_at'] ??
          DateTime.now().toUtc().toIso8601String(), // Store as UTC
      editedAt: data['edited_at'],
      metadata: data['metadata'],
      attachments: data['attachments'],
      deleted: data['deleted'] == true,
      senderName: senderName,
      replyToMessage: replyToMessage,
      replyToMessageId: replyToMessageId,
    );
    try {
      if (conversationMeta != null) {
        await _messagesRepo.addMessageToCache(
          conversationId: conversationId,
          newMessage: newMessage,
          updatedMeta: conversationMeta.copyWith(
            totalCount: conversationMeta.totalCount + 1,
          ),
          insertAtBeginning: false, // Add new messages at the end
        );

        // Debug reply message storage
        // if (message.replyToMessage != null) {
        //   debugPrint(
        //     '💾 Reply message stored: ${message.id} -> ${message.replyToMessage!.id} (${message.replyToMessage!.senderName})',
        //   );
        // } else {
        //   debugPrint('💾 Regular message stored: ${message.id}');
        // }

        // Validate reply message storage periodically
        if (newMessage.replyToMessage != null) {
          await _messagesRepo.validateReplyMessageStorage(conversationId);
        }
      }
    } catch (e) {
      debugPrint('❌ Error storing message asynchronously');
    }
  }

  Future<void> storeMediaMessageSqlite(
    int conversationId,
    Map<String, dynamic> message,
  ) async {
    final cachedData = await _messagesRepo.getCachedMessages(conversationId);
    final conversationMeta = cachedData?.meta;

    final data = message['data'] as Map<String, dynamic>? ?? {};
    final senderId = _parseToInt(data['sender_id'] ?? data['senderId']);
    final messageId = _parseToInt(
      data['id'] ?? data['message_id'] ?? data['media_message_id'],
    );
    final optimisticId = _parseToInt(
      data['optimistic_id'] ?? data['optimisticId'],
    );
    final senderName = data['sender_name'] ?? 'Unknown User';

    // Attempt reconciliation first if optimistic -> server IDs present
    if (optimisticId != 0 && messageId != 0) {
      try {
        final updated = await _messagesRepo.updateOptimisticMessage(
          conversationId,
          optimisticId,
          messageId,
          message,
        );
        if (updated != null) {
          if (conversationMeta != null) {
            await _messagesRepo.saveConversationMeta(
              conversationId,
              conversationMeta.copyWith(
                totalCount: conversationMeta.totalCount,
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('❌ Error reconciling optimistic media message: $e');
      }
    }

    // Build media message
    final attachments = data['attachments'] as Map<String, dynamic>?;
    final messageType = data['type'] ?? attachments?['type'] ?? 'media';

    // Optionally include reply info for media replies
    MessageModel? replyToMessage;
    int? replyToMessageId;
    final metadata = data['metadata'] as Map<String, dynamic>?;
    if (metadata != null && metadata['reply_to'] != null) {
      final replyToData = metadata['reply_to'] as Map<String, dynamic>;
      replyToMessageId = _parseToInt(replyToData['message_id']);
      replyToMessage = MessageModel(
        id: replyToMessageId,
        body: replyToData['body'] ?? '',
        type: replyToData['type'] ?? 'text',
        senderId: _parseToInt(replyToData['sender_id']),
        conversationId: conversationId,
        createdAt: replyToData['created_at'] ?? '',
        deleted: false,
        senderName: replyToData['sender_name'] ?? 'Unknown User',
      );
    } else if (data['reply_to_message_id'] != null) {
      replyToMessageId = _parseToInt(data['reply_to_message_id']);
      try {
        final existing = await _messagesRepo.getMessageById(replyToMessageId);
        if (existing != null) replyToMessage = existing;
      } catch (_) {}
    }

    final newMessage = MessageModel(
      id: messageId,
      body: data['body'] ?? '',
      type: messageType,
      senderId: senderId,
      conversationId: conversationId,
      createdAt: data['created_at'] ?? DateTime.now().toUtc().toIso8601String(),
      editedAt: data['edited_at'],
      metadata: data['metadata'],
      attachments: attachments,
      deleted: data['deleted'] == true,
      senderName: senderName,
      replyToMessage: replyToMessage,
      replyToMessageId: replyToMessageId,
    );

    try {
      if (conversationMeta != null) {
        await _messagesRepo.addMessageToCache(
          conversationId: conversationId,
          newMessage: newMessage,
          updatedMeta: conversationMeta.copyWith(
            totalCount: conversationMeta.totalCount + 1,
          ),
          insertAtBeginning: false,
        );

        if (newMessage.replyToMessage != null) {
          await _messagesRepo.validateReplyMessageStorage(conversationId);
        }
      }
    } catch (e) {
      debugPrint('❌ Error storing media message asynchronously');
    }
  }

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
