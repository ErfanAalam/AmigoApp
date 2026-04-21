import 'dart:async';
import 'package:flutter/material.dart';

import 'package:amigo/types/socket.types.dart';

/// Service to manage user online/offline status tracking
class UserStatusService {
  static final UserStatusService _instance = UserStatusService._internal();
  factory UserStatusService() => _instance;
  UserStatusService._internal();

  // Map to store online status for each user ID
  final Map<String, bool> _usersOnlineStatus = {};

  // Stream controller for status updates
  final StreamController<Map<String, bool>> _onlineStatusController =
      StreamController<Map<String, bool>>.broadcast();

  // Getters
  Stream<Map<String, bool>> get userStatusStream =>
      _onlineStatusController.stream;
  Map<String, bool> get onlineStatus => Map.unmodifiable(_usersOnlineStatus);

  /// Check if a user is online
  bool isUserOnline(String userId) {
    return _usersOnlineStatus[userId] ?? false;
  }

  /// Set user online status
  void setUserOnlineStatus(String userId, {bool isOnline = true}) {
    _usersOnlineStatus[userId] = isOnline;
    _notifyStatusChange();
  }

  /// Handle connection:status WebSocket message.
  /// Backend sends 'online' | 'offline' | 'stale' (not 'foreground'/'background').
  void handleUserOnlineMessage(ConnectionStatusPayload payload) {
    try {
      setUserOnlineStatus(
        payload.senderId,
        isOnline: payload.status == 'online',
      );
    } catch (e) {
      debugPrint('❌ Error handling connection:status message: $e');
    }
  }

  /// Clear all online status (useful when disconnecting)
  void clearAllStatus() {
    _usersOnlineStatus.clear();
    _notifyStatusChange();
  }

  /// Remove specific user status
  void removeUserStatus(String userId) {
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
