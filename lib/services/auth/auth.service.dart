import 'package:amigo/db/sqlite.db.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../api/auth.api-client.dart';
import '../../providers/chat.provider.dart';
import '../../providers/draft.provider.dart';
import '../../providers/notification-badge.provider.dart';
import '../../screens/auth/login.screen.dart';
import '../../utils/navigation-helper.util.dart';
import '../contact.service.dart';
import '../cookies.service.dart';
import '../media-cache.service.dart';
import '../notification.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../socket/websocket.service.dart';
import '../user-status.service.dart';

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
        final response = await ApiService().updateFCMToken(fcmToken);
        if (response['success'] == true) {
          debugPrint('✅ FCM token sent to backend successfully');
        } else {
          if (retry == null || retry <= 0) {
            debugPrint('❌ Failed to get FCM token after multiple attempts');
            return;
          }
          await sendFCMTokenToBackend(retry - 1);
        }
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

      // 5. Clear media cache
      final mediaCacheService = MediaCacheService();
      await mediaCacheService.clearAllCache();

      // 6. Clear CachedNetworkImage cache
      await _clearCachedNetworkImages();

      // 7. Clear notification data
      final notificationService = NotificationService();
      await notificationService.clearNotificationData();

      // 8. Clear user status data
      final userStatusService = UserStatusService();
      userStatusService.clearAllStatus();

      // 9. Clear contact cache
      final contactService = ContactService();
      contactService.clearCache();

      // 10. Clear app cache directories
      await _clearAppCacheDirectories();

      // 11. Clear temporary files
      await _clearTemporaryFiles();

      // 12. Clear user details from shared preferences
      await UserUtils().clearUserDetails();

      // 13. Clear current_user_name
      await prefs.remove('current_user_name');

      // 14. Clear all provider states
      try {
        final context = NavigationHelper.navigatorKey.currentContext;
        if (context != null) {
          final container = ProviderScope.containerOf(context);

          // Clear chat provider - reset dmList and groupList
          try {
            container.read(chatProvider.notifier).clearAllState();
            debugPrint('✅ Cleared chat provider state');
          } catch (e) {
            debugPrint('⚠️ Error clearing chat provider: $e');
          }

          // Clear draft messages provider
          try {
            container.read(draftMessagesProvider.notifier).clearAllDrafts();
            debugPrint('✅ Cleared draft messages provider state');
          } catch (e) {
            debugPrint('⚠️ Error clearing draft messages provider: $e');
          }

          // Clear notification badge provider - reset to initial state
          try {
            container.read(notificationBadgeProvider.notifier).clearAllCounts();
            debugPrint('✅ Cleared notification badge provider state');
          } catch (e) {
            debugPrint('⚠️ Error clearing notification badge provider: $e');
          }
        } else {
          debugPrint(
            '⚠️ Navigator context not available for clearing providers',
          );
        }
      } catch (e) {
        debugPrint('⚠️ Error clearing provider states: $e');
      }

      // 15. Clear the local database completely
      try {
        // Try to clear all data from tables first
        // If this fails (e.g., read-only), we'll just delete the file
        await SqliteDatabase.instance.clearAllData();
      } catch (e) {
        debugPrint('⚠️ Could not clear database tables: $e');
        // Continue to delete the file anyway
      }

      try {
        // Delete the database file entirely to ensure no data remains
        // This will work even if clearing tables failed
        await SqliteDatabase.instance.deleteDatabaseFile();
        debugPrint('✅ Database file deletion attempted');
      } catch (e) {
        debugPrint('⚠️ Error deleting database file: $e');
        // Still try to close the database
        try {
          await SqliteDatabase.instance.close();
        } catch (_) {}
      }

      // 16. Restart the app
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
}
