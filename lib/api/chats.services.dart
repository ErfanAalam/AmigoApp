import 'dart:io';
import 'package:dio/dio.dart';
import 'api_service.dart';

class ChatsServices {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> createChat(String receiverId) async {
    try {
      final response = await _apiService.authenticatedPost(
        '/chat/create-chat/$receiverId',
      );
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to create chat: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create chat',
      };
    }
  }

  Future<Map<String, dynamic>> getConversationHistory({
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
        'message': 'Conversation history retrieved successfully',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to get conversation history: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get conversation history',
      };
    }
  }

  Future<Map<String, dynamic>> sendMediaMessage(File file) async {
    try {
      final response = await _apiService.sendMedia(file: file);

      // Handle the response based on the API structure
      // Response should be: {success: true, code: 200, message: "File uploaded successfully", data: {...}}
      // if (response is Map<String, dynamic>) {
      return {
        'success': response['success'] == true || response['code'] == 200,
        'data': response['data'],
        'message': response['message'] ?? 'Media uploaded successfully',
        'statusCode': response['code'],
      };
      // }
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to upload media: ${e.message}',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteMessage(List<int> messageIds) async {
    try {
      final response = await _apiService.authenticatedDelete(
        '/chat/soft-delete-message',
        body: {'message_ids': messageIds},
      );
      return response.data;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete message',
      };
    }
  }

  Future<Map<String, dynamic>> deleteDm(int conversationId) async {
    try {
      final response = await _apiService.authenticatedDelete(
        '/chat/soft-delete-dm/$conversationId',
      );
      return response.data;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete dm',
      };
    }
  }

  Future<Map<String, dynamic>> reviveChat(int conversationId) async {
    try {
      final response = await _apiService.authenticatedPost(
        '/chat/revive-chat/$conversationId',
      );
      return response.data;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to revive chat',
      };
    }
  }
}
