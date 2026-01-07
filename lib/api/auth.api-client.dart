import 'dart:convert';
import 'dart:io';
import 'package:amigo/env.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:amigo/services/auth/auth.service.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

import '../services/cookies.service.dart';
import '../services/location.service.dart';
import '../services/socket/websocket.service.dart';
import '../services/socket/ws-message.handler.dart';
import 'ip.api-client.dart';

class ApiService {
  final Dio _dio = Dio();
  final CookieService _cookieService = CookieService();
  final AuthService _authService = AuthService();
  final WebSocketService _websocketService = WebSocketService();

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initDio();
  }

  // Check if the API service is initialized
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Token refresh management
  bool _isRefreshing = false;
  final List<Function> _requestsQueue = [];
  Future<bool>? _refreshFuture;

  Future<void> _initDio() async {
    try {
      // Initialize cookie service first
      await _cookieService.init();

      // Configure Dio defaults
      _dio.options.validateStatus = (status) {
        return status != null;
      };

      // Enable cookie handling for HTTP-only cookies
      _dio.options.followRedirects = true;
      _dio.options.receiveDataWhenStatusError = true;

      // Set User-Agent to identify as mobile app for backend detection
      _dio.options.headers['User-Agent'] = 'Amigo-Mobile-App/Flutter';

      // Add cookie manager to Dio using the cookie service's jar
      _dio.interceptors.add(CookieManager(_cookieService.cookieJar));

      // Add request/response interceptors for better handling of HTTP-only cookies
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            // We don't need to manually add the token as the CookieManager
            // will automatically include cookies in the request
            return handler.next(options);
          },
          onResponse: (response, handler) async {
            // Debug: Check for cookies in response headers
            // final cookies = response.headers['set-cookie'];
            // if (cookies != null && cookies.isNotEmpty) {
            //   // Don't log the actual cookies for security reasons
            // }

            if (response.statusCode == 401) {
              // Don't try to refresh if we're already refreshing
              // or if the failed request was the refresh endpoint itself
              if (_isRefreshing ||
                  response.requestOptions.path.contains(
                    '/auth/refresh-mobile',
                  )) {
                _authService.logout();
                _disconnectWebSocketOnLogout();
                return handler.next(response);
              }

              // Try to refresh the token
              final refreshSuccess = await _refreshToken();

              if (refreshSuccess) {
                // Retry the original request with new token
                try {
                  final res = await _dio.fetch(response.requestOptions);
                  return handler.resolve(res);
                } catch (retryError) {
                  return handler.next(response);
                }
              } else {
                _authService.logout();
                _disconnectWebSocketOnLogout();
                return handler.next(response);
              }
            }

            // Check for authentication success
            if ((response.requestOptions.path.contains('verify-login-otp') ||
                    response.requestOptions.path.contains(
                      'verify-signup-otp',
                    )) &&
                response.statusCode == 200) {
              // Mark user as authenticated
              _authService.setAuthenticated();

              // Connect to WebSocket after successful authentication
              _connectWebSocketAfterLogin();

              // Update user location and IP after successful authentication
              // Run this in the background to avoid blocking the response
              updateUserLocationAndIp();
            }
            return handler.next(response);
          },
          onError: (DioException e, handler) async {
            // Handle auth errors - Token expired
            debugPrint(
              '⚠️ DioException intercepted: ${e.response?.statusCode} for ${e.requestOptions.path}',
            );
            return handler.next(e);
          },
        ),
      );

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
    }
  }

  /// Refresh the access token using the refresh token
  /// Returns true if successful, false otherwise
  Future<bool> _refreshToken() async {
    // If refresh is already in progress, wait for it and return its result
    if (_isRefreshing && _refreshFuture != null) {
      return await _refreshFuture!;
    }

    _isRefreshing = true;

    // Create a future that all concurrent calls will wait for
    _refreshFuture = _performTokenRefresh();

    try {
      final result = await _refreshFuture!;
      return result;
    } finally {
      _refreshFuture = null;
    }
  }

  /// Performs the actual token refresh operation
  /// This is separated so multiple calls can wait for the same operation
  Future<bool> _performTokenRefresh() async {
    try {
      // Call the refresh endpoint with validateStatus that accepts more status codes
      // This prevents the error interceptor from triggering on non-200 responses
      final response = await _dio.post(
        '${Environment.baseUrl}/auth/refresh-mobile',
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) {
            // Accept 200-299 and specific error codes without throwing
            return status != null &&
                (status >= 200 && status < 300 ||
                    status == 401 ||
                    status == 404);
          },
        ),
      );

      if (response.statusCode == 200) {
        // Check if we received new cookies
        final cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          // Cookies are automatically handled by CookieManager
          debugPrint('✅ Received new cookies in refresh response');
        } else {
          debugPrint('⚠️ Warning: No set-cookie headers in refresh response');
        }

        // Process any queued requests
        for (var request in _requestsQueue) {
          request();
        }
        _requestsQueue.clear();

        _isRefreshing = false;
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 404) {
        // Refresh token is expired or invalid
        debugPrint(
          '❌ Refresh token expired or invalid (Status: ${response.statusCode})',
        );
        _isRefreshing = false;
        return false;
      } else {
        debugPrint(
          '❌ Token refresh failed with status: ${response.statusCode}',
        );
        _isRefreshing = false;
        return false;
      }
    } on DioException catch (e) {
      debugPrint('❌ Token refresh DioException: ${e.message}');
      _isRefreshing = false;
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error during token refresh: $e');
      _isRefreshing = false;
      return false;
    }
  }

  /// Validate if the refresh token is still valid (matches server)
  /// Returns true if valid, false if invalid or error
  Future<bool> validateRefreshToken() async {
    try {
      final response = await _dio.get(
        '${Environment.baseUrl}/auth/validate-token',
        options: Options(
          validateStatus: (status) {
            return status != null && (status >= 200 && status < 300 || status == 404 || status == 401);
          },
        ),
      );

      if (response.statusCode == 200) {
        return response.data['success'] == true;
      } else {
        // Token is invalid (404 or 401)
        return false;
      }
    } on DioException catch (e) {
      debugPrint('❌ Token validation DioException: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error during token validation: $e');
      return false;
    }
  }

  // sign up function

  Future generateSignupOtp(String phoneNumber) async {
    try {
      Response response = await _dio.post(
        "${Environment.baseUrl}/auth/generate-signup-otp/$phoneNumber",
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

  Future verifySignupOtp(
    String phoneNumber,
    int otp,
    String firstName,
    String lastName,
  ) async {
    try {
      final name = '$firstName $lastName';
      Response response = await _dio.post(
        "${Environment.baseUrl}/auth/verify-signup-otp",
        data: {'phone': phoneNumber, 'otp': otp, 'name': name, 'role': 'user'},
      );

      if (response.data is String) {
        return jsonDecode(response.data as String);
      }
      return response.data;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred',
      };
    }
  }

  Future requestSignup(String firstName, String lastName, String phoneNumber) async {
    try {
      Response response = await _dio.post(
        "${Environment.baseUrl}/auth/request-signup",
        data: {'first_name': firstName, 'last_name': lastName, 'phone': phoneNumber},
      );
     if (response.data is String) {
        return jsonDecode(response.data as String);
      }
      return response.data;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred',
      };
    }
  }

  Future getSignupRequestStatus(String phoneNumber) async {
    try {
      Response response = await _dio.get(
        "${Environment.baseUrl}/auth/signup-request-status/$phoneNumber",
      );
      if (response.data is String) {
        return jsonDecode(response.data as String);
      }
      return response.data;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred',
      };
    }
  }

  Future sendLoginOtp(String phoneNumber) async {
    try {
      Response response = await _dio.post(
        "${Environment.baseUrl}/auth/generate-login-otp/$phoneNumber",
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

  Future verifyLoginOtp(String phoneNumber, int otp) async {
    try {
      // Format the request exactly like Postman
      Response response = await _dio.post(
        "${Environment.baseUrl}/auth/verify-login-otp",
        data: {'phone': phoneNumber, 'otp': otp},
      );

      if (response.data is String) {
        return jsonDecode(response.data as String);
      }
      return response.data;
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred',
      };
    }
  }

  // Check if authentication cookies exist
  Future<bool> hasAuthCookies() async {
    return await _cookieService.hasAuthCookies();
  }

  // Update user location and IP after authentication
  Future<void> updateUserLocationAndIp() async {
    try {
      final LocationService locationService = LocationService();
      final IpService ipService = IpService();

      // Get location and IP concurrently for better performance
      final futures = await Future.wait([
        locationService.getCurrentLocation(),
        ipService.getDetailedIpInfo(),
      ]);

      final locationResult = futures[0];
      final ipResult = futures[1];
      final data = {
        'location': {
          'latitude': locationResult['latitude'],
          'longitude': locationResult['longitude'],
        },
        'ip_address': (ipResult['ip']).toString(),
      };

      final response = await authenticatedPost('/user/update-user', data: data);

      return response.data;
    } catch (e) {
      debugPrint('❌ Error updating user location and IP');
    }
  }

  /// Update user FCM token
  Future updateFCMToken(String fcmToken) async {
    try {
      final response = await authenticatedPost(
        '/user/update-fcm-token',
        data: {'fcm_token': fcmToken},
      );

      if (response.data is String) {
        return jsonDecode(response.data as String);
      }
      return response.data;
    } catch (e) {
      debugPrint('❌ Error updating FCM token');
    }
  }

  // Method to make authenticated requests
  Future<Response> authenticatedGet(String path) async {
    // Check if we have auth cookies before making the request
    await _cookieService.hasAuthCookies();

    final response = await _dio.get('${Environment.baseUrl}$path');

    return response;
  }

  Future<Response> authenticatedPost(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    return await _dio.post(
      '${Environment.baseUrl}$path',
      data: data,
      queryParameters: queryParameters,
      options: Options(headers: headers),
    );
  }

  Future<Response> authenticatedPut(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.put(
      '${Environment.baseUrl}$path',
      data: data,
      queryParameters: queryParameters,
    );
  }

  Future<Response> authenticatedDelete(
    String path, {
    dynamic body,

    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.delete(
      '${Environment.baseUrl}$path',
      data: body,
      queryParameters: queryParameters,
    );
  }

  /// Sends media files to the server
  ///
  /// [file] - The file to upload
  /// [conversationId] - ID of the conversation to send the media to
  /// [messageType] - Type of message ('image', 'video', 'document', 'file')
  /// [caption] - Optional caption for the media
  /// [replyToMessageId] - Optional ID of message being replied to
  /// [onSendProgress] - Optional callback for upload progress
  ///
  /// Returns a Map with success status and response data
  Future<Map<String, dynamic>> sendMedia({
    required File file,
    Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      // Validate file exists
      if (!await file.exists()) {
        return {
          'success': false,
          'error': 'File does not exist',
          'message': 'The selected file could not be found',
        };
      }

      // Get file information
      final fileName = path.basename(file.path);
      final fileSize = await file.length();
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      // Validate file size (500MB limit)
      const maxFileSize = 500 * 1024 * 1024; // 500MB in bytes
      if (fileSize > maxFileSize) {
        return {
          'success': false,
          'error': 'File too large',
          'message': 'File size cannot exceed 500MB',
        };
      }

      // Read file as bytes to avoid content length issues
      // Use fromFile instead of fromBytes to enable proper progress tracking
      // fromBytes loads entire file into memory and doesn't report progress properly
      final multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      );

      // Prepare form data
      final formData = FormData.fromMap({'file': multipartFile});

      // Send the file
      final response = await _dio.post(
        '${Environment.baseUrl}/media/upload',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(
            minutes: 5,
          ), // 5 minute timeout for large files
          sendTimeout: const Duration(minutes: 5),
        ),
        onSendProgress: onSendProgress,
      );

      // Handle the response data properly
      if (response.data is Map<String, dynamic>) {
        return response.data;
      } else {
        // If response is not a map, wrap it in the expected format
        return {
          'success': response.statusCode == 200 || response.statusCode == 201,
          'code': response.statusCode,
          'data': response.data,
          'message': response.statusCode == 200 || response.statusCode == 201
              ? 'File uploaded successfully'
              : 'Upload failed',
        };
      }
    } on DioException catch (e) {
      String errorMessage = 'Failed to send media';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage =
            'Upload timeout - please check your connection and try again';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Connection error - please check your internet connection';
      } else if (e.type == DioExceptionType.unknown) {
        errorMessage =
            'Network error - please check your internet connection and server availability';
      } else if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode == 413) {
          errorMessage = 'File too large for server';
        } else if (statusCode == 415) {
          errorMessage = 'File type not supported';
        } else if (statusCode == 401) {
          errorMessage = 'Authentication required';
          _authService.logout();
          _disconnectWebSocketOnLogout();
        } else if (statusCode == 400) {
          errorMessage = e.response!.data?['message'] ?? 'Invalid request';
        } else {
          // For other status codes, try to get server message
          if (e.response!.data is Map<String, dynamic>) {
            errorMessage =
                e.response!.data['message'] ?? 'Server error: $statusCode';
          } else {
            errorMessage = 'Server error: $statusCode';
          }
        }
      }

      return {
        'success': false,
        'error': e.toString(),
        'message': errorMessage,
        'statusCode': e.response?.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred while sending media',
      };
    }
  }

  /// Sends multiple media files to the server
  ///
  /// [files] - List of files to upload
  /// [conversationId] - ID of the conversation to send the media to
  /// [messageType] - Type of message ('image', 'video', 'document', 'file')
  /// [caption] - Optional caption for the media
  /// [replyToMessageId] - Optional ID of message being replied to
  /// [onSendProgress] - Optional callback for upload progress
  ///
  /// Returns a Map with success status and response data
  Future<Map<String, dynamic>> sendMultipleMedia({
    required List<File> files,
    required int conversationId,
    required String messageType,
    String? caption,
    int? replyToMessageId,
    Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      if (files.isEmpty) {
        return {
          'success': false,
          'error': 'No files provided',
          'message': 'Please select at least one file to send',
        };
      }

      // Validate all files exist and get total size
      int totalSize = 0;
      final List<MultipartFile> multipartFiles = [];

      for (final file in files) {
        if (!await file.exists()) {
          return {
            'success': false,
            'error': 'File does not exist',
            'message': 'One or more selected files could not be found',
          };
        }

        final fileSize = await file.length();
        totalSize += fileSize;

        // Validate individual file size (50MB limit)
        const maxFileSize = 50 * 1024 * 1024; // 50MB in bytes
        if (fileSize > maxFileSize) {
          return {
            'success': false,
            'error': 'File too large',
            'message': 'Each file size cannot exceed 50MB',
          };
        }

        final fileName = path.basename(file.path);
        final mimeType =
            lookupMimeType(file.path) ?? 'application/octet-stream';

        final multipartFile = await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        );
        multipartFiles.add(multipartFile);
      }

      // Validate total size (100MB limit for multiple files)
      const maxTotalSize = 100 * 1024 * 1024; // 100MB in bytes
      if (totalSize > maxTotalSize) {
        return {
          'success': false,
          'error': 'Total files too large',
          'message': 'Total size of all files cannot exceed 100MB',
        };
      }

      // Prepare form data
      final formData = FormData.fromMap({
        'files': multipartFiles,
        'conversation_id': conversationId.toString(),
        'type': messageType,
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        if (replyToMessageId != null)
          'reply_to_message_id': replyToMessageId.toString(),
      });

      // Send the files
      final response = await _dio.post(
        '${Environment.baseUrl}/messages/send-multiple-media',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(
            minutes: 10,
          ), // 10 minute timeout for multiple files
          sendTimeout: const Duration(minutes: 10),
        ),
        onSendProgress: onSendProgress,
      );

      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'statusCode': response.statusCode,
        'data': response.data,
        'message': 'Media files sent successfully',
      };
    } on DioException catch (e) {
      String errorMessage = 'Failed to send media files';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage =
            'Upload timeout - please check your connection and try again';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Connection error - please check your internet connection';
      } else if (e.response != null) {
        final statusCode = e.response!.statusCode;
        if (statusCode == 413) {
          errorMessage = 'Files too large for server';
        } else if (statusCode == 415) {
          errorMessage = 'One or more file types not supported';
        } else if (statusCode == 401) {
          errorMessage = 'Authentication required';
          _authService.logout();
          _disconnectWebSocketOnLogout();
        } else if (statusCode == 400) {
          errorMessage = e.response!.data?['message'] ?? 'Invalid request';
        }
      }

      return {
        'success': false,
        'error': e.toString(),
        'message': errorMessage,
        'statusCode': e.response?.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred while sending media files',
      };
    }
  }

  // Connect to WebSocket after successful login
  Future<void> _connectWebSocketAfterLogin() async {
    try {
      print('🔌 Connecting to WebSocket after successful login...');

      // CRITICAL: Initialize message handler BEFORE connecting to WebSocket
      // This ensures listeners are set up before any messages arrive
      WebSocketMessageHandler().initialize();

      await _websocketService.connect();
      print('✅ WebSocket connected successfully after login');
    } catch (e) {
      print('❌ Failed to connect WebSocket after login: $e');
    }
  }

  // Disconnect WebSocket on logout
  Future<void> _disconnectWebSocketOnLogout() async {
    try {
      print('🔌 Disconnecting WebSocket on logout...');
      await _websocketService.shutdown();
      print('✅ WebSocket disconnected successfully on logout');
    } catch (e) {
      print('❌ Failed to disconnect WebSocket on logout: $e');
    }
  }
}
