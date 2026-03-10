import 'dart:io';

import '../core/api_result.dart';
import '../core/base_api_client.dart';
import '../../utils/serialization.utils.dart';

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

  /// Get conversation history
  Future<ApiResult<dynamic>> getConversationHistory({
    required int conversationId,
    int page = 1,
    int limit = 20,
  }) async {
    return get(
      '/chat/get-conversation-history/$conversationId?page=$page&limit=$limit',
    );
  }

  /// Get message statuses
  Future<ApiResult<dynamic>> getMessageStatuses({
    required int conversationId,
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
    List<int> messageIds, {
    bool? isAdminOrStaff,
  }) async {
    final body = <String, dynamic>{'message_ids': messageIds};
    if (isAdminOrStaff != null) {
      body['is_admin_or_staff'] = isAdminOrStaff;
    }
    final idsWithString = convertBigIntIdsToString(body);
    return delete('/message/soft-delete', data: idsWithString);
  }

  /// Delete message for me
  Future<ApiResult<dynamic>> deleteMessageForMe({
    required List<int> messageIds,
    required int conversationId,
  }) async {
    return delete(
      '/message/delete-for-me',
      data: {'message_ids': messageIds, 'conversation_id': conversationId},
    );
  }

  /// Delete DM conversation
  Future<ApiResult<dynamic>> deleteDm(int conversationId) async {
    return delete('/chat/dm/soft-delete-dm/$conversationId');
  }

  /// Revive chat
  Future<ApiResult<dynamic>> reviveChat(int conversationId) async {
    return post('/chat/revive-chat/$conversationId');
  }

  /// Mark message as delivered
  Future<ApiResult<dynamic>> markMessageDelivered({
    required int messageId,
    required int conversationId,
  }) async {
    return post(
      '/message/delivered',
      data: {
        'message_id': messageId.toString(),
        'conversation_id': conversationId,
      },
    );
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
    required int conversationId,
  }) async {
    return post('/message/verify-ids', data: {
      'message_ids': messageIds,
      'conversation_id': conversationId,
    });
  }
}
