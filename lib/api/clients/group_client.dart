import '../core/api_result.dart';
import '../core/base_api_client.dart';

/// Group API client
class GroupClient extends BaseApiClient {
  GroupClient({
    required super.dio,
    required super.cookieService,
    required super.authService,
  });

  /// Create a new group
  Future<ApiResult<dynamic>> createGroup({
    required String title,
    required List<String> memberIds,
  }) async {
    return post(
      '/chat/group/create-group',
      data: {'title': title, 'member_ids': memberIds},
    );
  }

  /// Get group list
  Future<ApiResult<dynamic>> getGroupList() async {
    return get('/chat/get-chat-list');
  }

  /// Add members to group
  Future<ApiResult<dynamic>> addMember({
    required String conversationId,
    required List<String> userIds,
    String role = 'member',
  }) async {
    return post(
      '/chat/group/add-members',
      data: {
        'conversation_id': conversationId,
        'user_ids': userIds,
        'role': role,
      },
    );
  }

  /// Remove member from group
  Future<ApiResult<dynamic>> removeMember({
    required String conversationId,
    required String userId,
  }) async {
    return delete(
      '/chat/group/remove-member',
      data: {'conversation_id': conversationId, 'user_id': userId},
    );
  }

  /// Update group title
  Future<ApiResult<dynamic>> updateGroupTitle({
    required String conversationId,
    required String title,
  }) async {
    return put(
      '/chat/group/update-group-title',
      data: {'conversation_id': conversationId, 'title': title},
    );
  }

  /// Delete group conversation
  Future<ApiResult<dynamic>> deleteGroup(
    String conversationId,
  ) async {
    return delete('/chat/soft-delete-chat/$conversationId');
  }

  /// Promote user to admin
  Future<ApiResult<dynamic>> promoteToAdmin({
    required String conversationId,
    required String userId,
  }) async {
    return post(
      '/chat/group/promote-to-admin',
      data: {'user_id': userId, 'conversation_id': conversationId},
    );
  }

  /// Demote admin to member
  Future<ApiResult<dynamic>> demoteToMember({
    required String conversationId,
    required String userId,
  }) async {
    return post(
      '/chat/group/demote-to-member',
      data: {'user_id': userId, 'conversation_id': conversationId},
    );
  }

  /// Get group info
  Future<ApiResult<dynamic>> getGroupInfo(
    String conversationId,
  ) async {
    return get('/chat/group/get-group-info/$conversationId');
  }
}
