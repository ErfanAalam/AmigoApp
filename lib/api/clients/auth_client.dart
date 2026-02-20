import '../../services/location.service.dart';
import '../core/api_result.dart';
import '../core/base_api_client.dart';
import 'ip_client.dart';

/// Authentication API client
class AuthClient extends BaseApiClient {
  AuthClient({
    required super.dio,
    required super.cookieService,
    required super.authService,
  });

  /// Generate signup OTP
  Future<ApiResult<dynamic>> generateSignupOtp(
    String phoneNumber,
  ) async {
    return post('/auth/generate-signup-otp/$phoneNumber');
  }

  /// Verify signup OTP
  Future<ApiResult<dynamic>> verifySignupOtp({
    required String phoneNumber,
    required int otp,
    required String firstName,
    required String lastName,
  }) async {
    return post(
      '/auth/verify-signup-otp',
      data: {
        'phone': phoneNumber,
        'otp': otp,
        'name': '$firstName $lastName',
        'role': 'user',
      },
    );
  }

  /// Request signup
  Future<ApiResult<dynamic>> requestSignup({
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    return post(
      '/auth/request-signup',
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phoneNumber,
      },
    );
  }

  /// Get signup request status
  Future<ApiResult<dynamic>> getSignupRequestStatus(
    String phoneNumber,
  ) async {
    return get('/auth/signup-request-status/$phoneNumber');
  }

  /// Send login OTP
  Future<ApiResult<dynamic>> sendLoginOtp(
    String phoneNumber,
  ) async {
    return post('/auth/generate-login-otp/$phoneNumber');
  }

  /// Verify login OTP
  Future<ApiResult<dynamic>> verifyLoginOtp({
    required String phoneNumber,
    required int otp,
  }) async {
    return post(
      '/auth/verify-login-otp',
      data: {'phone': phoneNumber, 'otp': otp},
    );
  }

  /// Update user location and IP
  Future<ApiResult<void>> updateUserLocationAndIp() async {
    try {
      final locationService = LocationService();
      final ipService = IpClient();

      // Get location and IP concurrently
      final futures = await Future.wait([
        locationService.getCurrentLocation(),
        ipService.getDetailedIpInfo(),
      ]);

      final locationResult = futures[0];
      final ipResult = futures[1];

      final lat = locationResult['latitude'];
      final lng = locationResult['longitude'];

      final data = <String, dynamic>{
        'ip_address': ipResult['ip']?.toString(),
      };

      if (lat != null && lng != null) {
        data['location'] = {'latitude': lat, 'longitude': lng};
      }

      final result = await post('/user/update-user', data: data);
      // Convert Map result to void result
      if (result.isSuccess) {
        return ApiResult<void>.success(
          data: null,
          code: result.code,
          message: result.message,
        );
      }
      return ApiResult<void>.error(
        message: result.message,
        code: result.code,
        error: result.error,
      );
    } catch (e) {
      return ApiResult<void>.error(
        message: 'Failed to update location and IP',
        code: 500,
        error: e.toString(),
      );
    }
  }

  /// Update FCM token
  Future<ApiResult<dynamic>> updateFCMToken(
    String fcmToken,
  ) async {
    return post(
      '/user/update-fcm-token',
      data: {'fcm_token': fcmToken},
    );
  }
}
