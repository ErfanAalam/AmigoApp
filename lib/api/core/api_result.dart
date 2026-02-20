/// Result type matching backend ResultType<T>
/// Every API response follows this structure
class ApiResult<T> {
  final bool success;
  final int code;
  final String message;
  final T? data;
  final dynamic error;

  const ApiResult({
    required this.success,
    required this.code,
    required this.message,
    this.data,
    this.error,
  });

  /// Create a successful result
  factory ApiResult.success({
    required T data,
    int code = 200,
    String message = 'Success',
  }) {
    return ApiResult<T>(
      success: true,
      code: code,
      message: message,
      data: data,
    );
  }

  /// Create an error result
  factory ApiResult.error({
    required String message,
    int code = 500,
    dynamic error,
  }) {
    return ApiResult<T>(
      success: false,
      code: code,
      message: message,
      error: error,
    );
  }

  /// Create from backend response Map
  factory ApiResult.fromMap(Map<String, dynamic> map) {
    // Get the data from the map
    final data = map['data'];
    
    // When T is dynamic (or not specified), preserve the actual data type
    // This allows Lists, Maps, primitives, etc. to be preserved as-is
    // For typed results, attempt to cast to T
    T? typedData;
    
    if (data == null) {
      typedData = null;
    } else {
      // For dynamic type, just assign directly (preserves actual type)
      // For other types, attempt cast (will throw if incompatible, which is expected)
      typedData = data as T?;
    }
    
    return ApiResult<T>(
      success: map['success'] as bool? ?? false,
      code: map['code'] as int? ?? (map['success'] == true ? 200 : 500),
      message: map['message'] as String? ?? '',
      data: typedData,
      error: map['error'],
    );
  }

  /// Returns true if the result is successful
  bool get isSuccess => success;

  /// Returns true if the result is successful and has non-null data
  bool get hasData => success && data != null;

  /// Returns true if the result is an error
  bool get isError => !success;

  /// Gets the data if successful, null otherwise
  T? get dataOrNull => success ? data : null;

  /// Gets the error message
  String get errorMessage => message;

  /// Map the data to a different type
  ApiResult<R> map<R>(R Function(T data) mapper) {
    if (success && data != null) {
      return ApiResult.success(
        data: mapper(data as T),
        code: code,
        message: message,
      );
    }
    return ApiResult.error(message: message, code: code, error: error);
  }

  /// Execute a function if successful
  ApiResult<T> onSuccess(void Function(T data) handler) {
    if (success && data != null) {
      handler(data as T);
    }
    return this;
  }

  /// Execute a function if error
  ApiResult<T> onError(
    void Function(String message, int code, dynamic error) handler,
  ) {
    if (!success) {
      handler(message, code, error);
    }
    return this;
  }

  /// Get the result as a Map (for backward compatibility)
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'code': code,
      'message': message,
      if (data != null) 'data': data,
      if (error != null) 'error': error,
    };
  }

  @override
  String toString() {
    return 'ApiResult(success: $success, code: $code, message: $message, data: $data, error: $error)';
  }
}
