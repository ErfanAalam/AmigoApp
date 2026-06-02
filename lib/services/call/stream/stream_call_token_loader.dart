import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../env.dart';
import '../../../utils/user.utils.dart';
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

    // Stash credentials in SharedPreferences so the Kotlin side can perform
    // a cold-state reject (when the user taps the Decline button on the
    // killed-app incoming-call notification, no Flutter isolate is alive
    // to call `call.reject()` and the caller never sees the rejection).
    // The native broadcast receiver reads these to call our backend's
    // `/call/stream/decline-cold` endpoint directly.
    if (token != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        // Important: do NOT manually prepend `flutter.` to these keys.
        // Flutter's `shared_preferences` package already prepends that
        // prefix when persisting to Android's `FlutterSharedPreferences`
        // store. Doing it ourselves produced `flutter.flutter.stream_user_id`,
        // which the Kotlin AmigoColdDeclineBridge — reading the canonical
        // single-prefix key — never matched, so every killed-state decline
        // bailed with `missing prefs (user_id=null base=null)`.
        await prefs.setString('stream_user_token', token);
        if (apiKey != null) {
          await prefs.setString('stream_api_key', apiKey);
        }
        final user = await UserUtils().getUserDetails();
        if (user != null) {
          await prefs.setString('stream_user_id', user.id);
        }
        await prefs.setString('stream_backend_base', Environment.baseUrl);
        debugPrint('[STREAM-TOKEN]   cached creds for native decline: '
            'user=${user?.id}  base=${Environment.baseUrl}');
      } catch (e) {
        debugPrint('[STREAM-TOKEN]   ✗ failed to cache creds for native decline: $e');
      }
    }
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
