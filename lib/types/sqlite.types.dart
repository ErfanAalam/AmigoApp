/// Result type for SQLite operations
/// Used to handle database operations with proper error handling
class SqliteResult<T> {
  final bool success;
  final int? errorCode;
  final String message;
  final T? data;

  const SqliteResult({
    required this.success,
    this.errorCode,
    required this.message,
    this.data,
  });

  /// Create a successful result
  factory SqliteResult.success({T? data, String message = 'Success'}) {
    return SqliteResult<T>(success: true, message: message, data: data);
  }

  /// Create an error result
  factory SqliteResult.error({required String message, int? errorCode}) {
    return SqliteResult<T>(
      success: false,
      errorCode: errorCode,
      message: message,
    );
  }

  /// Check if this is a duplicate insertion error (SQLite error code 1555)
  bool get isDuplicateError => errorCode == 1555;

  /// Returns true if the result is successful
  bool get isSuccess => success;

  /// Returns true if the result is an error
  bool get isError => !success;

  /// Gets the data if successful, null otherwise
  T? get dataOrNull => success ? data : null;

  /// Gets the error message
  String get errorMessage => message;

  /// Convert to Map for backward compatibility
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      if (errorCode != null) 'errorCode': errorCode,
      'message': message,
      if (data != null) 'result': data,
    };
  }

  @override
  String toString() {
    return 'SqliteResult(success: $success, errorCode: $errorCode, message: $message, data: $data)';
  }
}
