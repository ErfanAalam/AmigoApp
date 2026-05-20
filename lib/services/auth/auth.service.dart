import 'package:amigo/db/sqlite.db.dart';
import 'package:amigo/env.dart';
import 'package:amigo/utils/user.utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../api/api_service.dart';
import '../../providers/chat.provider.dart';
import '../../providers/draft.provider.dart';
import '../../providers/message.provider.dart';
import '../../providers/notification-badge.provider.dart';
import '../../screens/auth/login.screen.dart';
import '../../utils/navigation-helper.util.dart';
import '../contact.service.dart';
import '../cookies.service.dart';
import '../fcm/fcm-init.service.dart';
import '../media-cache.service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../call/stream/stream_call.service.dart';
import '../socket/transport.manager.dart';
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

  // Re-entry guard. Multiple subsystems (FCM, chat list loader, refresh-token
  // interceptor, etc.) can each trip the auth-failure path concurrently on a
  // fresh install. Without this, every concurrent failure runs the full
  // teardown and pushes a new LoginScreen — visible as the login screen
  // "warping" / popping in several times.
  bool _isLoggingOut = false;

  /// Lazy getter for ApiService - only accessed after initialization
  ApiService get apiService => ApiService();

  /// Lazy getter for NotificationService - only accessed after initialization
  NotificationService get notificationService => NotificationService();

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

      // CRITICAL: Validate refresh token against server to detect if user logged in elsewhere
      // This ensures that if Device A is closed and Device B logs in, Device A will be logged out
      // when it opens the app again
      // NOTE: Skip server validation when offline to allow users to use the app offline
      // final isOnline =
      //     NetworkConnectivityUtil().currentQuality != NetworkQuality.offline;

      // if (isOnline) {
      try {
        final result = await apiService.client.validateRefreshToken();
        if (!result.isSuccess) {
          debugPrint(
            '🚪 Refresh token invalidated - user logged in on another device',
          );
          await logout();
          return false;
        }
      } on DioException catch (e) {
        // If we can't reach the server (offline), skip validation and allow offline access
        // Only logout if the server explicitly says the token is invalid, not if we can't reach it
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.unknown) {
          debugPrint(
            '⚠️ Cannot validate token (offline) - allowing offline access',
          );
          // Return true based on local checks only when offline
          return true;
        }
        // For other DioExceptions, rethrow to be handled by outer catch
        rethrow;
      }
      // }
      return true;
    } catch (e) {
      debugPrint('❌ Error checking authentication: $e');
      return false;
    }
  }

  /// Fast local-only auth check — reads from secure storage/prefs only,
  /// no network call. Used to make the app respond immediately on startup.
  /// The server-side token validation is still done in the background.
  Future<bool> isAuthenticatedLocally() async {
    try {
      final hasAuthCookies = await _cookieService.hasAuthCookies();
      if (!hasAuthCookies) return false;

      final authStatus = await _secureStorage.read(key: _authStatusKey);
      if (authStatus != 'authenticated') return false;

      final prefs = await SharedPreferences.getInstance();
      final lastLoginTime = prefs.getInt(_lastLoginTimeKey);
      if (lastLoginTime == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final thirtyDaysInMillis = 30 * 24 * 60 * 60 * 1000;
      if (now - lastLoginTime > thirtyDaysInMillis) {
        await logout();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error checking local authentication: $e');
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

  // Send FCM token to backend, gated by NotificationService's 24h/changed
  // heuristic. Pass force: true to bypass the gate (e.g., right after login).
  Future<void> sendFCMTokenToBackend({bool force = false}) async {
    try {
      await notificationService.maybeSendTokenToBackend(force: force);
    } catch (e) {
      debugPrint('❌ Error sending FCM token: $e');
    }
  }

  // Log out user
  Future<void> logout() async {
    if (_isLoggingOut) {
      debugPrint('🚪 Logout already in progress — skipping duplicate call');
      return;
    }
    _isLoggingOut = true;
    // Capture pre-logout auth state. If the user wasn't authenticated to
    // begin with (fresh install, already-logged-out state), the MaterialApp
    // `home:` builder is already rendering LoginScreen — pushing another
    // one on top plays a redundant pop-in animation. Skip the push in that
    // case.
    final hadAuthState =
        await _cookieService.hasAuthCookies() ||
            (await _secureStorage.read(key: _authStatusKey)) == 'authenticated';
    try {
      debugPrint('🚪 Logging out user...');
      // Ensure websocket is fully shut down and won't auto-reconnect
      try {
        await TransportManager().shutdown();
      } catch (_) {}

      try {
        await apiService.client.get("/auth/logout");
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

      // Reset guest mode environment so regular users aren't routed to the guest backend
      Environment.setGuestMode(false);

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

      // 7b. Tear down the Stream Video client so the next login rebinds it
      // to the new user identity. Without this the singleton retains the
      // previous user's `User.regular(...)` and outgoing calls placed under
      // the new login show the old user's name/avatar to the callee.
      try {
        await StreamCallService().dispose();
      } catch (e) {
        debugPrint('⚠️ StreamCallService.dispose failed: $e');
      }

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
      // Capture the container early so we can use it after DB operations too.
      ProviderContainer? providerContainer;
      try {
        final context = NavigationHelper.navigatorKey.currentContext;
        if (context != null) {
          providerContainer = ProviderScope.containerOf(context);

          // Clear chat provider - reset dmList and groupList
          try {
            providerContainer.read(chatProvider.notifier).clearAllState();
            debugPrint('✅ Cleared chat provider state');
          } catch (e) {
            debugPrint('⚠️ Error clearing chat provider: $e');
          }

          // Clear draft messages provider
          try {
            providerContainer
                .read(draftMessagesProvider.notifier)
                .clearAllDrafts();
            debugPrint('✅ Cleared draft messages provider state');
          } catch (e) {
            debugPrint('⚠️ Error clearing draft messages provider: $e');
          }

          // Clear notification badge provider - reset to initial state
          try {
            providerContainer
                .read(notificationBadgeProvider.notifier)
                .clearAllCounts();
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

      // Invalidate Drift stream providers AFTER the DB file is deleted and
      // _db is null. This forces them to re-subscribe to a brand-new
      // AppDatabase() the next time any screen reads them, so the new
      // account's data appears instead of stale streams from the old DB.
      if (providerContainer != null) {
        try {
          providerContainer.invalidate(dmListStreamProvider);
          providerContainer.invalidate(groupListStreamProvider);
          providerContainer.invalidate(messageStreamProvider);
          providerContainer.invalidate(userStatusStreamProvider);
          debugPrint('✅ Invalidated Drift stream providers');
        } catch (e) {
          debugPrint('⚠️ Error invalidating stream providers: $e');
        }
      }

      // 16. Restart the app — but only if the user actually had an auth
      // session to log out of. On a fresh install the home: builder is
      // already rendering LoginScreen, so pushing another one plays a
      // redundant pop-in animation.
      if (hadAuthState &&
          NavigationHelper.navigatorKey.currentContext != null) {
        Navigator.pushAndRemoveUntil(
          NavigationHelper.navigatorKey.currentContext!,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
      debugPrint('✅ Logout process completed successfully');
    } catch (e) {
      debugPrint('❌ Error during logout');
    } finally {
      _isLoggingOut = false;
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
