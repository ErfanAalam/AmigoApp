import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../db/repositories/messages_repository.dart';
import '../../api/chats.services.dart';
import '../../services/socket/websocket_service.dart';
import '../../services/message_storage_service.dart';

/// Configuration for sending media messages
class SendMediaMessageConfig {
  final File mediaFile;
  final int conversationId;
  final int? currentUserId;
  final int optimisticMessageId;
  final MessageModel? replyToMessage;
  final int? replyToMessageId;
  final MessageModel? failedMessage; // For retry
  final String messageType; // 'image', 'video', 'document', 'audio'
  final String? fileName; // For documents
  final String? extension; // For documents
  final int? duration; // For audio
  final List<MessageModel> messages;
  final Set<int> optimisticMessageIds;
  final ConversationMeta? conversationMeta;
  final MessagesRepository messagesRepo;
  final ChatsServices chatsServices;
  final WebSocketService websocketService;
  final bool Function() mounted;
  final void Function(void Function()) setState;
  final void Function(MessageModel, String) handleMediaUploadFailure;
  final void Function(int) animateNewMessage;
  final void Function() scrollToBottom;
  final void Function()? cancelReply; // Optional, only if not retrying
  final bool isReplying;
  final BuildContext? context; // For closing modal (audio only)
  final void Function()? closeModal; // For closing voice recording modal

  SendMediaMessageConfig({
    required this.mediaFile,
    required this.conversationId,
    required this.currentUserId,
    required this.optimisticMessageId,
    this.replyToMessage,
    this.replyToMessageId,
    this.failedMessage,
    required this.messageType,
    this.fileName,
    this.extension,
    this.duration,
    required this.messages,
    required this.optimisticMessageIds,
    this.conversationMeta,
    required this.messagesRepo,
    required this.chatsServices,
    required this.websocketService,
    required this.mounted,
    required this.setState,
    required this.handleMediaUploadFailure,
    required this.animateNewMessage,
    required this.scrollToBottom,
    this.cancelReply,
    this.isReplying = false,
    this.context,
    this.closeModal,
  });
}

