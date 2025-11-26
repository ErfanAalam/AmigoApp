import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amigo/api/api_service.dart';
import 'background_call_handler.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/types/socket.type.dart';
import 'package:amigo/models/message.model.dart';
// import 'package:amigo/firebase_options.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Store initial message when app is launched from terminated state
  RemoteMessage? _initialMessage;
  bool _hasProcessedInitialMessage = false;

  // Stream controllers for different notification types
  final StreamController<Map<String, dynamic>> _messageNotificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get messageNotificationStream =>
      _messageNotificationController.stream;

  // Track notifications by conversation for grouped notifications
  // Key: conversationId, Value: List of {title, body, messageId}
  final Map<String, List<Map<String, dynamic>>> _conversationNotifications = {};
  
  // Summary notification ID (fixed ID for the summary)
  static const int _summaryNotificationId = -1;

  // Message repository for storing messages from notifications
  final MessageRepository _messageRepo = MessageRepository();

  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Initialize FirebaseMessaging after Firebase is initialized
      _firebaseMessaging = FirebaseMessaging.instance;

      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      await _getFCMToken();

      // Set up message handlers
      _setupMessageHandlers();
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request notification permission
      await Permission.notification.request();
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    await _localNotifications.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel messageChannel =
        AndroidNotificationChannel(
          'messages',
          'Messages',
          description: 'Notifications for new messages',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

    const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
      'calls',
      'Calls',
      description: 'Notifications for incoming calls',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(messageChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(callChannel);
  }

  /// Get FCM token
  Future<void> _getFCMToken() async {
    try {
      if (_firebaseMessaging != null) {
        _fcmToken = await _firebaseMessaging!.getToken();

        // Store token in shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken ?? '');
      } else {
        debugPrint('❌ FirebaseMessaging not initialized');
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token');
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    if (_firebaseMessaging == null) return;

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Store initial message when app is launched from terminated state
    // Don't process it immediately - let the app initialize first
    _firebaseMessaging!.getInitialMessage().then((message) {
      if (message != null) {
        _initialMessage = message;
      }
    });
  }

  /// Check and process initial message (call this after app is fully initialized)
  Future<void> processInitialMessage() async {
    if (_initialMessage != null && !_hasProcessedInitialMessage) {
      _hasProcessedInitialMessage = true;
      _handleNotificationTap(_initialMessage!);
      _initialMessage = null; // Clear it after processing
    } else if (_hasProcessedInitialMessage) {
      debugPrint('ℹ️ Initial message already processed');
    } else {
      debugPrint('ℹ️ No initial message to process');
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;

    if (data['type'] == 'message') {
      // Store message in local DB if chat_message is present
      await _storeMessageFromNotification(data);
      
      // Show notification
      _handleMessageNotification(data, notification);
    }
  }

  /// Handle notification taps (from Firebase when app is in background)
  void _handleNotificationTap(RemoteMessage message) async {
    final data = message.data;

    if (data['type'] == 'message') {
      // Store message in local DB if chat_message is present
      await _storeMessageFromNotification(data);
      
      // Ensure conversationId is included in the data
      final notificationData = {
        'type': 'message',
        'conversationId': data['conversationId'],
        'senderId': data['senderId'],
        'senderName': data['senderName'],
        'messageId': data['messageId'],
        'messageType': data['messageType'],
      };

      _messageNotificationController.add(notificationData);
    }
  }

  /// Handle message notifications
  void _handleMessageNotification(
    Map<String, dynamic> data,
    RemoteNotification? notification,
  ) {
    // Show local notification for new message
    showMessageNotification(
      title: notification?.title ?? 'New Message',
      body: notification?.body ?? 'You have a new message',
      data: data,
    );

    // DO NOT emit to stream here - only emit when user taps the notification
    // The stream emission happens in _handleNotificationTap and _handleMessageNotificationAction
  }

  /// Store message from FCM notification data to local database
  Future<void> _storeMessageFromNotification(Map<String, dynamic> data) async {
    try {
      // Check if chat_message is present in the notification data
      final chatMessageStr = data['chat_message'];
      if (chatMessageStr == null) {
        debugPrint('ℹ️ No chat_message in notification data, skipping storage');
        return;
      }

      // Parse the chat_message JSON string
      Map<String, dynamic> chatMessageJson;
      if (chatMessageStr is String) {
        chatMessageJson = jsonDecode(chatMessageStr);
      } else if (chatMessageStr is Map) {
        chatMessageJson = Map<String, dynamic>.from(chatMessageStr);
      } else {
        debugPrint('❌ Invalid chat_message format in notification');
        return;
      }

      // Convert to ChatMessagePayload
      final chatMessagePayload = ChatMessagePayload.fromJson(chatMessageJson);

      // Convert to MessageModel and store in local DB
      final messageModel = MessageModel(
        optimisticId: chatMessagePayload.optimisticId,
        canonicalId: chatMessagePayload.canonicalId,
        conversationId: chatMessagePayload.convId,
        senderId: chatMessagePayload.senderId,
        senderName: chatMessagePayload.senderName,
        type: chatMessagePayload.msgType,
        body: chatMessagePayload.body,
        status: MessageStatusType.delivered, // Messages from notifications are delivered
        attachments: chatMessagePayload.attachments,
        metadata: chatMessagePayload.metadata,
        isStarred: false,
        isReplied: chatMessagePayload.replyToMessageId != null,
        isForwarded: false,
        isDeleted: false,
        sentAt: chatMessagePayload.sentAt.toIso8601String(),
      );

      // Store in local database
      await _messageRepo.insertMessage(messageModel);
      
      debugPrint('✅ Stored message from FCM notification: ${chatMessagePayload.canonicalId ?? chatMessagePayload.optimisticId}');
    } catch (e) {
      debugPrint('❌ Error storing message from FCM notification: $e');
    }
  }

  /// Show message notification with grouping support
  Future<void> showMessageNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final conversationId = data['conversationId']?.toString() ?? '';
    final messageId = data['messageId']?.toString() ?? '';
    
    if (conversationId.isEmpty) {
      debugPrint('❌ ConversationId is missing in notification data');
      return;
    }

    // Track this notification for the conversation
    if (!_conversationNotifications.containsKey(conversationId)) {
      _conversationNotifications[conversationId] = [];
    }

    // Add or update the latest message for this conversation
    // Keep only the latest message per conversation for the individual notification
    _conversationNotifications[conversationId] = [
      {
        'title': title,
        'body': body,
        'messageId': messageId,
        'senderName': data['senderName'] ?? 'Unknown',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    ];

    // Create individual notification for this conversation
    // Use conversationId hash as notification ID to replace previous notifications for same conversation
    final conversationNotificationId = conversationId.hashCode;

    final AndroidNotificationDetails conversationNotificationDetails =
        AndroidNotificationDetails(
          'messages',
          'Messages',
          channelDescription: 'Notifications for new messages',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          groupKey: 'messages_group', // All message notifications in same group
          setAsGroupSummary: false, // This is an individual notification
          groupAlertBehavior: GroupAlertBehavior.children, // Only summary makes sound
        );

    final NotificationDetails conversationNotificationDetailsObj = NotificationDetails(
      android: conversationNotificationDetails,
    );

    await _localNotifications.show(
      conversationNotificationId,
      title,
      body,
      conversationNotificationDetailsObj,
      payload: jsonEncode({
        'type': 'message',
        'messageId': messageId,
        'conversationId': conversationId,
        'senderId': data['senderId'],
        'senderName': data['senderName'],
        'messageType': data['messageType'],
      }),
    );

    // Update or create summary notification
    await _updateSummaryNotification();
  }

  /// Update the summary notification showing all conversations
  Future<void> _updateSummaryNotification() async {
    if (_conversationNotifications.isEmpty) {
      // No notifications, cancel summary
      await _localNotifications.cancel(_summaryNotificationId);
      return;
    }

    final totalConversations = _conversationNotifications.length;
    final List<String> conversationLines = [];

    // Build inbox style lines (max 5 conversations shown in inbox style)
    final sortedConversations = _conversationNotifications.entries.toList()
      ..sort((a, b) {
        // Sort by most recent message timestamp
        final aTime = a.value.isNotEmpty ? a.value.last['timestamp'] ?? 0 : 0;
        final bTime = b.value.isNotEmpty ? b.value.last['timestamp'] ?? 0 : 0;
        return bTime.compareTo(aTime);
      });

    for (final entry in sortedConversations.take(5)) {
      final messages = entry.value;
      if (messages.isNotEmpty) {
        final latestMessage = messages.last;
        final senderName = latestMessage['senderName'] ?? 'Unknown';
        final body = latestMessage['body'] ?? '';
        
        // Format: "Sender: Message preview"
        final preview = body.length > 30 
            ? body.substring(0, 30) + '...' 
            : body;
        conversationLines.add('$senderName: $preview');
      }
    }

    // Create summary title
    String summaryTitle;
    if (totalConversations == 1) {
      final firstConv = sortedConversations.first;
      final senderName = firstConv.value.isNotEmpty 
          ? firstConv.value.last['senderName'] ?? 'Unknown'
          : 'Unknown';
      summaryTitle = senderName;
    } else {
      summaryTitle = '$totalConversations new messages';
    }

    // Create summary body
    String summaryBody;
    if (totalConversations == 1) {
      final firstConv = sortedConversations.first;
      summaryBody = firstConv.value.isNotEmpty 
          ? firstConv.value.last['body'] ?? 'New message'
          : 'New message';
    } else {
      summaryBody = 'From $totalConversations conversations';
    }

    // Create inbox style for summary notification
    final InboxStyleInformation inboxStyle = InboxStyleInformation(
      conversationLines,
      summaryText: summaryBody,
    );

    final AndroidNotificationDetails summaryNotificationDetails =
        AndroidNotificationDetails(
          'messages',
          'Messages',
          channelDescription: 'Notifications for new messages',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          groupKey: 'messages_group',
          setAsGroupSummary: true, // This is the summary notification
          styleInformation: inboxStyle,
        );

    final NotificationDetails summaryNotificationDetailsObj = NotificationDetails(
      android: summaryNotificationDetails,
    );

    await _localNotifications.show(
      _summaryNotificationId,
      summaryTitle,
      summaryBody,
      summaryNotificationDetailsObj,
      payload: jsonEncode({
        'type': 'message_summary',
        'conversationCount': totalConversations,
      }),
    );
  }

  /// Clear notifications for a specific conversation
  Future<void> clearConversationNotifications(String conversationId) async {
    // Remove from tracking
    _conversationNotifications.remove(conversationId);
    
    // Cancel the individual notification for this conversation
    await _localNotifications.cancel(conversationId.hashCode);
    
    // Update summary notification
    await _updateSummaryNotification();
  }

  /// Handle notification tap (from local notifications)
  void _onNotificationTapped(NotificationResponse response) {
    try {
      final payload = response.payload;
      final actionId = response.actionId;

      if (payload != null) {
        // Parse the payload data
        final data = _parseNotificationPayload(payload);

        if (data != null && data['type'] == 'message') {
          _handleMessageNotificationAction(actionId, data);
        } else {
          debugPrint('❌ Failed to parse notification payload');
        }
      } else {
        debugPrint('❌ Notification payload is null');
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap');
    }
  }

  /// Parse notification payload
  Map<String, dynamic>? _parseNotificationPayload(String payload) {
    try {
      // Try to parse as JSON
      if (payload.startsWith('{') && payload.endsWith('}')) {
        final Map<String, dynamic> data = jsonDecode(payload);
        return data;
      }

      // If not JSON, try to extract basic info from string
      // This is a fallback for simple string payloads
      return {'type': 'call', 'callId': payload};
    } catch (e) {
      debugPrint('❌ Error parsing notification payload');
      return null;
    }
  }

  /// Handle message notification actions (from local notifications)
  void _handleMessageNotificationAction(
    String? actionId,
    Map<String, dynamic> data,
  ) {
    // Ensure all required fields are present
    final notificationData = {
      'type': data['type'] ?? 'message',
      'conversationId': data['conversationId'],
      'senderId': data['senderId'],
      'senderName': data['senderName'],
      'messageId': data['messageId'],
      'messageType': data['messageType'],
      'action': actionId ?? 'tap',
    };

    // Only emit to stream - navigation will be handled by the listener in main.dart
    _messageNotificationController.add(notificationData);
  }

  /// Send FCM token to backend
  Future<void> sendTokenToBackend(String userId) async {
    if (_fcmToken == null) return;

    try {
      await ApiService().updateFCMToken(_fcmToken!);
    } catch (e) {
      debugPrint('❌ Error sending FCM token to backend');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    _conversationNotifications.clear();
  }

  /// Clear specific call notification
  Future<void> clearCallNotification(String callId) async {
    await _localNotifications.cancel(callId.hashCode);
  }

  /// Update call notification (e.g., when call is answered)
  Future<void> updateCallNotification({
    required String callId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'calls',
          'Calls',
          channelDescription: 'Notifications for incoming calls',
          importance: Importance.max,
          priority: Priority.high,
          playSound: false, // No sound for updates
          enableVibration: false,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.call,
          ongoing: false,
          autoCancel: true,
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      callId.hashCode,
      title,
      body,
      notificationDetails,
      payload: jsonEncode({'type': 'call_update', 'callId': callId, ...data}),
    );
  }

  /// Clear all notification data (for logout)
  Future<void> clearNotificationData() async {
    try {
      // Cancel all notifications
      await _localNotifications.cancelAll();
      
      // Clear conversation tracking
      _conversationNotifications.clear();

      // Clear FCM token
      _fcmToken = null;

      // Clear any stored notification preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      await prefs.remove('notification_permissions_granted');
      await prefs.remove('last_notification_check');
    } catch (e) {
      debugPrint('❌ Error clearing notification data');
    }
  }

  /// Dispose resources
  void dispose() {
    _messageNotificationController.close();
  }
}
