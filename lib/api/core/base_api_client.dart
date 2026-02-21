import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

import '../../env.dart';
import '../../services/auth/auth.service.dart';
import '../../services/cookies.service.dart';
import '../../utils/serialization.utils.dart';
import 'api_result.dart';

/// Base API client with common functionality
/// All domain-specific API clients should extend this
abstract class BaseApiClient {
  final Dio _dio;
  final CookieService cookieService;
  final AuthService _authService;

  BaseApiClient({
    required Dio dio,
    required this.cookieService,
    required AuthService authService,
  }) : _dio = dio,
       _authService = authService;

  /// Get the base URL
  String get baseUrl => Environment.baseUrl;

  /// Get the Dio instance
  Dio get dio => _dio;

  /// Parse response data, handling both String and Map responses
  /// Backend always returns ResultType<T> format
  static Map<String, dynamic> _parseResponseData(dynamic data) {
    Map<String, dynamic> parsed;

    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          parsed = decoded;
        } else {
          // If decoded data is not a Map (e.g., List, primitive), wrap it
          // Convert string IDs to int before wrapping
          final convertedData = convertStringIdsToInt(decoded);
          return {
            'success': true,
            'code': 200,
            'message': 'Success',
            'data': convertedData,
          };
        }
      } catch (_) {
        // If parsing fails, wrap in ResultType format
        return {
          'success': false,
          'code': 500,
          'message': 'Failed to parse response',
          'error': data,
        };
      }
    } else if (data is Map<String, dynamic>) {
      parsed = data;
    } else {
      // If data is not a Map (e.g., List, primitive), wrap it in ResultType format
      // This preserves the actual data structure instead of discarding it
      // Convert string IDs to int before wrapping
      final convertedData = convertStringIdsToInt(data);
      return {
        'success': true,
        'code': 200,
        'message': 'Success',
        'data': convertedData,
      };
    }

    // Ensure it has the ResultType structure
    if (!parsed.containsKey('success')) {
      // If backend didn't return ResultType format, wrap it
      final wrapped = {
        'success': true,
        'code': 200,
        'message': parsed['message'] ?? 'Success',
        'data': parsed,
      };
      // Convert string IDs to int before returning
      return convertStringIdsToInt(wrapped);
    }

    // Convert string IDs (from BigInt) to int before returning
    return convertStringIdsToInt(parsed);
  }

  /// Handle DioException and convert to ApiResult.error
  ApiResult<T> _handleDioException<T>(DioException e) {
    String message = 'An error occurred';
    int code = e.response?.statusCode ?? 500;
    dynamic error;

    // Check if backend returned ResultType format
    if (e.response?.data is Map<String, dynamic>) {
      final responseData = e.response!.data as Map<String, dynamic>;
      // Convert string IDs to int before processing
      final convertedData = convertStringIdsToInt(responseData);

      if (convertedData.containsKey('success') &&
          convertedData.containsKey('message')) {
        // Backend already returned ResultType format
        return ApiResult<T>.fromMap(convertedData);
      }
      // Extract message from response if available
      message = convertedData['message'] ?? message;
      error = convertedData['error'] ?? e.message;
    } else {
      error = e.message;
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Request timeout - please check your connection';
        break;
      case DioExceptionType.connectionError:
        message = 'Connection error - please check your internet connection';
        break;
      case DioExceptionType.badResponse:
        if (code == 401) {
          message = 'Authentication required';
          _authService.logout();
        } else if (code == 403) {
          message = 'Access forbidden';
        } else if (code == 404) {
          message = 'Resource not found';
        } else if (code == 413) {
          message = 'File too large';
        } else if (code == 415) {
          message = 'File type not supported';
        } else if (code == 400) {
          message = message.isNotEmpty ? message : 'Invalid request';
        }
        break;
      case DioExceptionType.cancel:
        message = 'Request cancelled';
        break;
      case DioExceptionType.unknown:
        message = 'Network error - please check your connection';
        break;
      case DioExceptionType.badCertificate:
        message = 'Certificate error';
        break;
    }

    return ApiResult<T>.error(message: message, code: code, error: error);
  }

  /// Handle generic exceptions
  ApiResult<T> _handleException<T>(Object e) {
    return ApiResult<T>.error(
      message: 'Unexpected error occurred',
      code: 500,
      error: e.toString(),
    );
  }

  /// Make an authenticated GET request
  /// Returns ApiResult with backend ResultType format
  Future<ApiResult<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      await cookieService.hasAuthCookies();

      final response = await _dio.get(
        '$baseUrl$path',
        queryParameters: queryParameters,
        options: options,
      );

      final parsedData = _parseResponseData(response.data);
      return ApiResult<dynamic>.fromMap(parsedData);
    } on DioException catch (e) {
      return _handleDioException<dynamic>(e);
    } catch (e) {
      return _handleException<dynamic>(e);
    }
  }

  /// Make an authenticated POST request
  /// Returns ApiResult with backend ResultType format
  Future<ApiResult<dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl$path',
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      final parsedData = _parseResponseData(response.data);
      return ApiResult<dynamic>.fromMap(parsedData);
    } on DioException catch (e) {
      return _handleDioException<dynamic>(e);
    } catch (e) {
      return _handleException<dynamic>(e);
    }
  }

  /// Make an authenticated PUT request
  /// Returns ApiResult with backend ResultType format
  Future<ApiResult<dynamic>> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        '$baseUrl$path',
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      final parsedData = _parseResponseData(response.data);
      return ApiResult<dynamic>.fromMap(parsedData);
    } on DioException catch (e) {
      return _handleDioException<dynamic>(e);
    } catch (e) {
      return _handleException<dynamic>(e);
    }
  }

  /// Make an authenticated DELETE request
  /// Returns ApiResult with backend ResultType format
  Future<ApiResult<dynamic>> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        '$baseUrl$path',
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      final parsedData = _parseResponseData(response.data);
      return ApiResult<dynamic>.fromMap(parsedData);
    } on DioException catch (e) {
      return _handleDioException<dynamic>(e);
    } catch (e) {
      return _handleException<dynamic>(e);
    }
  }

  /// Upload a single media file
  Future<ApiResult<dynamic>> uploadMedia({
    required File file,
    Function(int sent, int total)? onSendProgress,
    int maxFileSizeMB = 500,
  }) async {
    try {
      // Validate file exists
      if (!await file.exists()) {
        return ApiResult<dynamic>.error(
          message: 'File does not exist',
          code: 400,
          error: 'The selected file could not be found',
        );
      }

      // Get file information
      final fileName = path.basename(file.path);
      final fileSize = await file.length();
      final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';

      // Validate file size
      final maxFileSize = maxFileSizeMB * 1024 * 1024;
      if (fileSize > maxFileSize) {
        return ApiResult<dynamic>.error(
          message: 'File too large',
          code: 413,
          error: 'File size cannot exceed ${maxFileSizeMB}MB',
        );
      }

      // Create multipart file
      final multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      );

      // Prepare form data
      final formData = FormData.fromMap({'file': multipartFile});

      // Send the file
      final response = await _dio.post(
        '$baseUrl/media/upload',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
        ),
        onSendProgress: onSendProgress,
      );

      final parsedData = _parseResponseData(response.data);
      return ApiResult<dynamic>.fromMap(parsedData);
    } on DioException catch (e) {
      return _handleDioException<dynamic>(e);
    } catch (e) {
      return _handleException<dynamic>(e);
    }
  }

  /// Upload multiple media files
  Future<ApiResult<dynamic>> uploadMultipleMedia({
    required List<File> files,
    Map<String, dynamic>? additionalFields,
    Function(int sent, int total)? onSendProgress,
    int maxFileSizeMB = 50,
    int maxTotalSizeMB = 100,
  }) async {
    try {
      if (files.isEmpty) {
        return ApiResult<dynamic>.error(
          message: 'No files provided',
          code: 400,
          error: 'Please select at least one file to send',
        );
      }

      // Validate all files
      int totalSize = 0;
      final List<MultipartFile> multipartFiles = [];

      for (final file in files) {
        if (!await file.exists()) {
          return ApiResult<dynamic>.error(
            message: 'File does not exist',
            code: 400,
            error: 'One or more selected files could not be found',
          );
        }

        final fileSize = await file.length();
        totalSize += fileSize;

        final maxFileSize = maxFileSizeMB * 1024 * 1024;
        if (fileSize > maxFileSize) {
          return ApiResult<dynamic>.error(
            message: 'File too large',
            code: 413,
            error: 'Each file size cannot exceed ${maxFileSizeMB}MB',
          );
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

      // Validate total size
      final maxTotalSize = maxTotalSizeMB * 1024 * 1024;
      if (totalSize > maxTotalSize) {
        return ApiResult<dynamic>.error(
          message: 'Total files too large',
          code: 413,
          error: 'Total size of all files cannot exceed ${maxTotalSizeMB}MB',
        );
      }

      // Prepare form data
      final formDataMap = <String, dynamic>{
        'files': multipartFiles,
        if (additionalFields != null) ...additionalFields,
      };
      final formData = FormData.fromMap(formDataMap);

      // Send the files
      final response = await _dio.post(
        '$baseUrl/messages/send-multiple-media',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
        onSendProgress: onSendProgress,
      );

      final parsedData = _parseResponseData(response.data);
      return ApiResult<dynamic>.fromMap(parsedData);
    } on DioException catch (e) {
      return _handleDioException<dynamic>(e);
    } catch (e) {
      return _handleException<dynamic>(e);
    }
  }
}
