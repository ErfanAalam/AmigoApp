import 'package:dio/dio.dart';
import 'api_service.dart';

class UserService {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> getUser() async {
    try {
      final response = await _apiService.authenticatedGet('/user/get-user');
      return response.data;
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.message,
        'type': e.type.toString(),
        'statusCode': e.response?.statusCode,
        'message': 'Failed to get user data: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred',
      };
    }
  }

  Future<Map<String, dynamic>> getAvailableUsers(List<String> contacts) async {
    try {
      final response = await _apiService.authenticatedPost(
        '/user/get-available-users',
        data: {'phone_numbers': contacts},
      );
      return {
        'success': response.data['success'],
        'statusCode': response.data['code'],
        'data': response.data['data'],
        'message': response.data['message'],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred',
      };
    }
  }

  Future<Map<String, dynamic>> GetChatList(String type) async {
    try {
      final response = await _apiService.authenticatedGet(
        '/chat/get-chat-list/$type',
      );
      return response.data;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred',
      };
    }
  }

  Future<Map<String, dynamic>> GetCommunityChatList() async {
    try {
      final response = await _apiService.authenticatedGet(
        '/community/list-connected-communities',
      );
      return response.data;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred',
      };
    }
  }

  Future<Map<String, dynamic>> updateUser(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.authenticatedPost(
        '/user/update-user',
        data: data,
      );
      return response.data;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred',
      };
    }
  }
}
