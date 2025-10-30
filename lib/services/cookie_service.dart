import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../env.dart';

class CookieService {
  static final CookieService _instance = CookieService._internal();
  late PersistCookieJar _cookieJar;
  bool _initialized = false;

  factory CookieService() {
    return _instance;
  }

  CookieService._internal();

  Future<void> init() async {
    if (_initialized) return;

    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final appDocPath = appDocDir.path;

      _cookieJar = PersistCookieJar(
        storage: FileStorage("$appDocPath/.cookies/"),
        ignoreExpires: false,
      );

      _initialized = true;
    } catch (e) {
      debugPrint('❌ Error initializing cookie service');
    }
  }

  PersistCookieJar get cookieJar {
    return _cookieJar;
  }

  // Check if authentication cookies exist
  Future<bool> hasAuthCookies() async {
    if (!_initialized) await init();

    try {
      final baseUrl = Uri.parse(Environment.baseUrl);
      final cookies = await _cookieJar.loadForRequest(baseUrl);

      // Check for auth cookies - look for common names
      bool hasAuthCookie = cookies.any(
        (cookie) => cookie.name.toLowerCase().contains('token'),
      );

      // print('🔍 Auth cookies found: $hasAuthCookie');
      return hasAuthCookie;
    } catch (e) {
      debugPrint('❌ Error checking auth cookies');
      return false;
    }
  }

  // Clear all cookies
  Future<void> clearAllCookies() async {
    if (!_initialized) await init();

    try {
      await _cookieJar.deleteAll();
      print('🗑️ All cookies cleared');
    } catch (e) {
      print('❌ Error clearing cookies: $e');
    }
  }

  // Get access token from cookies
  Future<String?> getAccessToken() async {
    if (!_initialized) await init();

    try {
      final baseUrl = Uri.parse(Environment.baseUrl);
      final cookies = await _cookieJar.loadForRequest(baseUrl);

      // Look for common access token cookie names
      final tokenCookieNames = [
        'access_token',
        'accessToken',
        'token',
        'auth_token',
        'jwt',
        'session',
      ];

      for (final cookie in cookies) {
        if (tokenCookieNames.any(
          (name) => cookie.name.toLowerCase().contains(name.toLowerCase()),
        )) {
          print('🔑 Found access token cookie: ${cookie.name}');
          return cookie.value;
        }
      }

      print('⚠️ No access token found in cookies');
      return null;
    } catch (e) {
      print('❌ Error extracting access token from cookies: $e');
      return null;
    }
  }

  // Debug method to list all cookies (don't use in production)
  Future<void> debugListCookies() async {
    if (!_initialized) await init();

    try {
      final baseUrl = Uri.parse(Environment.baseUrl);
      final cookies = await _cookieJar.loadForRequest(baseUrl);

      print('🍪 All cookies (${cookies.length}):');
      for (var cookie in cookies) {
        // Only print name and domain for security
        print(
          '- ${cookie.name} (domain: ${cookie.domain}, httpOnly: ${cookie.httpOnly})',
        );
      }
    } catch (e) {
      print('❌ Error listing cookies: $e');
    }
  }
}
