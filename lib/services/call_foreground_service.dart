import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Foreground task handler for keeping microphone active during calls
@pragma('vm:entry-point')
void startCallbackForForeground() {
  FlutterForegroundTask.setTaskHandler(CallForegroundTaskHandler());
}

class CallForegroundTaskHandler extends TaskHandler {
  // This will be called whenever a notification is received
  @override
  Future<void> onDestroy(DateTime timestamp) async {
    print('[ForegroundService] Service destroyed at $timestamp');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // This is called every interval (e.g., every 5 seconds)
    // Just keep the service alive, no action needed
    FlutterForegroundTask.updateService(
      notificationTitle: 'Call in progress',
      notificationText: 'Microphone active',
    );
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('[ForegroundService] Service started at $timestamp');
  }

  @override
  Future<void> onNotificationButtonPressed(String id) async {
    print('[ForegroundService] Notification button pressed: $id');
  }

  @override
  Future<void> onNotificationPressed() async {
    print('[ForegroundService] Notification pressed');
  }

  @override
  Future<void> onNotificationDismissed() async {
    print('[ForegroundService] Notification dismissed');
  }
}

class CallForegroundService {
  static bool _isRunning = false;

  /// Initialize foreground service (call this once at app startup)
  static Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'call_foreground_service',
        channelName: 'Call Service',
        channelDescription: 'Keeps microphone active during calls',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          5000,
        ), // repeat every 5 seconds
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start foreground service for a call
  static Future<bool> startService({required String callerName}) async {
    if (_isRunning) {
      print('[ForegroundService] Service already running');
      return true;
    }

    try {
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Call in progress',
        notificationText: 'Call with $callerName',
        notificationButtons: [
          const NotificationButton(id: 'end_call', text: 'End Call'),
        ],
        callback: startCallbackForForeground,
      );

      _isRunning = true;
      print('[ForegroundService] ✅ Service started successfully');
      return true;
    } catch (e) {
      print('[ForegroundService] ❌ Error starting service: $e');
      return false;
    }
  }

  /// Update foreground notification (e.g., when call status changes)
  static Future<bool> updateService({String? title, String? text}) async {
    if (!_isRunning) return false;

    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: title ?? 'Call in progress',
        notificationText: text ?? 'Microphone active',
      );
      return true;
    } catch (e) {
      print('[ForegroundService] Error updating service: $e');
      return false;
    }
  }

  /// Stop foreground service when call ends
  static Future<bool> stopService() async {
    if (!_isRunning) {
      print('[ForegroundService] Service not running');
      return true;
    }

    try {
      await FlutterForegroundTask.stopService();
      _isRunning = false;
      print('[ForegroundService] ✅ Service stopped successfully');
      return true;
    } catch (e) {
      print('[ForegroundService] ❌ Error stopping service: $e');
      _isRunning = false;
      return false;
    }
  }

  /// Check if foreground service is currently running
  static bool get isRunning => _isRunning;

  /// Check if the service is actually running (query from system)
  static Future<bool> isServiceRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}
