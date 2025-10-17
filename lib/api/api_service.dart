import 'dart:io';
import 'package:amigo/env.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:amigo/services/auth_service.dart';
import 'package:amigo/services/cookie_service.dart';
import 'package:amigo/services/location_service.dart';
import 'package:amigo/services/ip_service.dart';
import 'package:amigo/services/websocket_service.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

class ApiService {
  final Dio _dio = Dio();
  final CookieService _cookieService = CookieService();
  final AuthService _authService = AuthService();
  final WebSocketService _websocketService = WebSocketService();

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal() {
    _initDio();
  }

  // Check if the API service is initialized
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Token refresh management
  bool _isRefreshing = false;
  List<Function> _requestsQueue = [];
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
          onResponse: (response, handler) {
            // Debug: Check for cookies in response headers
            final cookies = response.headers['set-cookie'];
            if (cookies != null && cookies.isNotEmpty) {
              // Don't log the actual cookies for security reasons
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
            if (e.response?.statusCode == 401) {
              print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
              print('🔄 401 Unauthorized detected!');
              print('📍 Request path: ${e.requestOptions.path}');
              print('📍 Request method: ${e.requestOptions.method}');
              print('📍 Is refreshing: $_isRefreshing');
              print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

              // Don't try to refresh if we're already refreshing
              // or if the failed request was the refresh endpoint itself
              if (_isRefreshing ||
                  e.requestOptions.path.contains('/auth/refresh-mobile')) {
                print(
                  '❌ Already refreshing or refresh endpoint failed - logging out',
                );
                _authService.logout();
                _disconnectWebSocketOnLogout();
                return handler.next(e);
              }

              print('🔄 Attempting to refresh access token...');

              // Try to refresh the token
              final refreshSuccess = await _refreshToken();

              print(
                '📊 Refresh result: ${refreshSuccess ? "SUCCESS ✅" : "FAILED ❌"}',
              );

              if (refreshSuccess) {
                print(
                  '✅ Token refreshed successfully - Retrying original request',
                );
                print(
                  '🔄 Retrying: ${e.requestOptions.method} ${e.requestOptions.path}',
                );

                // Retry the original request with new token
                try {
                  final response = await _dio.fetch(e.requestOptions);
                  print('✅ Original request succeeded after token refresh!');
                  return handler.resolve(response);
                } catch (retryError) {
                  print('❌ Retry failed after token refresh: $retryError');
                  return handler.next(e);
                }
              } else {
                print('❌ Token refresh failed - Logging out user');
                print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                _authService.logout();
                _disconnectWebSocketOnLogout();
                return handler.next(e);
              }
            }
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
      print('⏳ Token refresh already in progress, waiting for completion...');
      return await _refreshFuture!;
    }

    _isRefreshing = true;
    print('🔄 Starting token refresh process...');
    print(
      '📍 Current cookies available: ${await _cookieService.hasAuthCookies()}',
    );

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

      print('📊 Refresh response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Token refresh successful');

        // Check if we received new cookies
        final cookies = response.headers['set-cookie'];
        if (cookies != null && cookies.isNotEmpty) {
          print('🍪 New tokens received: ${cookies.length} cookie(s)');
          for (var cookie in cookies) {
            // Log cookie names without values for security
            final cookieName = cookie.split('=')[0];
            print('  - $cookieName');
          }
        } else {
          print('⚠️ Warning: No set-cookie headers in refresh response');
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
        print(
          '❌ Refresh token expired or invalid (Status: ${response.statusCode})',
        );
        print('📄 Response: ${response.data}');
        _isRefreshing = false;
        return false;
      } else {
        print('❌ Token refresh failed with status: ${response.statusCode}');
        print('📄 Response: ${response.data}');
        _isRefreshing = false;
        return false;
      }
    } on DioException catch (e) {
      print('❌ Token refresh DioException: ${e.message}');
      print('📍 Error type: ${e.type}');
      if (e.response != null) {
        print('📍 Response status: ${e.response?.statusCode}');
        print('📍 Response data: ${e.response?.data}');
      }

      _isRefreshing = false;
      return false;
    } catch (e) {
      print('❌ Unexpected error during token refresh: $e');
      _isRefreshing = false;
      return false;
    }
  }

  // sign up function

  Future generateSignupOtp(String phoneNumber) async {
    print('this is the phone number: $phoneNumber');
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

      // Check if we received any cookies
      final cookies = response.headers['set-cookie'];
      if (cookies != null && cookies.isNotEmpty) {
      } else {
        print('No cookies received');
      }
      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'data': response.data,
        'message': 'Signup OTP verified successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Unexpected error occurred',
      };
    }
  }

  Future send_login_otp(String phone_number) async {
    try {
      Response response = await _dio.post(
        "${Environment.baseUrl}/auth/generate-login-otp/$phone_number",
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

  Future verify_login_otp(String phone_number, int otp) async {
    try {
      // Format the request exactly like Postman
      Response response = await _dio.post(
        "${Environment.baseUrl}/auth/verify-login-otp",
        data: {'phone': phone_number, 'otp': otp},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          // Ensure cookies are received
          receiveDataWhenStatusError: true,
          validateStatus: (status) => true,
        ),
      );

      // Check if we received any cookies
      final cookies = response.headers['set-cookie'];
      if (cookies != null && cookies.isNotEmpty) {
      } else {}

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'data': response.data,
        'message': 'Login OTP verified successfully',
      };
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

  // Debug method to list all cookies (don't use in production)
  Future<void> debugListCookies() async {
    await _cookieService.debugListCookies();
  }

  // Update user location and IP after authentication
  Future<void> updateUserLocationAndIp() async {
    try {
      print('🚀 Updating user location and IP after authentication...');

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

      print(
        '-------------------------------------------------------------------------------',
      );
      print('this is the response: $response');
      print(
        '-------------------------------------------------------------------------------',
      );
      return response.data;
    } catch (e) {
      print('❌ Error updating user location and IP: $e');
    }
  }

  /// Update user FCM token
  Future<void> updateFCMToken(String fcmToken) async {
    try {
      print('🔑 Updating FCM token...');

      final response = await authenticatedPost(
        '/user/update-fcm-token',
        data: {'fcm_token': fcmToken},
      );

      print('✅ FCM token updated successfully');
      return response.data;
    } catch (e) {
      print('❌ Error updating FCM token: $e');
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
  Future<Map<String, dynamic>> sendMedia({required File file}) async {
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

      // Validate file size (50MB limit)
      const maxFileSize = 50 * 1024 * 1024; // 50MB in bytes
      if (fileSize > maxFileSize) {
        return {
          'success': false,
          'error': 'File too large',
          'message': 'File size cannot exceed 50MB',
        };
      }

      // Read file as bytes to avoid content length issues
      final fileBytes = await file.readAsBytes();

      // Create multipart file from bytes instead of file path
      final multipartFile = MultipartFile.fromBytes(
        fileBytes,
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
      await _websocketService.disconnect();
      print('✅ WebSocket disconnected successfully on logout');
    } catch (e) {
      print('❌ Failed to disconnect WebSocket on logout: $e');
    }
  }
}
