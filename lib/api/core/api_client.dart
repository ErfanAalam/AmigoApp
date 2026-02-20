import 'package:amigo/env.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';

import '../../services/auth/auth.service.dart';
import '../../services/cookies.service.dart';
import 'api_result.dart';
import 'base_api_client.dart';

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
          // Handle token expiry (498, 499)
          if (response.statusCode == 498 || response.statusCode == 499) {
            final refreshSuccess = await _refreshToken(dio, authService);
            if (!refreshSuccess) {
              authService.logout();
              return handler.next(response);
            }
          }

          // Handle authentication success
          final path = response.requestOptions.path;
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

  /// Refresh the access token
  static Future<bool> _refreshToken(Dio dio, AuthService authService) async {
    try {
      final response = await dio.post(
        '${Environment.baseUrl}/auth/refresh-mobile',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) =>
              status != null &&
              (status >= 200 && status < 300 || status == 401 || status == 404),
        ),
      );

      if (response.statusCode == 200) {
        final cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          debugPrint('✅ Received new cookies in refresh response');
        } else {
          debugPrint('⚠️ Warning: No set-cookie headers in refresh response');
        }
        return true;
      }

      debugPrint(
        '❌ Refresh token expired or invalid (Status: ${response.statusCode})',
      );
      return false;
    } catch (e) {
      debugPrint('❌ Token refresh error: $e');
      return false;
    }
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
