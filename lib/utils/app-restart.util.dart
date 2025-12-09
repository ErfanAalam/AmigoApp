import 'package:restart_app/restart_app.dart';

/// Utility class for handling app restart functionality
class AppRestartHelper {
  /// Restarts the app after a successful authentication
  /// This ensures all services are properly reinitialized
  static Future<void> restartAppAfterAuth() async {
    try {
      print('🔄 Restarting app after successful authentication...');

      // Add a small delay to ensure all authentication processes complete
      await Future.delayed(const Duration(milliseconds: 1500));

      // Restart the app
      await Restart.restartApp();
    } catch (e) {
      print('❌ Error restarting app: $e');
      // If restart fails, we could show an error message or handle it gracefully
      rethrow;
    }
  }
}
