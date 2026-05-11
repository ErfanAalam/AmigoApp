import '../core/api_result.dart';
import '../core/base_api_client.dart';

class VersionClient extends BaseApiClient {
  VersionClient({
    required super.dio,
    required super.cookieService,
    required super.authService,
  });

  Future<ApiResult<dynamic>> getAppVersion(String platform) async {
    return get('/app/version?platform=$platform');
  }
}
