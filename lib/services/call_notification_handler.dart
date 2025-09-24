import 'dart:async';
import 'package:amigo/services/notification_service.dart';
import 'package:amigo/services/call_service.dart';
import 'package:amigo/services/websocket_service.dart';
import 'package:amigo/utils/navigation_helper.dart';
import 'package:amigo/screens/call/incoming_call_screen.dart';

class CallNotificationHandler {
  static final CallNotificationHandler _instance = CallNotificationHandler._internal();
  factory CallNotificationHandler() => _instance;
  CallNotificationHandler._internal();

  final NotificationService _notificationService = NotificationService();
  final CallService _callService = CallService();
  final WebSocketService _websocketService = WebSocketService();
  
  StreamSubscription? _callNotificationSubscription;

  /// Initialize the call notification handler
  void initialize() {
    _callNotificationSubscription = _notificationService.callNotificationStream.listen(_handleCallNotification);
    print('📞 CallNotificationHandler initialized');
  }

  /// Handle call notifications from the notification service
  void _handleCallNotification(Map<String, dynamic> data) {
    print('📞 Handling call notification: $data');
    
    final action = data['action'] as String?;
    final callId = data['callId'] as String?;
    final callerId = data['callerId'] as String?;
    final callerName = data['callerName'] as String?;
    final callType = data['callType'] as String?;
    
    if (callId == null) {
      print('❌ Call notification missing callId');
      return;
    }

    switch (action) {
      case 'accept':
        _handleAcceptCall(callId, callerId, callerName, callType);
        break;
      case 'decline':
        _handleDeclineCall(callId, callerId);
        break;
      case 'tap':
        _handleTapCallNotification(callId, callerId, callerName, callType);
        break;
      default:
        print('⚠️ Unknown call notification action: $action');
        break;
    }
  }

  /// Handle accept call action
  void _handleAcceptCall(String callId, String? callerId, String? callerName, String? callType) {
    print('✅ Accepting call: $callId');
    
    try {
      // Send accept message via WebSocket
      _websocketService.sendMessage({
        'type': 'call:accept',
        'callId': int.tryParse(callId),
      });
      
      // Clear the call notification
      _notificationService.clearCallNotification(callId);
      
      // Update notification to show call accepted
      _notificationService.updateCallNotification(
        callId: callId,
        title: 'Call Accepted',
        body: 'Call with ${callerName ?? 'Unknown'} is now active',
        data: {
          'callId': callId,
          'callerId': callerId,
          'callerName': callerName,
          'callType': callType,
          'status': 'accepted',
        },
      );
      
      // Navigate to call screen
      _navigateToCallScreen(callId, callerId, callerName, callType);
      
    } catch (e) {
      print('❌ Error accepting call: $e');
    }
  }

  /// Handle decline call action
  void _handleDeclineCall(String callId, String? callerId) {
    print('❌ Declining call: $callId');
    
    try {
      // Send decline message via WebSocket
      _websocketService.sendMessage({
        'type': 'call:decline',
        'callId': int.tryParse(callId),
        'payload': {
          'reason': 'declined_by_user',
        },
      });
      
      // Clear the call notification
      _notificationService.clearCallNotification(callId);
      
      // Show declined notification briefly
      _notificationService.updateCallNotification(
        callId: callId,
        title: 'Call Declined',
        body: 'You declined the call',
        data: {
          'callId': callId,
          'callerId': callerId,
          'status': 'declined',
        },
      );
      
    } catch (e) {
      print('❌ Error declining call: $e');
    }
  }

  /// Handle tap on call notification (open incoming call screen)
  void _handleTapCallNotification(String callId, String? callerId, String? callerName, String? callType) {
    print('👆 Tapping call notification: $callId');
    
    try {
      // Navigate to incoming call screen
      _navigateToIncomingCallScreen(callId, callerId, callerName, callType);
      
    } catch (e) {
      print('❌ Error handling call notification tap: $e');
    }
  }

  /// Navigate to call screen
  void _navigateToCallScreen(String callId, String? callerId, String? callerName, String? callType) {
    try {
      // This would navigate to the active call screen
      // You might need to adjust this based on your navigation setup
      NavigationHelper.pushRoute(
        // Replace with your actual call screen
        const IncomingCallScreen(), // This should be your active call screen
      );
    } catch (e) {
      print('❌ Error navigating to call screen: $e');
    }
  }

  /// Navigate to incoming call screen
  void _navigateToIncomingCallScreen(String callId, String? callerId, String? callerName, String? callType) {
    try {
      // This would navigate to the incoming call screen
      NavigationHelper.pushRoute(
        const IncomingCallScreen(),
      );
    } catch (e) {
      print('❌ Error navigating to incoming call screen: $e');
    }
  }

  /// Show incoming call notification
  Future<void> showIncomingCallNotification({
    required String callId,
    required String callerId,
    required String callerName,
    required String callType,
    String? callerProfilePic,
  }) async {
    try {
      await _notificationService.showCallNotification(
        title: 'Incoming ${callType == 'video' ? 'Video' : 'Audio'} Call',
        body: '$callerName is calling you',
        data: {
          'callId': callId,
          'callerId': callerId,
          'callerName': callerName,
          'callType': callType,
          'callerProfilePic': callerProfilePic,
        },
      );
    } catch (e) {
      print('❌ Error showing incoming call notification: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _callNotificationSubscription?.cancel();
  }
}
