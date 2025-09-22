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
}
