import 'package:restart_app/restart_app.dart';
import 'package:flutter/material.dart';

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

  /// Shows a loading dialog while restarting the app
  // static void showRestartDialog(BuildContext context) {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return WillPopScope(
  //         onWillPop: () async => false,
  //         child: AlertDialog(
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               const CircularProgressIndicator(),
  //               const SizedBox(height: 16),
  //               const Text(
  //                 'Restarting app...',
  //                 style: TextStyle(fontSize: 16),
  //               ),
  //               const SizedBox(height: 8),
  //               const Text(
  //                 'Please wait while we restart the app to complete your authentication.',
  //                 textAlign: TextAlign.center,
  //                 style: TextStyle(fontSize: 14, color: Colors.grey),
  //               ),
  //             ],
  //           ),
  //         ),
  //       );
  //     },
  //   );
  // }

  /// Restarts the app with a loading dialog
  static Future<void> restartAppWithDialog(BuildContext context) async {
    // Show loading dialog
    // showRestartDialog(context);

    // Wait a bit for the dialog to show
    // await Future.delayed(const Duration(milliseconds: 300));

    // Restart the app
    // await restartAppAfterAuth();
  }
}
