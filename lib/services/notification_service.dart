import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amigo/api/api_service.dart';
import 'background_call_handler.dart';
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

  // Stream controllers for different notification types
  final StreamController<Map<String, dynamic>> _messageNotificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get messageNotificationStream =>
      _messageNotificationController.stream;

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

      print('🔔 NotificationService initialized successfully');
    } catch (e) {
      print('❌ Error initializing NotificationService: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      // Request notification permission
      final status = await Permission.notification.request();
      if (status != PermissionStatus.granted) {
        print('⚠️ Notification permission denied');
      }
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(
      initializationSettings,
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
        print('🔑 FCM Token: $_fcmToken');

        // Store token in shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken ?? '');
      } else {
        print('❌ FirebaseMessaging not initialized');
      }
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    if (_firebaseMessaging == null) {
      print('❌ FirebaseMessaging not initialized, cannot set up handlers');
      return;
    }

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification taps when app is terminated
    _firebaseMessaging!.getInitialMessage().then((message) {
      if (message != null) {
        print('📱 App launched from terminated state via notification');
        _handleNotificationTap(message);
      }
    });
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('📨 Received foreground message: ${message.messageId}');

    final data = message.data;
    final notification = message.notification;

    if (data['type'] == 'call') {
      // CallKit is handled by the call service, no need for additional notification here
      print('📞 Call notification received in foreground - handled by CallKit');
    } else if (data['type'] == 'message') {
      _handleMessageNotification(data, notification);
    }
  }

  /// Handle notification taps
  void _handleNotificationTap(RemoteMessage message) {
    print('👆 Notification tapped: ${message.messageId}');

    final data = message.data;

    print('-------------------------------------------------------');
    print(data);
    print('-------------------------------------------------------');
    if (data['type'] == 'message') {
      _messageNotificationController.add(data);
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

  /// Show message notification
  Future<void> showMessageNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'messages',
          'Messages',
          channelDescription: 'Notifications for new messages',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          groupKey: 'messages',
        );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      data['messageId']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      notificationDetails,
      payload: jsonEncode({
        'type': 'message',
        'messageId': data['messageId'],
        'conversationId': data['conversationId'],
        'senderId': data['senderId'],
        'senderName': data['senderName'],
        'messageType': data['messageType'],
      }),
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print(
      '👆 Local notification tapped: ${response.actionId} - ${response.payload}',
    );

    try {
      final payload = response.payload;
      final actionId = response.actionId;

      if (payload != null) {
        // Parse the payload data
        final data = _parseNotificationPayload(payload);

        if (data != null) {
          if (data['type'] == 'message') {
            _handleMessageNotificationAction(actionId, data);
          }
        }
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
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
      print('❌ Error parsing notification payload: $e');
      return null;
    }
  }

  /// Handle message notification actions
  void _handleMessageNotificationAction(
    String? actionId,
    Map<String, dynamic> data,
  ) {
    print('📨 Message notification action: $actionId');

    // Only emit to stream - navigation will be handled by the listener in main.dart
    _messageNotificationController.add({...data, 'action': actionId ?? 'tap'});
  }

  /// Send FCM token to backend
  Future<void> sendTokenToBackend(String userId) async {
    if (_fcmToken == null) {
      print('⚠️ FCM token not available');
      return;
    }

    try {
      print('📤 Sending FCM token to backend for user: $userId');
      await ApiService().updateFCMToken(_fcmToken!);
    } catch (e) {
      print('❌ Error sending FCM token to backend: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
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

      // Clear FCM token
      _fcmToken = null;

      // Clear any stored notification preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      await prefs.remove('notification_permissions_granted');
      await prefs.remove('last_notification_check');

      print('✅ Notification data cleared');
    } catch (e) {
      print('❌ Error clearing notification data: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _messageNotificationController.close();
  }
}
