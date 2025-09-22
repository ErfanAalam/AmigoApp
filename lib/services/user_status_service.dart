import 'dart:async';

/// Service to manage user online/offline status tracking
class UserStatusService {
  static final UserStatusService _instance = UserStatusService._internal();
  factory UserStatusService() => _instance;
  UserStatusService._internal();

  // Map to store online status for each user ID
  final Map<int, bool> _onlineStatus = {};

  // Stream controller for status updates
  final StreamController<Map<int, bool>> _statusController =
      StreamController<Map<int, bool>>.broadcast();

  // Getters
  Stream<Map<int, bool>> get statusStream => _statusController.stream;
  Map<int, bool> get onlineStatus => Map.unmodifiable(_onlineStatus);

  /// Check if a user is online
  bool isUserOnline(int userId) {
    return _onlineStatus[userId] ?? false;
  }

  /// Set user online status
  void setUserOnline(int userId, {bool isOnline = true}) {
    _onlineStatus[userId] = isOnline;
    _notifyStatusChange();

    if (isOnline) {
      print('🟢 User $userId is now online');
    } else {
      print('🔴 User $userId is now offline');
    }
  }

  /// Set multiple users online
  void setUsersOnline(List<int> userIds) {
    bool hasChanges = false;
    for (final userId in userIds) {
      if (_onlineStatus[userId] != true) {
        _onlineStatus[userId] = true;
        hasChanges = true;
        print('🟢 User $userId is now online');
      }
    }

    if (hasChanges) {
      _notifyStatusChange();
    }
  }

  /// Set multiple users offline
  void setUsersOffline(List<int> userIds) {
    bool hasChanges = false;
    for (final userId in userIds) {
      if (_onlineStatus[userId] != false) {
        _onlineStatus[userId] = false;
        hasChanges = true;
        print('🔴 User $userId is now offline');
      }
    }

    if (hasChanges) {
      _notifyStatusChange();
    }
  }

  /// Handle user_online WebSocket message
  void handleUserOnlineMessage(Map<String, dynamic> message) {
    try {
      final data = message['data'] as Map<String, dynamic>? ?? {};
      final userId = data['user_id'] as int?;

      if (userId != null) {
        setUserOnline(userId, isOnline: true);
      } else {
        print('⚠️ Invalid user_online message: missing user_id');
      }
    } catch (e) {
      print('❌ Error handling user_online message: $e');
    }
  }

  /// Handle user_offline WebSocket message
  void handleUserOfflineMessage(Map<String, dynamic> message) {
    try {
      final data = message['data'] as Map<String, dynamic>? ?? {};
      final userId = data['user_id'] as int?;

      if (userId != null) {
        setUserOnline(userId, isOnline: false);
      } else {
        print('⚠️ Invalid user_offline message: missing user_id');
      }
    } catch (e) {
      print('❌ Error handling user_offline message: $e');
    }
  }

  /// Handle bulk online users message (if server sends initial online users)
  void handleBulkOnlineUsersMessage(List<int> userIds) {
    setUsersOnline(userIds);
  }

  /// Clear all online status (useful when disconnecting)
  void clearAllStatus() {
    _onlineStatus.clear();
    _notifyStatusChange();
    print('🧹 Cleared all user online status');
  }

  /// Remove specific user status
  void removeUserStatus(int userId) {
    if (_onlineStatus.containsKey(userId)) {
      _onlineStatus.remove(userId);
      _notifyStatusChange();
      print('🗑️ Removed status for user $userId');
    }
  }

  /// Notify listeners about status changes
  void _notifyStatusChange() {
    _statusController.add(Map.unmodifiable(_onlineStatus));
  }

  /// Dispose resources
  void dispose() {
    _statusController.close();
  }
}
