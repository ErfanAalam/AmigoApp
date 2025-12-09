import 'package:amigo/types/socket.types.dart';
import 'package:flutter/material.dart';

import '../../services/socket/websocket.service.dart';
import '../../ui/snackbar.dart';

/// Configuration for handling forward to conversations
class HandleForwardToConversationsConfig {
  final Set<int> messagesToForward;
  final List<int> selectedConversationIds;
  // final WebSocketService websocketService;
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
    // required this.websocketService,
    required this.currentUserId,
    required this.sourceConversationId,
    required this.context,
    required this.mounted,
    required this.clearMessagesToForward,
    required this.showErrorDialog,
    this.debugPrefix,
  });
}

final WebSocketService websocketService = WebSocketService();

/// Handle forwarding messages to selected conversations
Future<void> handleForwardToConversations(
  HandleForwardToConversationsConfig config,
) async {
  if (config.messagesToForward.isEmpty ||
      config.selectedConversationIds.isEmpty) {
    return;
  }

  try {
    final forwardMessagePayload = MessageForwardPayload(
      sourceConvId: config.sourceConversationId,
      forwarderId: config.currentUserId,
      forwardedMessageIds: config.messagesToForward.toList(),
      targetConvIds: config.selectedConversationIds,
    ).toJson();

    final wsmsg = WSMessage(
      type: WSMessageType.messageForward,
      payload: forwardMessagePayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    websocketService.sendMessage(wsmsg).catchError((e) {
      debugPrint('❌ Error sending message forward');
    });

    // Show success message
    if (config.mounted) {
      Snack.success(
        'Forwarded ${config.messagesToForward.length} message${config.messagesToForward.length > 1 ? 's' : ''} to ${config.selectedConversationIds.length} chat${config.selectedConversationIds.length > 1 ? 's' : ''}',
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
