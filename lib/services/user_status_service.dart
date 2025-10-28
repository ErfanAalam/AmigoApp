import 'dart:async';

import 'package:flutter/material.dart';

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
  // void setUserOnline(int userId, {bool isOnline = true}) {
  void setUserOnlineStatus(int userId, {bool isOnline = true}) {
    _onlineStatus[userId] = isOnline;
    _notifyStatusChange();
  }

  /// Handle user_online WebSocket message
  void handleUserOnlineMessage(Map<String, dynamic> message) {
    try {
      final data = message['data'] as Map<String, dynamic>? ?? {};
      final userId = data['user_id'] as int?;

      if (userId != null) {
        setUserOnlineStatus(userId, isOnline: true);
      } else {
        debugPrint('⚠️ Invalid user_online message: missing user_id');
      }
    } catch (e) {
      debugPrint('❌ Error handling user_online message');
    }
  }

  /// Handle user_offline WebSocket message
  void handleUserOfflineMessage(Map<String, dynamic> message) {
    try {
      final data = message['data'] as Map<String, dynamic>? ?? {};
      final userId = data['user_id'] as int?;

      if (userId != null) {
        setUserOnlineStatus(userId, isOnline: false);
      } else {
        debugPrint('⚠️ Invalid user_offline message: missing user_id');
      }
    } catch (e) {
      debugPrint('❌ Error handling user_offline message');
    }
  }

  /// Clear all online status (useful when disconnecting)
  void clearAllStatus() {
    _onlineStatus.clear();
    _notifyStatusChange();
  }

  /// Remove specific user status
  void removeUserStatus(int userId) {
    if (_onlineStatus.containsKey(userId)) {
      _onlineStatus.remove(userId);
      _notifyStatusChange();
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
