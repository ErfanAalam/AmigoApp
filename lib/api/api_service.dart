import 'package:dio/dio.dart';

import '../services/auth/auth.service.dart';
import '../services/cookies.service.dart';
import 'clients/auth_client.dart';
import 'clients/chat_client.dart';
import 'clients/group_client.dart';
import 'clients/user_client.dart';
import 'core/api_client.dart';

/// Main API service that provides access to all domain-specific clients
class ApiService {
  static ApiService? _instance;
  late final AuthClient _authClient;
  late final ChatClient _chatClient;
  late final GroupClient _groupClient;
  late final UserClient _userClient;
  late final ApiClient _apiClient;
  late final Dio _dio;
  late final CookieService _cookieService;
  late final AuthService _authService;

  ApiService._internal({
    required Dio dio,
    required CookieService cookieService,
    required AuthService authService,
  })  : _dio = dio,
        _cookieService = cookieService,
        _authService = authService {
    _apiClient = ApiClient.instance();
    _authClient = AuthClient(
      dio: dio,
      cookieService: cookieService,
      authService: authService,
    );
    _chatClient = ChatClient(
      dio: dio,
      cookieService: cookieService,
      authService: authService,
    );
    _groupClient = GroupClient(
      dio: dio,
      cookieService: cookieService,
      authService: authService,
    );
    _userClient = UserClient(
      dio: dio,
      cookieService: cookieService,
      authService: authService,
    );
  }

  /// Initialize the API service
  /// Must be called before using any API clients
  static Future<void> initialize({
    required Dio dio,
    required CookieService cookieService,
    required AuthService authService,
  }) async {
    await ApiClient.initialize(
      dio: dio,
      cookieService: cookieService,
      authService: authService,
    );

    _instance = ApiService._internal(
      dio: dio,
      cookieService: cookieService,
      authService: authService,
    );
  }

  /// Get the singleton instance
  factory ApiService() {
    if (_instance == null) {
      throw StateError(
        'ApiService not initialized. Call ApiService.initialize() first.',
      );
    }
    return _instance!;
  }

  // Getters for domain-specific clients
  AuthClient get auth => _authClient;
  ChatClient get chat => _chatClient;
  GroupClient get group => _groupClient;
  UserClient get user => _userClient;
  ApiClient get client => _apiClient;
}
