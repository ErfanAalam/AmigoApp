import 'dart:async';
import 'package:flutter/material.dart';

import 'package:amigo/types/socket.types.dart';

/// Service to manage user online/offline status tracking
class UserStatusService {
  static final UserStatusService _instance = UserStatusService._internal();
  factory UserStatusService() => _instance;
  UserStatusService._internal();

  // Map to store online status for each user ID
  final Map<int, bool> _usersOnlineStatus = {};

  // Stream controller for status updates
  final StreamController<Map<int, bool>> _onlineStatusController =
      StreamController<Map<int, bool>>.broadcast();

  // Getters
  Stream<Map<int, bool>> get userStatusStream => _onlineStatusController.stream;
  Map<int, bool> get onlineStatus => Map.unmodifiable(_usersOnlineStatus);

  /// Check if a user is online
  bool isUserOnline(int userId) {
    return _usersOnlineStatus[userId] ?? false;
  }

  /// Set user online status
  // void setUserOnline(int userId, {bool isOnline = true}) {
  void setUserOnlineStatus(int userId, {bool isOnline = true}) {
    _usersOnlineStatus[userId] = isOnline;
    _notifyStatusChange();
  }

  /// Handle user_online WebSocket message
  void handleUserOnlineMessage(ConnectionStatus payload) {
    try {
      setUserOnlineStatus(
        payload.senderId,
        isOnline: payload.status == 'foreground',
      );
    } catch (e) {
      debugPrint('❌ Error handling user_online message');
    }
  }

  /// Clear all online status (useful when disconnecting)
  void clearAllStatus() {
    _usersOnlineStatus.clear();
    _notifyStatusChange();
  }

  /// Remove specific user status
  void removeUserStatus(int userId) {
    if (_usersOnlineStatus.containsKey(userId)) {
      _usersOnlineStatus.remove(userId);
      _notifyStatusChange();
    }
  }

  /// Notify listeners about status changes
  void _notifyStatusChange() {
    _onlineStatusController.add(Map.unmodifiable(_usersOnlineStatus));
  }

  /// Dispose resources
  void dispose() {
    _onlineStatusController.close();
  }
}
