import 'package:flutter/material.dart';
import '../../models/conversation_model.dart';
import '../../api/user.service.dart';
import '../../services/socket/websocket_service.dart';

/// Configuration for loading available conversations
class LoadAvailableConversationsConfig {
  final UserService userService;
  final int currentConversationId;
  final Function(bool) setIsLoading;
  final Function(List<ConversationModel>) setAvailableConversations;
  final bool mounted;
  final Function(String) showErrorDialog;
  final String? debugPrefix;

  LoadAvailableConversationsConfig({
    required this.userService,
    required this.currentConversationId,
    required this.setIsLoading,
    required this.setAvailableConversations,
    required this.mounted,
    required this.showErrorDialog,
    this.debugPrefix,
  });
}

/// Load available conversations for forwarding (excluding current conversation)
Future<void> loadAvailableConversations(
  LoadAvailableConversationsConfig config,
) async {
  config.setIsLoading(true);

  try {
    final response = await config.userService.GetChatList('all');

    if (response['success'] == true && response['data'] != null) {
      final dynamic responseData = response['data'];
      List<dynamic> conversationsList = [];

      if (responseData is List) {
        conversationsList = responseData;
      } else if (responseData is Map<String, dynamic>) {
        if (responseData.containsKey('data') && responseData['data'] is List) {
          conversationsList = responseData['data'] as List<dynamic>;
        } else {
          for (var key in responseData.keys) {
            if (responseData[key] is List) {
              conversationsList = responseData[key] as List<dynamic>;
              break;
            }
          }
        }
      }

      if (conversationsList.isNotEmpty) {
        final conversations = <ConversationModel>[];

        for (int i = 0; i < conversationsList.length; i++) {
          final json = conversationsList[i];
          try {
            final conversation = ConversationModel.fromJson(
              json as Map<String, dynamic>,
            );
            // Exclude current conversation
            if (conversation.id != config.currentConversationId) {
              conversations.add(conversation);
            } else {
              final prefix = config.debugPrefix != null
                  ? '${config.debugPrefix} '
                  : '';
              debugPrint(
                '🚫 $prefix Forward modal - Excluding current conversation: ${conversation.id}',
              );
            }
          } catch (e) {
            final prefix = config.debugPrefix != null
                ? '${config.debugPrefix} '
                : '';
            debugPrint('⚠️ $prefix Error parsing conversation $i: $e');
            continue;
          }
        }

        config.setAvailableConversations(conversations);
      }
    }
  } catch (e) {
    final prefix = config.debugPrefix != null ? '${config.debugPrefix} ' : '';
    debugPrint('❌ ${prefix}Error loading conversations for forward: $e');
    if (config.mounted) {
      config.showErrorDialog('Failed to load conversations. Please try again.');
    }
  } finally {
    if (config.mounted) {
      config.setIsLoading(false);
    }
  }
}

/// Configuration for handling forward to conversations
class HandleForwardToConversationsConfig {
  final Set<int> messagesToForward;
  final List<int> selectedConversationIds;
  final WebSocketService websocketService;
  final int currentUserId;
  final int sourceConversationId;
  final BuildContext context;
  final bool mounted;
  final Function(Set<int>) clearMessagesToForward;
  final Function(String) showErrorDialog;
  final String? debugPrefix;

  HandleForwardToConversationsConfig({
    required this.messagesToForward,
    required this.selectedConversationIds,
    required this.websocketService,
    required this.currentUserId,
    required this.sourceConversationId,
    required this.context,
    required this.mounted,
    required this.clearMessagesToForward,
    required this.showErrorDialog,
    this.debugPrefix,
  });
}

/// Handle forwarding messages to selected conversations
Future<void> handleForwardToConversations(
  HandleForwardToConversationsConfig config,
) async {
  if (config.messagesToForward.isEmpty ||
      config.selectedConversationIds.isEmpty) {
    return;
  }

  try {
    // Send WebSocket message for forwarding
    await config.websocketService.sendMessage({
      'type': 'message_forward',
      'data': {
        'user_id': config.currentUserId,
        'source_conversation_id': config.sourceConversationId,
        'target_conversation_ids': config.selectedConversationIds,
      },
      'message_ids': config.messagesToForward.toList(),
    });

    // Show success message
    if (config.mounted) {
      ScaffoldMessenger.of(config.context).showSnackBar(
        SnackBar(
          content: Text(
            'Forwarded ${config.messagesToForward.length} message${config.messagesToForward.length > 1 ? 's' : ''} to ${config.selectedConversationIds.length} chat${config.selectedConversationIds.length > 1 ? 's' : ''}',
          ),
          backgroundColor: Colors.green[600],
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Clear forward state
    config.clearMessagesToForward(config.messagesToForward);
  } catch (e) {
    final prefix = config.debugPrefix != null ? '${config.debugPrefix} ' : '';
    debugPrint('❌ ${prefix}Error forwarding messages: $e');
    if (config.mounted) {
      config.showErrorDialog('Failed to forward messages. Please try again.');
    }
  }
}
