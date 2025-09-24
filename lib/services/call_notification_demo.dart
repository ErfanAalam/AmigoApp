import 'package:amigo/services/notification_service.dart';
import 'package:amigo/services/call_notification_handler.dart';

class CallNotificationDemo {
  static final CallNotificationDemo _instance = CallNotificationDemo._internal();
  factory CallNotificationDemo() => _instance;
  CallNotificationDemo._internal();

  final NotificationService _notificationService = NotificationService();
  final CallNotificationHandler _callNotificationHandler = CallNotificationHandler();

  /// Test call notification with accept/decline actions
  Future<void> testCallNotification() async {
    print('🧪 Testing call notification...');
    
    try {
      // Show a test call notification
      await _callNotificationHandler.showIncomingCallNotification(
        callId: 'test_call_${DateTime.now().millisecondsSinceEpoch}',
        callerId: '12345',
        callerName: 'John Doe',
        callType: 'audio',
        callerProfilePic: 'https://example.com/profile.jpg',
      );
      
      print('✅ Test call notification sent!');
      print('📱 Check your device for the notification with Accept/Decline buttons');
      
    } catch (e) {
      print('❌ Error testing call notification: $e');
    }
  }

  /// Test message notification
  Future<void> testMessageNotification() async {
    print('🧪 Testing message notification...');
    
    try {
      await _notificationService.showMessageNotification(
        title: 'New Message from Jane',
        body: 'Hey! How are you doing?',
        data: {
          'messageId': 'msg_${DateTime.now().millisecondsSinceEpoch}',
          'conversationId': 'conv_123',
          'senderId': '67890',
          'senderName': 'Jane Smith',
          'messageType': 'text',
        },
      );
      
      print('✅ Test message notification sent!');
      
    } catch (e) {
      print('❌ Error testing message notification: $e');
    }
  }
}
