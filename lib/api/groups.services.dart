import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:amigo/api/api_service.dart';

class GroupsService {
  final ApiService _apiService = ApiService();

  // Create a new group
  Future<Map<String, dynamic>> createGroup(
    String title,
    List<int> memberIds,
  ) async {
    try {
      final response = await _apiService.authenticatedPost(
        '/chat/create-group',
        data: {'title': title, 'member_ids': memberIds},
      );

      if (response.data is String) {
        return jsonDecode(response.data as String);
      }
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to create group: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create group',
      };
    }
  }

  // Get list of groups for current user
  Future<Map<String, dynamic>> getGroupList() async {
    try {
      final response = await _apiService.authenticatedGet(
        '/chat/get-chat-list',
      );

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'data': response.data,
        'message': 'Groups retrieved successfully',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to get groups: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get groups',
      };
    }
  }

  // Add member to group
  Future<Map<String, dynamic>> addMember(
    int conversationId,
    List<int> userIds, {
    String role = 'member',
  }) async {
    try {
      print('userIds: $userIds');
      print('conversationId: $conversationId');
      print('role: $role');

      final response = await _apiService.authenticatedPost(
        '/chat/add-members',
        data: {
          'conversation_id': conversationId,
          'user_ids': userIds,
          'role': role,
        },
      );

      print('response: $response');

      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to add member: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to add member',
      };
    }
  }

  // Remove member from group
  Future<Map<String, dynamic>> removeMember(
    int conversationId,
    int userId,
  ) async {
    try {
      final response = await _apiService.authenticatedDelete(
        '/chat/remove-member',
        body: {'conversation_id': conversationId, 'user_id': userId},
      );

      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to remove member: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to remove member',
      };
    }
  }

  // Update group title
  Future<Map<String, dynamic>> updateGroupTitle(
    int conversationId,
    String title,
  ) async {
    try {
      final response = await _apiService.authenticatedPut(
        '/chat/update-group-title',
        data: {'conversation_id': conversationId, 'title': title},
      );

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'data': response.data,
        'message': 'Group title updated successfully',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to update group title: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update group title',
      };
    }
  }

  // Get group conversation history
  Future<Map<String, dynamic>> getGroupConversationHistory({
    required int conversationId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiService.authenticatedGet(
        '/chat/get-conversation-history/$conversationId?page=$page&limit=$limit',
      );

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'data': response.data,
        'message': 'Group conversation history retrieved successfully',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to get group conversation history: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get group conversation history',
      };
    }
  }

  // Delete group conversation
  Future<Map<String, dynamic>> deleteGroup(int conversationId) async {
    try {
      final response = await _apiService.authenticatedDelete(
        '/chat/soft-delete-chat/$conversationId',
      );

      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to delete group: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete group',
      };
    }
  }

  // Delete group conversation
  Future<Map<String, dynamic>> promoteToAdmin(
    int conversationId,
    int userId,
  ) async {
    print('group promote to admin request: $conversationId, $userId');
    try {
      final response = await _apiService.authenticatedPost(
        '/chat/promote-to-admin',
        data: {'user_id': userId, 'conversation_id': conversationId},
      );

      print('group promote to admin response: $response');

      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to make admin: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to make admin',
      };
    }
  }

  Future<Map<String, dynamic>> demoteToAdmin(
    int conversationId,
    int userId,
  ) async {
    try {
      final response = await _apiService.authenticatedPost(
        '/chat/demote-to-member',
        data: {'user_id': userId, 'conversation_id': conversationId},
      );

      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to demote to member: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to demote to member',
      };
    }
  }

  Future<Map<String, dynamic>> getGroupInfo(int conversationId) async {
    try {
      final response = await _apiService.authenticatedGet(
        '/chat/get-group-info/$conversationId',
      );

      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to get group info: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get group info',
      };
    }
  }
}