/// Send image message with retry support
Future<void> sendImageMessage(SendMediaMessageConfig config) async {
  // If this is a retry, use the failed message's reply data
  final actualReplyMessage =
      config.failedMessage?.replyToMessage ?? config.replyToMessage;
  final actualReplyMessageId =
      config.failedMessage?.replyToMessageId ?? config.replyToMessageId;

  // Clear reply state immediately for better UX (only if not retrying)
  if (config.isReplying &&
      config.failedMessage == null &&
      config.cancelReply != null) {
    config.cancelReply!();
  }

  MessageModel loadingMessage;
  bool isRetry = config.failedMessage != null;

  if (isRetry) {
    // Retry: Update existing failed message
    final index = config.messages.indexWhere(
      (msg) => msg.id == config.failedMessage!.id,
    );
    if (index == -1) return; // Message not found, can't retry

    // Update metadata to show retrying
    final updatedMetadata = Map<String, dynamic>.from(
      config.failedMessage!.metadata ?? {},
    );
    updatedMetadata['is_uploading'] = true;
    updatedMetadata['upload_failed'] = false;

    if (config.mounted()) {
      config.setState(() {
        config.messages[index] = config.failedMessage!.copyWith(
          metadata: updatedMetadata,
        );
      });
    }

    loadingMessage = config.messages[index];
  } else {
    // New send: Create new loading message
    loadingMessage = MessageModel(
      id: config.optimisticMessageId,
      conversationId: config.conversationId,
      senderId: config.currentUserId ?? 0,
      senderName: 'You',
      body: '',
      type: 'image',
      createdAt: DateTime.now().toIso8601String(),
      deleted: false,
      attachments: {'local_path': config.mediaFile.path},
      replyToMessageId: actualReplyMessageId,
      replyToMessage: actualReplyMessage,
      metadata: {
        'optimistic_id': config.optimisticMessageId,
        'is_uploading': true,
        'upload_failed': false,
      },
    );

    // Track this as an optimistic message
    config.optimisticMessageIds.add(config.optimisticMessageId);

    // Add loading message to UI immediately
    if (config.mounted()) {
      config.setState(() {
        config.messages.add(loadingMessage);
      });
      config.animateNewMessage(loadingMessage.id);
      config.scrollToBottom();
    }
  }

  try {
    final response = await config.chatsServices.sendMediaMessage(
      config.mediaFile,
    );

    if (response['success'] == true && response['data'] != null) {
      final mediaData = response['data'];

      // Update the loading message with actual data
      if (config.mounted()) {
        final index = config.messages.indexWhere(
          (msg) => msg.id == loadingMessage.id,
        );
        if (index != -1) {
          final currentMessage = config.messages[index];
          final updatedMetadata = Map<String, dynamic>.from(
            currentMessage.metadata ?? {},
          );
          updatedMetadata.remove('is_uploading');
          updatedMetadata.remove('upload_failed');

          config.setState(() {
            config.messages[index] = currentMessage.copyWith(
              metadata: updatedMetadata,
              attachments: mediaData,
            );
          });
        }
      }

      // Store in local storage
      final updatedMeta =
          config.conversationMeta?.copyWith() ??
          ConversationMeta(
            totalCount: config.messages.length,
            currentPage: 1,
            totalPages: 1,
            hasNextPage: false,
            hasPreviousPage: false,
          );

      final updatedIndex = config.messages.indexWhere(
        (msg) => msg.id == loadingMessage.id,
      );
      if (updatedIndex != -1) {
        await config.messagesRepo.addMessageToCache(
          conversationId: config.conversationId,
          newMessage: config.messages[updatedIndex],
          updatedMeta: updatedMeta,
          insertAtBeginning: false,
        );
      }

      // Send to websocket for real-time messaging
      await config.websocketService.sendMessage({
        'type': 'media',
        'data': {
          ...response['data'],
          'conversation_id': config.conversationId,
          'optimistic_id':
              loadingMessage.metadata?['optimistic_id'] ??
              config.optimisticMessageId,
          'reply_to_message_id': actualReplyMessageId,
        },
        'conversation_id': config.conversationId,
      });
    } else {
      config.handleMediaUploadFailure(
        loadingMessage,
        'Failed to upload image: ${response['message'] ?? 'Upload failed'}',
      );
    }
  } catch (e) {
    debugPrint('❌ Error sending image message: $e');
    config.handleMediaUploadFailure(
      loadingMessage,
      'Failed to send image. Please try again.',
    );
  }
}

