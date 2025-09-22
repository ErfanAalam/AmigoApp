import '../services/user_status_service.dart';

/// Demo utility to simulate user online/offline messages for testing
class UserStatusDemo {
  static final UserStatusService _userStatusService = UserStatusService();

  /// Simulate a user coming online
  static void simulateUserOnline(int userId) {
    final message = {
      'type': 'user_online',
      'data': {'user_id': userId},
    };

    print('🧪 Demo: Simulating user_online message for user $userId');
    _userStatusService.handleUserOnlineMessage(message);
  }

  /// Simulate a user going offline
  static void simulateUserOffline(int userId) {
    final message = {
      'type': 'user_offline',
      'data': {'user_id': userId},
    };

    print('🧪 Demo: Simulating user_offline message for user $userId');
    _userStatusService.handleUserOfflineMessage(message);
  }

  /// Simulate multiple users coming online at once
  static void simulateMultipleUsersOnline(List<int> userIds) {
    for (final userId in userIds) {
      simulateUserOnline(userId);
    }
  }

  /// Simulate multiple users going offline at once
  static void simulateMultipleUsersOffline(List<int> userIds) {
    for (final userId in userIds) {
      simulateUserOffline(userId);
    }
  }

  /// Get current online status for debugging
  static Map<int, bool> getCurrentStatus() {
    return _userStatusService.onlineStatus;
  }

  /// Print current online status for debugging
  static void printCurrentStatus() {
    final status = getCurrentStatus();
    print('📊 Current online status: $status');
  }
}
