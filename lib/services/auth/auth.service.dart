import 'package:amigo/api/api_service.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../cookie_service.dart';
import '../socket/websocket_service.dart';
import '../message_storage_service.dart';
import '../chat_preferences_service.dart';
import '../notification_service.dart';
import '../contact_service.dart';
import '../user_status_service.dart';
import '../last_message_storage_service.dart';
import 'package:amigo/api/user.service.dart' as user_service;
import 'package:amigo/utils/navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:amigo/screens/auth/login_screen.dart';
import 'package:amigo/db/database_helper.dart';
import '../media_cache_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AuthService {
  static const String _authStatusKey = 'auth_status';
  static const String _lastLoginTimeKey = 'last_login_time';

  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final CookieService _cookieService = CookieService();

  final NotificationService notificationService = NotificationService();

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
      debugPrint('Error setting authentication status');
    }
  }

  // Send FCM token to backend
  Future<void> sendFCMTokenToBackend([int? retry]) async {
    try {
      // Initialize notification service if not already done
      await notificationService.initialize();

      // Get the FCM token
      final fcmToken = notificationService.fcmToken;

      if (fcmToken != null && fcmToken.isNotEmpty) {
        await ApiService().updateFCMToken(fcmToken);
      } else {
        // Retry getting the token after a short delay
        if (retry == null || retry <= 0) {
          debugPrint('❌ Failed to get FCM token after multiple attempts');
          return;
        }
        await sendFCMTokenToBackend(retry - 1);
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM token');
    }
  }

  // Log out user
  Future<void> logout() async {
    try {
      // Ensure websocket is fully shut down and won't auto-reconnect
      try {
        await WebSocketService().shutdown();
      } catch (_) {}

      try {
        await ApiService().authenticatedGet("/auth/logout");
      } catch (e) {
        debugPrint('⚠️ Server logout failed (continuing with local logout)');
      }

      // 2. Clear authentication status and secure storage
      await _secureStorage.delete(key: _authStatusKey);
      await _secureStorage.deleteAll();

      // 3. Clear SharedPreferences (includes login timestamp and all app preferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastLoginTimeKey);
      await prefs.remove('fcm_token');
      await prefs.clear();

      // 4. Clear cookies using the cookie service
      await _cookieService.clearAllCookies();

      // 5. Clear message storage cache
      final messageStorage = MessageStorageService();
      await messageStorage.clearAllCache();

      // 6. Clear media cache
      final mediaCacheService = MediaCacheService();
      await mediaCacheService.clearAllCache();

      // 7. Clear CachedNetworkImage cache
      await _clearCachedNetworkImages();

      // 8. Clear chat preferences
      final chatPreferences = ChatPreferencesService();
      await chatPreferences.clearAllPreferences();

      // 9. Clear notification data
      final notificationService = NotificationService();
      await notificationService.clearNotificationData();

      // 10. Clear user status data
      final userStatusService = UserStatusService();
      userStatusService.clearAllStatus();

      // 11. Clear contact cache
      final contactService = ContactService();
      contactService.clearCache();

      // 12. Clear last message storage
      final lastMessageStorage = LastMessageStorageService.instance;
      await lastMessageStorage.clearAllLastMessages();

      // 13. Clear local database
      final databaseHelper = DatabaseHelper.instance;
      await databaseHelper.clearAllData();
      await databaseHelper.resetInstance();

      // 14. Clear app cache directories
      await _clearAppCacheDirectories();

      // 15. Clear temporary files
      await _clearTemporaryFiles();

      // 16. Clear user details from shared preferences
      await UserUtils().clearUserDetails();

      // 17. Clear current_user_name
      await prefs.remove('current_user_name');

      // 18. Restart the app
      if (NavigationHelper.navigatorKey.currentContext != null) {
        Navigator.pushAndRemoveUntil(
          NavigationHelper.navigatorKey.currentContext!,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error during logout');
    }
  }

  /// Clear CachedNetworkImage cache
  Future<void> _clearCachedNetworkImages() async {
    try {
      // Clear both the cache and file system for CachedNetworkImage
      final cacheManager = DefaultCacheManager();
      await cacheManager.emptyCache();
    } catch (e) {
      debugPrint('❌ Error clearing CachedNetworkImage cache');
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
    } catch (e) {
      debugPrint('❌ Error clearing app cache directories');
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
            debugPrint('⚠️ Could not delete temp file: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error clearing temporary files');
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
          debugPrint('⚠️ Could not delete: ${entity.path}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error clearing directory contents');
    }
  }

  // Get current user ID
  Future<int?> getCurrentUserId() async {
    try {
      final userServiceInstance = user_service.UserService();
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
      debugPrint('❌ Error getting current user ID');
      return null;
    }
  }
}