/// Send video message with retry support
Future<void> sendVideoMessage(SendMediaMessageConfig config) async {
  // If this is a retry, use the failed message's reply data
  final actualReplyMessage =
      config.failedMessage?.replyToMessage ?? config.replyToMessage;
  final actualReplyMessageId =
      config.failedMessage?.replyToMessageId ?? config.replyToMessageId;

  // Clear reply state immediately for better UX (only if not retrying)
  if (config.isReplying &&
      config.failedMessage == null &&
      config.cancelReply != null) {
    config.cancelReply!();
  }

  MessageModel loadingMessage;
  bool isRetry = config.failedMessage != null;

  if (isRetry) {
    // Retry: Update existing failed message
    final index = config.messages.indexWhere(
      (msg) => msg.id == config.failedMessage!.id,
    );
    if (index == -1) return;

    final updatedMetadata = Map<String, dynamic>.from(
      config.failedMessage!.metadata ?? {},
    );
    updatedMetadata['is_uploading'] = true;
    updatedMetadata['upload_failed'] = false;

    if (config.mounted()) {
      config.setState(() {
        config.messages[index] = config.failedMessage!.copyWith(
          metadata: updatedMetadata,
        );
      });
    }

    loadingMessage = config.messages[index];
  } else {
    // New send: Create new loading message
    loadingMessage = MessageModel(
      id: config.optimisticMessageId,
      conversationId: config.conversationId,
      senderId: config.currentUserId ?? 0,
      senderName: 'You',
      body: '',
      type: 'video',
      createdAt: DateTime.now().toIso8601String(),
      deleted: false,
      attachments: {'local_path': config.mediaFile.path},
      replyToMessageId: actualReplyMessageId,
      replyToMessage: actualReplyMessage,
      metadata: {
        'optimistic_id': config.optimisticMessageId,
        'is_uploading': true,
        'upload_failed': false,
      },
    );

    config.optimisticMessageIds.add(config.optimisticMessageId);

    if (config.mounted()) {
      config.setState(() {
        config.messages.add(loadingMessage);
      });
      config.animateNewMessage(loadingMessage.id);
      config.scrollToBottom();
    }
  }

  try {
    final response = await config.chatsServices.sendMediaMessage(
      config.mediaFile,
    );

    if (response['success'] == true && response['data'] != null) {
      final mediaData = response['data'];

      if (config.mounted()) {
        final index = config.messages.indexWhere(
          (msg) => msg.id == loadingMessage.id,
        );
        if (index != -1) {
          final currentMessage = config.messages[index];
          final updatedMetadata = Map<String, dynamic>.from(
            currentMessage.metadata ?? {},
          );
          updatedMetadata.remove('is_uploading');
          updatedMetadata.remove('upload_failed');

          config.setState(() {
            config.messages[index] = currentMessage.copyWith(
              metadata: updatedMetadata,
              attachments: mediaData,
            );
          });
        }
      }

      final updatedMeta =
          config.conversationMeta?.copyWith() ??
          ConversationMeta(
            totalCount: config.messages.length,
            currentPage: 1,
            totalPages: 1,
            hasNextPage: false,
            hasPreviousPage: false,
          );

      final updatedIndex = config.messages.indexWhere(
        (msg) => msg.id == loadingMessage.id,
      );
      if (updatedIndex != -1) {
        await config.messagesRepo.addMessageToCache(
          conversationId: config.conversationId,
          newMessage: config.messages[updatedIndex],
          updatedMeta: updatedMeta,
          insertAtBeginning: false,
        );
      }

      await config.websocketService.sendMessage({
        'type': 'media',
        'data': {
          ...response['data'],
          'conversation_id': config.conversationId,
          'message_type': 'video',
          'optimistic_id':
              loadingMessage.metadata?['optimistic_id'] ??
              config.optimisticMessageId,
          'reply_to_message_id': actualReplyMessageId,
        },
        'conversation_id': config.conversationId,
      });
    } else {
      config.handleMediaUploadFailure(
        loadingMessage,
        'Failed to upload video: ${response['message'] ?? 'Upload failed'}',
      );
    }
  } catch (e) {
    debugPrint('❌ Error sending video message: $e');
    config.handleMediaUploadFailure(
      loadingMessage,
      'Failed to send video. Please try again.',
    );
  }
}

