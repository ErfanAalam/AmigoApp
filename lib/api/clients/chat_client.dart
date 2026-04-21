import 'dart:io';

import '../core/api_result.dart';
import '../core/base_api_client.dart';

/// Chat API client
class ChatClient extends BaseApiClient {
  ChatClient({
    required super.dio,
    required super.cookieService,
    required super.authService,
  });

  /// Create a new DM chat
  Future<ApiResult<dynamic>> createChat(String receiverId) async {
    return post('/chat/dm/create-dm/$receiverId');
  }

  /// Get conversation history (cursor-based pagination)
  Future<ApiResult<dynamic>> getConversationHistory({
    required String conversationId,
    int limit = 20,
    String? beforeMessageId,
    String? afterMessageId,
  }) async {
    var path = '/chat/get-conversation-history/$conversationId?limit=$limit';
    if (beforeMessageId != null) path += '&before_message_id=$beforeMessageId';
    if (afterMessageId  != null) path += '&after_message_id=$afterMessageId';
    return get(path);
  }

  /// Get messages around a specific message (for jump-to-message)
  Future<ApiResult<dynamic>> getMessagesAround({
    required String conversationId,
    required String messageId,
    int before = 50,
    int after  = 50,
  }) async {
    return get(
      '/chat/get-messages-around/$conversationId/$messageId?before=$before&after=$after',
    );
  }

  /// Get chat members (called once on first chat load)
  Future<ApiResult<dynamic>> getChatMembers({
    required String conversationId,
  }) async {
    return get('/chat/get-chat-members/$conversationId');
  }

  /// Get message statuses
  Future<ApiResult<dynamic>> getMessageStatuses({
    required String conversationId,
    int page = 1,
    int limit = 1000,
  }) async {
    return get(
      '/chat/get-message-statuses/$conversationId?page=$page&limit=$limit',
    );
  }

  /// Send media message
  Future<ApiResult<dynamic>> sendMediaMessage(
    File file, {
    Function(int sent, int total)? onSendProgress,
  }) async {
    return uploadMedia(file: file, onSendProgress: onSendProgress);
  }

  /// Delete messages
  Future<ApiResult<dynamic>> deleteMessage(
    List<String> messageIds, {
    bool? isAdminOrStaff,
  }) async {
    final body = <String, dynamic>{'message_ids': messageIds};
    if (isAdminOrStaff != null) {
      body['is_admin_or_staff'] = isAdminOrStaff;
    }
    return delete('/message/soft-delete', data: body);
  }

  /// Delete message for me
  Future<ApiResult<dynamic>> deleteMessageForMe({
    required List<String> messageIds,
    required String conversationId,
  }) async {
    return delete(
      '/message/delete-for-me',
      data: {'message_ids': messageIds, 'conversation_id': conversationId},
    );
  }

  /// Delete DM conversation
  Future<ApiResult<dynamic>> deleteDm(String conversationId) async {
    return delete('/chat/dm/soft-delete-dm/$conversationId');
  }

  /// Revive chat
  Future<ApiResult<dynamic>> reviveChat(String conversationId) async {
    return post('/chat/revive-chat/$conversationId');
  }

  /// Mark message as delivered
  Future<ApiResult<dynamic>> markMessageDelivered({
    required String messageId,
    required String conversationId,
  }) async {
    return post(
      '/message/delivered',
      data: {
        'message_id': messageId,
        'conversation_id': conversationId,
      },
    );
  }

  /// Send batched status acknowledgements via HTTP fallback
  Future<ApiResult<dynamic>> sendStatusAck(
      Map<String, dynamic> payload) async {
    return post('/message/status-ack', data: payload);
  }

  /// Sync messages via polling
  Future<ApiResult<dynamic>> syncMessageViaPolling() async {
    return get('/chat/poll/sync-messages-via-polling');
  }

  /// Poll pending messages
  Future<ApiResult<dynamic>> pollPendingMessages({
    String? afterMessageId,
    bool? forSync,
  }) async {
    var path = '/chat/poll/poll-pending-messages';
    if (afterMessageId != null) {
      path += '?after_message_id=${Uri.encodeComponent(afterMessageId)}';
    }
    if (forSync != null && forSync) {
      path += '?for_sync=true';
    }
    return get(path);
  }

  /// Verify which of the given message IDs the server has (GC reconciliation).
  Future<ApiResult<dynamic>> verifyMessageIds({
    required List<String> messageIds,
    required String conversationId,
  }) async {
    return post('/message/verify-ids', data: {
      'message_ids': messageIds,
      'conversation_id': conversationId,
    });
  }

  /// React / un-react to a message with an emoji.
  Future<ApiResult<dynamic>> reactToMessage({
    required String messageId,
    required String conversationId,
    required String emoji,
    required String action, // 'add' | 'remove'
    String? senderName,
  }) async {
    return post('/message/react', data: {
      'message_id': messageId,
      'conversation_id': conversationId,
      'emoji': emoji,
      'action': action,
      if (senderName != null) 'sender_name': senderName,
    });
  }
}
