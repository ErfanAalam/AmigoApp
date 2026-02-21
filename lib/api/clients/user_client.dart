import '../core/api_result.dart';
import '../core/base_api_client.dart';

/// User API client
class UserClient extends BaseApiClient {
  UserClient({
    required super.dio,
    required super.cookieService,
    required super.authService,
  });

  /// Get current user
  Future<ApiResult<dynamic>> getUser() async {
    return get('/user/get-user');
  }

  /// Get available users from phone numbers
  Future<ApiResult<dynamic>> getAvailableUsers(
    List<String> phoneNumbers,
  ) async {
    return post(
      '/user/get-available-users',
      data: {'phone_numbers': phoneNumbers},
    );
  }

  /// Get chat list by type
  Future<ApiResult<dynamic>> getChatList(String type) async {
    return await get('/chat/get-chat-list/$type');
  }

  /// Get community chat list
  Future<ApiResult<dynamic>> getCommunityChatList() async {
    return get('/community/list-connected-communities');
  }

  /// Update user information
  Future<ApiResult<dynamic>> updateUser(Map<String, dynamic> data) async {
    return post('/user/update-user', data: data);
  }

  /// Fetch user call history
  Future<ApiResult<dynamic>> getCallHistory(int limit) async {
    return get('/call/history?limit=$limit');
  }
}