/// Send document message with retry support
Future<void> sendDocumentMessage(SendMediaMessageConfig config) async {
  // If this is a retry, use the failed message's reply data
  final actualReplyMessage =
      config.failedMessage?.replyToMessage ?? config.replyToMessage;
  final actualReplyMessageId =
      config.failedMessage?.replyToMessageId ?? config.replyToMessageId;

  // Clear reply state immediately for better UX (only if not retrying)
  if (config.isReplying &&
      config.failedMessage == null &&
      config.cancelReply != null) {
    config.cancelReply!();
  }

  MessageModel loadingMessage;
  bool isRetry = config.failedMessage != null;

  if (isRetry) {
    // Retry: Update existing failed message
    final index = config.messages.indexWhere(
      (msg) => msg.id == config.failedMessage!.id,
    );
    if (index == -1) return;

    final updatedMetadata = Map<String, dynamic>.from(
      config.failedMessage!.metadata ?? {},
    );
    updatedMetadata['is_uploading'] = true;
    updatedMetadata['upload_failed'] = false;

    if (config.mounted()) {
      config.setState(() {
        config.messages[index] = config.failedMessage!.copyWith(
          metadata: updatedMetadata,
        );
      });
    }

    loadingMessage = config.messages[index];
  } else {
    // New send: Create new loading message
    loadingMessage = MessageModel(
      id: config.optimisticMessageId,
      conversationId: config.conversationId,
      senderId: config.currentUserId ?? 0,
      senderName: 'You',
      body: '',
      type: 'docs',
      createdAt: DateTime.now().toIso8601String(),
      deleted: false,
      attachments: {
        'local_path': config.mediaFile.path,
        'file_name': config.fileName,
        'file_extension': config.extension,
        'category': 'docs',
      },
      replyToMessageId: actualReplyMessageId,
      replyToMessage: actualReplyMessage,
      metadata: {
        'optimistic_id': config.optimisticMessageId,
        'is_uploading': true,
        'upload_failed': false,
      },
    );

    config.optimisticMessageIds.add(config.optimisticMessageId);

    if (config.mounted()) {
      config.setState(() {
        config.messages.add(loadingMessage);
      });
      config.animateNewMessage(loadingMessage.id);
      config.scrollToBottom();
    }
  }

  try {
    final response = await config.chatsServices.sendMediaMessage(
      config.mediaFile,
    );

    if (response['success'] == true && response['data'] != null) {
      final mediaData = response['data'];

      if (config.mounted()) {
        final index = config.messages.indexWhere(
          (msg) => msg.id == loadingMessage.id,
        );
        if (index != -1) {
          final currentMessage = config.messages[index];
          final updatedMetadata = Map<String, dynamic>.from(
            currentMessage.metadata ?? {},
          );
          updatedMetadata.remove('is_uploading');
          updatedMetadata.remove('upload_failed');

          config.setState(() {
            config.messages[index] = currentMessage.copyWith(
              metadata: updatedMetadata,
              attachments: mediaData,
            );
          });
        }
      }

      final updatedMeta =
          config.conversationMeta?.copyWith() ??
          ConversationMeta(
            totalCount: config.messages.length,
            currentPage: 1,
            totalPages: 1,
            hasNextPage: false,
            hasPreviousPage: false,
          );

      final updatedIndex = config.messages.indexWhere(
        (msg) => msg.id == loadingMessage.id,
      );
      if (updatedIndex != -1) {
        await config.messagesRepo.addMessageToCache(
          conversationId: config.conversationId,
          newMessage: config.messages[updatedIndex],
          updatedMeta: updatedMeta,
          insertAtBeginning: false,
        );
      }

      await config.websocketService.sendMessage({
        'type': 'media',
        'data': {
          ...response['data'],
          'conversation_id': config.conversationId,
          'message_type': 'document',
          'optimistic_id':
              loadingMessage.metadata?['optimistic_id'] ??
              config.optimisticMessageId,
          'reply_to_message_id': actualReplyMessageId,
        },
        'conversation_id': config.conversationId,
      });
    } else {
      config.handleMediaUploadFailure(
        loadingMessage,
        'Failed to upload document: ${response['message'] ?? 'Upload failed'}',
      );
    }
  } catch (e) {
    debugPrint('❌ Error sending document message: $e');
    config.handleMediaUploadFailure(
      loadingMessage,
      'Failed to send document. Please try again.',
    );
  }
}

