import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../repositories/messages_repository.dart';

/// Configuration for isMediaMessage function
/// (No config needed, just the message)

/// Check if a message is a media message
bool isMediaMessage(MessageModel message) {
  // Check type first
  if (message.type == 'image' ||
      message.type == 'video' ||
      message.type == 'attachment' ||
      message.type == 'docs' ||
      message.type == 'audio' ||
      message.type == 'audios' ||
      message.type == 'media') {
    return true;
  }

  // Also check attachments category as fallback
  if (message.attachments != null) {
    final attachmentData = message.attachments as Map<String, dynamic>;
    final category = attachmentData['category'] as String?;
    if (category != null) {
      final categoryLower = category.toLowerCase();
      return categoryLower == 'images' ||
          categoryLower == 'videos' ||
          categoryLower == 'docs' ||
          categoryLower == 'audios';
    }
  }

  return false;
}

/// Configuration for handleMessagePin function
class HandleMessagePinConfig {
  final Map<String, dynamic> message;
  final int conversationId;
  final bool Function() mounted;
  final void Function(VoidCallback) setState;
  final int? Function() getPinnedMessageId;
  final void Function(int?) setPinnedMessageId;
  final MessagesRepository messagesRepo;

  HandleMessagePinConfig({
    required this.message,
    required this.conversationId,
    required this.mounted,
    required this.setState,
    required this.getPinnedMessageId,
    required this.setPinnedMessageId,
    required this.messagesRepo,
  });
}

/// Handle incoming message pin from WebSocket
Future<void> handleMessagePin(HandleMessagePinConfig config) async {
  final data = config.message['data'] as Map<String, dynamic>? ?? {};
  // Get message ID from message_ids array
  final messageIds = config.message['message_ids'] as List<dynamic>? ?? [];
  final messageId = messageIds.isNotEmpty ? messageIds[0] as int? : null;
  final action = data['action'] ?? 'pin';

  int? newPinnedMessageId;
  if (action == 'pin') {
    newPinnedMessageId = messageId;
  } else {
    newPinnedMessageId = null;
  }

  if (config.mounted()) {
    config.setState(() {
      config.setPinnedMessageId(newPinnedMessageId);
    });
  }

  // Save to local storage
  await config.messagesRepo.savePinnedMessage(
    conversationId: config.conversationId,
    pinnedMessageId: newPinnedMessageId,
  );
}

/// Configuration for handleMessageStar function
class HandleMessageStarConfig {
  final Map<String, dynamic> message;
  final bool Function() mounted;
  final void Function(VoidCallback) setState;
  final Set<int> starredMessages;
  final MessagesRepository messagesRepo;

  HandleMessageStarConfig({
    required this.message,
    required this.mounted,
    required this.setState,
    required this.starredMessages,
    required this.messagesRepo,
  });
}

/// Handle incoming message star from WebSocket
Future<void> handleMessageStar(HandleMessageStarConfig config) async {
  final data = config.message['data'] as Map<String, dynamic>? ?? {};
  final messagesIds = config.message['message_ids'] as List<int>? ?? [];
  final action = data['action'] ?? 'star';

  if (config.mounted()) {
    config.setState(() {
      if (action == 'star') {
        config.starredMessages.addAll(messagesIds);
      } else {
        config.starredMessages.removeAll(messagesIds);
      }
    });
  }

  // Save to local storage
  try {
    for (final messageId in messagesIds) {
      if (action == 'star') {
        await config.messagesRepo.starMessage(messageId);
      } else {
        await config.messagesRepo.unstarMessage(messageId);
      }
    }
  } catch (e) {
    debugPrint(
      '❌ Error updating starred messages from WebSocket in storage: $e',
    );
  }
}

/// Configuration for handleMessageDelete function
class HandleMessageDeleteConfig {
  final Map<String, dynamic> message;
  final bool Function() mounted;
  final void Function(VoidCallback) setState;
  final List<MessageModel> messages;
  final int conversationId;
  final MessagesRepository messagesRepo;

  HandleMessageDeleteConfig({
    required this.message,
    required this.mounted,
    required this.setState,
    required this.messages,
    required this.conversationId,
    required this.messagesRepo,
  });
}

/// Handle message delete event from WebSocket
Future<void> handleMessageDelete(HandleMessageDeleteConfig config) async {
  try {
    final messageIds = config.message['message_ids'] as List<dynamic>? ?? [];
    if (messageIds.isEmpty) return;

    final deletedMessageIds = messageIds.map((id) => id as int).toList();

    // Remove from UI
    if (config.mounted()) {
      config.setState(() {
        config.messages.removeWhere(
          (msg) => deletedMessageIds.contains(msg.id),
        );
      });
    }

    // Remove from local storage cache
    await config.messagesRepo.removeMessageFromCache(
      conversationId: config.conversationId,
      messageIds: deletedMessageIds,
    );
  } catch (e) {
    debugPrint('❌ Error handling message delete event: $e');
  }
}
