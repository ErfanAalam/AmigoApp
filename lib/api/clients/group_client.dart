import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

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

  /// Update group profile image (multipart). Admin-only on the server.
  /// Returns the new public URL via `data.profile_pic` on success. The
  /// matching `conversation:action` (action = chat_details:update) WS event
  /// fans the new URL out to all members, so callers don't need to update
  /// local state themselves.
  Future<ApiResult<dynamic>> updateGroupProfileImage({
    required String conversationId,
    required File image,
    Function(int sent, int total)? onSendProgress,
  }) async {
    if (!await image.exists()) {
      return ApiResult<dynamic>.error(
        message: 'File does not exist',
        code: 400,
        error: 'The selected file could not be found',
      );
    }

    final fileName = path.basename(image.path);
    final mimeType =
        lookupMimeType(image.path) ?? 'application/octet-stream';

    final multipart = await MultipartFile.fromFile(
      image.path,
      filename: fileName,
      contentType: DioMediaType.parse(mimeType),
    );

    final formData = FormData.fromMap({
      'conversation_id': conversationId,
      'image': multipart,
    });

    try {
      final response = await dio.post(
        '$baseUrl/chat/group/update-group-profile-image',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: onSendProgress,
      );
      return ApiResult<dynamic>.fromMap(
        response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : {'success': true, 'code': 200, 'data': response.data},
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data.containsKey('success')) {
        return ApiResult<dynamic>.fromMap(data);
      }
      return ApiResult<dynamic>.error(
        message: e.message ?? 'Upload failed',
        code: e.response?.statusCode ?? 500,
        error: e.message,
      );
    } catch (e) {
      return ApiResult<dynamic>.error(
        message: 'Upload failed',
        code: 500,
        error: e.toString(),
      );
    }
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
