import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../env.dart';
import '../../cookies.service.dart';

/// Fetches a fresh Stream Video user token from our backend.
///
/// Lives in its own file so background isolates (FCM handler) can pull it in
/// without dragging the full StreamCallService.
Future<String?> loadStreamToken() async {
  final url = '${Environment.baseUrl}/call/stream/credentials';
  debugPrint('[STREAM-TOKEN] ▶ GET $url');
  try {
    final cookieService = CookieService();
    await cookieService.init();
    final accessToken = await cookieService.getAccessToken();
    if (accessToken == null) {
      debugPrint('[STREAM-TOKEN] ✗ no access token in cookie jar — user not logged in?');
      return null;
    }
    debugPrint('[STREAM-TOKEN]   access_token len=${accessToken.length}');

    final response = await Dio().get(
      url,
      options: Options(
        headers: {'Authorization': 'Bearer $accessToken'},
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
    debugPrint('[STREAM-TOKEN]   status=${response.statusCode} '
        'success=${response.data?['success']} '
        'message=${response.data?['message']}');
    final token = (response.data?['data']?['token']) as String?;
    final apiKey = (response.data?['data']?['api_key']) as String?;
    debugPrint('[STREAM-TOKEN]   api_key=$apiKey  token.len=${token?.length}');
    return token;
  } on DioException catch (e) {
    debugPrint('[STREAM-TOKEN] ✗ DioException status=${e.response?.statusCode} '
        'msg=${e.message} body=${e.response?.data}');
    return null;
  } catch (e, st) {
    debugPrint('[STREAM-TOKEN] ✗ unexpected error: $e\n$st');
    return null;
  }
}
