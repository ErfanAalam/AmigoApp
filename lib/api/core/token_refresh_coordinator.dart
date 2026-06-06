import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../env.dart';

/// Coordinates access-token refresh across every caller (the HTTP interceptor
/// AND the realtime transport) so that only ONE `/auth/refresh-mobile` request
/// is ever in flight at a time.
///
/// Why this exists:
/// The backend ROTATES the refresh token on every refresh and stores a single
/// value per user. If two requests refresh concurrently, the first rotates the
/// token and the second sends the now-stale one -> 404 -> the app force-logs the
/// user out. This was the cause of the "random logouts": a burst of requests
/// returning 498/499 at once (e.g. on app resume) each fired their own refresh.
///
/// Funnelling every refresh through one shared in-flight Future means concurrent
/// callers await the SAME result instead of stampeding the rotating endpoint.
class TokenRefreshCoordinator {
  TokenRefreshCoordinator._();
  static final TokenRefreshCoordinator instance = TokenRefreshCoordinator._();

  Future<bool>? _inFlight;

  /// Refresh the access token, sharing a single request across concurrent
  /// callers. Returns true when the token was refreshed successfully.
  ///
  /// Pass the shared [Dio] instance (the one carrying the cookie jar) so the
  /// rotated cookies are written back for every subsequent request.
  Future<bool> refresh(Dio dio) {
    final existing = _inFlight;
    if (existing != null) {
      debugPrint('[TOKEN-REFRESH] Joining in-flight refresh');
      return existing;
    }

    final future = _performRefresh(dio).whenComplete(() => _inFlight = null);
    _inFlight = future;
    return future;
  }

  Future<bool> _performRefresh(Dio dio) async {
    try {
      debugPrint('[TOKEN-REFRESH] Requesting new access token');
      final response = await dio.post(
        '${Environment.baseUrl}/auth/refresh-mobile',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          // Mark so the auth interceptor never tries to refresh THIS request
          // (prevents any chance of refresh recursion).
          extra: {'skip_refresh': true},
          validateStatus: (status) =>
              status != null &&
              (status >= 200 && status < 300 ||
                  status == 401 ||
                  status == 404),
        ),
      );

      final ok = response.statusCode == 200;
      debugPrint(
        ok
            ? '[TOKEN-REFRESH] ✅ Token refreshed'
            : '[TOKEN-REFRESH] ❌ Refresh failed (status ${response.statusCode})',
      );
      return ok;
    } catch (e) {
      debugPrint('[TOKEN-REFRESH] ❌ Refresh error: $e');
      return false;
    }
  }
}
