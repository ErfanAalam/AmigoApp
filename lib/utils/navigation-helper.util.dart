import 'package:flutter/material.dart';

class NavigationHelper {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static NavigatorState? get navigator => navigatorKey.currentState;

  static Future<T?> pushRoute<T>(Widget screen) async {
    if (navigator == null) {
      print('[NavigationHelper] ❌ Navigator not available');
      return null;
    }

    try {
      return await navigator!.push<T>(
        MaterialPageRoute(builder: (context) => screen, fullscreenDialog: true),
      );
    } catch (e) {
      print('[NavigationHelper] ❌ Error pushing route: $e');
      return null;
    }
  }

  static Future<T?> pushNamed<T>(String routeName, {Object? arguments}) async {
    if (navigator == null) {
      print('[NavigationHelper] ❌ Navigator not available');
      return null;
    }

    try {
      return await navigator!.pushNamed<T>(routeName, arguments: arguments);
    } catch (e) {
      print('[NavigationHelper] ❌ Error pushing named route: $e');
      return null;
    }
  }

  /// Push route with retry mechanism for when navigator is not immediately available
  static Future<T?> pushRouteWithRetry<T>(
    Widget screen, {
    int maxRetries = 15,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      if (navigator != null) {
        print('[NavigationHelper] ✅ Navigator ready, attempting navigation');
        try {
          return await navigator!.push<T>(
            MaterialPageRoute(
              builder: (context) => screen,
              fullscreenDialog: true,
            ),
          );
        } catch (e) {
          print('[NavigationHelper] ❌ Error during navigation: $e');
          return null;
        }
      }

      print(
        '[NavigationHelper] ⏳ Navigator not ready, retrying in ${retryDelay.inMilliseconds}ms... (${maxRetries - i - 1} retries left)',
      );
      await Future.delayed(retryDelay);
    }

    print('[NavigationHelper] ❌ Max retries reached, navigation failed');
    return null;
  }
}
