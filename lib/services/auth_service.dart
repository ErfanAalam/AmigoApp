import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cookie_service.dart';
import 'package:amigo/api/user.service.dart' as userService;

class AuthService {
  static const String _authStatusKey = 'auth_status';
  static const String _lastLoginTimeKey = 'last_login_time';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final CookieService _cookieService = CookieService();

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    try {
      // First check if auth cookies exist
      final hasAuthCookies = await _cookieService.hasAuthCookies();
      if (!hasAuthCookies) {
        return false;
      }

      // Check if auth status is stored in secure storage
      final authStatus = await _secureStorage.read(key: _authStatusKey);
      if (authStatus != 'authenticated') {
        return false;
      }

      // Check if login session is still valid
      final prefs = await SharedPreferences.getInstance();
      final lastLoginTime = prefs.getInt(_lastLoginTimeKey);
      if (lastLoginTime == null) {
        return false;
      }

      // You can implement session expiry logic here
      // For example, check if login was within the last 30 days
      final now = DateTime.now().millisecondsSinceEpoch;
      final thirtyDaysInMillis = 30 * 24 * 60 * 60 * 1000;
      if (now - lastLoginTime > thirtyDaysInMillis) {
        await logout();
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  // Set user as authenticated after successful login
  Future<void> setAuthenticated() async {
    try {
      await _secureStorage.write(key: _authStatusKey, value: 'authenticated');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastLoginTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error setting authentication status: $e');
    }
  }

  // Log out user
  Future<void> logout() async {
    try {
      // Clear authentication status
      await _secureStorage.delete(key: _authStatusKey);

      // Clear login timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastLoginTimeKey);

      // Clear cookies using the cookie service
      await _cookieService.clearAllCookies();
    } catch (e) {
      print('❌ Error during logout: $e');
    }
  }

  // Get current user ID
  Future<int?> getCurrentUserId() async {
    try {
      final userServiceInstance = userService.UserService();
      final response = await userServiceInstance.getUser();
      if (response['success'] == true && response['data'] != null) {
        final userData = response['data'];
        final id = userData['id'];
        
        if (id is int) {
          return id;
        } else if (id is String) {
          return int.tryParse(id);
        } else {
          return int.tryParse(id.toString());
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting current user ID: $e');
      return null;
    }
  }
}