/// Send recorded voice message with retry support
Future<void> sendRecordedVoice(SendMediaMessageConfig config) async {
  File? voiceFile;
  int? duration;

  if (config.failedMessage != null) {
    // Retry: Get file info from failed message
    final attachments = config.failedMessage!.attachments;
    final localPath = attachments?['local_path'] as String?;
    duration = attachments?['duration'] as int?;

    if (localPath == null || !File(localPath).existsSync()) {
      if (config.context != null) {
        ScaffoldMessenger.of(config.context!).showSnackBar(
          const SnackBar(
            content: Text('Original recording not found. Please record again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    voiceFile = File(localPath);
  } else {
    // New send: Use the provided file
    voiceFile = config.mediaFile;
    duration = config.duration;
  }

  // If this is a retry, use the failed message's reply data
  final actualReplyMessage =
      config.failedMessage?.replyToMessage ?? config.replyToMessage;
  final actualReplyMessageId =
      config.failedMessage?.replyToMessageId ?? config.replyToMessageId;

  // Clear reply state immediately for better UX (only if not retrying)
  if (config.isReplying &&
      config.failedMessage == null &&
      config.cancelReply != null) {
    config.cancelReply!();
  }

  // Close modal only if not retrying
  if (config.failedMessage == null && config.closeModal != null) {
    config.closeModal!();
  }

  MessageModel loadingMessage;
  bool isRetry = config.failedMessage != null;

  if (isRetry) {
    // Retry: Update existing failed message
    final index = config.messages.indexWhere(
      (msg) => msg.id == config.failedMessage!.id,
    );
    if (index == -1) return;

    final updatedMetadata = Map<String, dynamic>.from(
      config.failedMessage!.metadata ?? {},
    );
    updatedMetadata['is_uploading'] = true;
    updatedMetadata['upload_failed'] = false;

    if (config.mounted()) {
      config.setState(() {
        config.messages[index] = config.failedMessage!.copyWith(
          metadata: updatedMetadata,
        );
      });
    }

    loadingMessage = config.messages[index];
  } else {
    // New send: Create loading message
    loadingMessage = MessageModel(
      id: config.optimisticMessageId,
      conversationId: config.conversationId,
      senderId: config.currentUserId ?? 0,
      senderName: 'You',
      body: '',
      type: 'audios',
      createdAt: DateTime.now().toIso8601String(),
      deleted: false,
      attachments: {
        'local_path': voiceFile.path,
        'duration': duration,
        'category': 'audios',
      },
      replyToMessageId: actualReplyMessageId,
      replyToMessage: actualReplyMessage,
      metadata: {
        'optimistic_id': config.optimisticMessageId,
        'is_uploading': true,
        'upload_failed': false,
      },
    );

    config.optimisticMessageIds.add(config.optimisticMessageId);

    if (config.mounted()) {
      config.setState(() {
        config.messages.add(loadingMessage);
      });
      config.animateNewMessage(loadingMessage.id);
      config.scrollToBottom();
    }
  }

  try {
    final response = await config.chatsServices.sendMediaMessage(voiceFile);

    if (response['success'] == true && response['data'] != null) {
      final mediaData = response['data'];

      if (config.mounted()) {
        final index = config.messages.indexWhere(
          (msg) => msg.id == loadingMessage.id,
        );
        if (index != -1) {
          final currentMessage = config.messages[index];
          final updatedMetadata = Map<String, dynamic>.from(
            currentMessage.metadata ?? {},
          );
          updatedMetadata.remove('is_uploading');
          updatedMetadata.remove('upload_failed');

          config.setState(() {
            config.messages[index] = currentMessage.copyWith(
              metadata: updatedMetadata,
              attachments: mediaData,
            );
          });
        }
      }

      final updatedMeta =
          config.conversationMeta?.copyWith() ??
          ConversationMeta(
            totalCount: config.messages.length,
            currentPage: 1,
            totalPages: 1,
            hasNextPage: false,
            hasPreviousPage: false,
          );

      final updatedIndex = config.messages.indexWhere(
        (msg) => msg.id == loadingMessage.id,
      );
      if (updatedIndex != -1) {
        await config.messagesRepo.addMessageToCache(
          conversationId: config.conversationId,
          newMessage: config.messages[updatedIndex],
          updatedMeta: updatedMeta,
          insertAtBeginning: false,
        );
      }

      await config.websocketService.sendMessage({
        'type': 'media',
        'data': {
          ...response['data'],
          'conversation_id': config.conversationId,
          'message_type': 'audio',
          'optimistic_id':
              loadingMessage.metadata?['optimistic_id'] ??
              config.optimisticMessageId,
          'reply_to_message_id': actualReplyMessageId,
        },
        'conversation_id': config.conversationId,
      });

      // Clean up - Only delete the temporary file if upload was successful and it's a new recording (not a retry)
      if (!isRetry && await voiceFile.exists()) {
        await voiceFile.delete();
      }
    } else {
      config.handleMediaUploadFailure(
        loadingMessage,
        'Failed to upload voice note: ${response['message'] ?? 'Upload failed'}',
      );
    }
  } catch (e) {
    config.handleMediaUploadFailure(
      loadingMessage,
      'Failed to send voice note. Please try again.',
    );
  }
}
