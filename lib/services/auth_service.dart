import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'cookie_service.dart';
import 'message_storage_service.dart';
import 'chat_preferences_service.dart';
import 'notification_service.dart';
import 'contact_service.dart';
import 'user_status_service.dart';
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
      print('🚪 Starting comprehensive logout process...');

      // 1. Clear authentication status and secure storage
      print('🔐 Clearing secure storage...');
      await _secureStorage.delete(key: _authStatusKey);
      await _secureStorage.deleteAll();

      // 2. Clear SharedPreferences (includes login timestamp and all app preferences)
      print('📱 Clearing SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastLoginTimeKey);
      await prefs.clear();

      // 3. Clear cookies using the cookie service
      print('🍪 Clearing cookies...');
      await _cookieService.clearAllCookies();

      // 4. Clear message storage cache
      print('💬 Clearing message storage cache...');
      final messageStorage = MessageStorageService();
      await messageStorage.clearAllCache();

      // 5. Clear chat preferences
      print('⚙️ Clearing chat preferences...');
      final chatPreferences = ChatPreferencesService();
      await chatPreferences.clearAllPreferences();

      // 6. Clear notification data
      print('🔔 Clearing notification data...');
      final notificationService = NotificationService();
      await notificationService.clearNotificationData();

      // 7. Clear user status data
      print('👤 Clearing user status data...');
      final userStatusService = UserStatusService();
      userStatusService.clearAllStatus();

      // 8. Clear contact cache
      print('📞 Clearing contact cache...');
      final contactService = ContactService();
      contactService.clearCache();

      // 9. Clear app cache directories
      print('🗂️ Clearing app cache directories...');
      await _clearAppCacheDirectories();

      // 10. Clear temporary files
      print('🗑️ Clearing temporary files...');
      await _clearTemporaryFiles();

      print('✅ Comprehensive logout completed successfully');
    } catch (e) {
      print('❌ Error during logout: $e');
      // Continue with logout even if some steps fail
    }
  }

  /// Clear app cache directories
  Future<void> _clearAppCacheDirectories() async {
    try {
      // Clear application documents directory cache
      final appDocDir = await getApplicationDocumentsDirectory();
      await _clearDirectoryContents(appDocDir);

      // Clear application support directory cache
      final appSupportDir = await getApplicationSupportDirectory();
      await _clearDirectoryContents(appSupportDir);

      // Clear temporary directory
      final tempDir = await getTemporaryDirectory();
      await _clearDirectoryContents(tempDir);

      print('🗂️ App cache directories cleared');
    } catch (e) {
      print('❌ Error clearing app cache directories: $e');
    }
  }

  /// Clear temporary files
  Future<void> _clearTemporaryFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();

      // List all files in temp directory
      final tempFiles = tempDir.listSync(recursive: true);

      for (final file in tempFiles) {
        if (file is File) {
          try {
            await file.delete();
          } catch (e) {
            // Ignore errors for individual files
            print('⚠️ Could not delete temp file: ${file.path}');
          }
        }
      }

      print('🗑️ Temporary files cleared');
    } catch (e) {
      print('❌ Error clearing temporary files: $e');
    }
  }

  /// Clear contents of a directory (but keep the directory itself)
  Future<void> _clearDirectoryContents(Directory directory) async {
    try {
      if (!await directory.exists()) return;

      final contents = directory.listSync(recursive: true);

      for (final entity in contents) {
        try {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (e) {
          // Ignore errors for individual files/directories
          print('⚠️ Could not delete: ${entity.path}');
        }
      }
    } catch (e) {
      print('❌ Error clearing directory contents: $e');
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
