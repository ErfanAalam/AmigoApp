import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';

import '../../services/auth/auth.service.dart';
import '../../services/cookies.service.dart';
import 'api_result.dart';
import 'base_api_client.dart';
import 'token_refresh_coordinator.dart';

/// Main API client that handles initialization and token refresh
/// This is a singleton that manages the Dio instance
class ApiClient extends BaseApiClient {
  static ApiClient? _instance;
  static bool _isInitialized = false;

  ApiClient._internal({
    required super.dio,
    required super.cookieService,
    required super.authService,
  });

  /// Get the singleton instance
  factory ApiClient.instance() {
    if (_instance == null) {
      throw StateError(
        'ApiClient not initialized. Call ApiClient.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Initialize the API client
  /// Must be called before using any API clients
  static Future<void> initialize({
    required Dio dio,
    required CookieService cookieService,
    required AuthService authService,
  }) async {
    if (_isInitialized) {
      debugPrint('⚠️ ApiClient already initialized');
      return;
    }

    // Initialize cookie service first
    await cookieService.init();

    // Configure Dio defaults
    dio.options.validateStatus = (status) => status != null;
    dio.options.followRedirects = true;
    dio.options.receiveDataWhenStatusError = true;
    dio.options.headers['User-Agent'] = 'Amigo-Mobile-App/Flutter';

    // Add cookie manager
    dio.interceptors.add(CookieManager(cookieService.cookieJar));

    // Add interceptors for token refresh and auth handling
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.next(options),
        onResponse: (response, handler) async {
          final requestOptions = response.requestOptions;

          // Handle token expiry (498, 499).
          // `skip_refresh` guards the refresh request itself; `refresh_retried`
          // guards against re-refreshing an already-replayed request.
          if ((response.statusCode == 498 || response.statusCode == 499) &&
              requestOptions.extra['skip_refresh'] != true &&
              requestOptions.extra['refresh_retried'] != true) {
            // Single-flight refresh shared with the transport manager — only one
            // /auth/refresh-mobile is ever in flight, so concurrent 498/499s no
            // longer stampede the rotating refresh token into a forced logout.
            final refreshSuccess =
                await TokenRefreshCoordinator.instance.refresh(dio);

            if (!refreshSuccess) {
              authService.logout();
              return handler.next(response);
            }

            // Refresh succeeded — replay the original request once with the new
            // cookies so the caller gets real data instead of the 498/499.
            // A 498/499 is produced by the auth middleware BEFORE the route
            // handler runs, so the original request had no side effects and is
            // safe to replay.
            try {
              requestOptions.extra['refresh_retried'] = true;
              final retried = await dio.fetch(requestOptions);
              return handler.resolve(retried);
            } catch (e) {
              if (e is DioException && e.response != null) {
                return handler.resolve(e.response!);
              }
              // Non-replayable request (e.g. consumed multipart) — fall back to
              // returning the original response rather than crashing.
              return handler.next(response);
            }
          }

          // Handle authentication success
          final path = requestOptions.path;
          if ((path.contains('verify-login-otp') ||
                  path.contains('verify-signup-otp')) &&
              response.statusCode == 200) {
            authService.setAuthenticated();
            // Update location/IP in background
            _updateLocationInBackground(authService);
          }

          return handler.next(response);
        },
        onError: (error, handler) {
          debugPrint(
            '⚠️ DioException: ${error.response?.statusCode} for ${error.requestOptions.path}',
          );
          return handler.next(error);
        },
      ),
    );

    _instance = ApiClient._internal(
      dio: dio,
      cookieService: cookieService,
      authService: authService,
    );

    _isInitialized = true;
  }

  /// Update user location and IP in background
  static void _updateLocationInBackground(AuthService authService) {
    // This will be handled by the location service
    // Just a placeholder for now
  }

  /// Validate refresh token
  Future<ApiResult<bool>> validateRefreshToken() async {
    try {
      final response = await dio.get('$baseUrl/auth/validate-token');

      // Fallback if response doesn't match ResultType format
      if (response.statusCode == 200) {
        return ApiResult<bool>.success(
          data: true,
          code: 200,
          message: 'Token validated',
        );
      }

      return ApiResult<bool>.error(
        message: 'Token validation failed',
        code: response.statusCode ?? 401,
      );
    } on DioException catch (e) {
      // Rethrow network errors for offline handling
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        rethrow;
      }

      // Check if backend returned ResultType format
      if (e.response?.data is Map<String, dynamic>) {
        final responseData = e.response!.data as Map<String, dynamic>;
        if (responseData.containsKey('success')) {
          return ApiResult<bool>.fromMap(responseData);
        }
      }

      return ApiResult<bool>.error(
        message: 'Token validation failed',
        code: e.response?.statusCode ?? 401,
        error: e.message,
      );
    } catch (e) {
      return ApiResult<bool>.error(
        message: 'Token validation error',
        code: 500,
        error: e.toString(),
      );
    }
  }

  /// Check if auth cookies exist
  Future<bool> hasAuthCookies() => cookieService.hasAuthCookies();
}
