import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:amigo/services/fcm/fcm-background.service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:amigo/db/repositories/message.repo.dart';
import 'package:amigo/db/repositories/conversations.repo.dart';
import 'package:amigo/db/repositories/message-status.repo.dart';
import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/message.model.dart';

import '../../api/api_service.dart';
import '../../types/socket.types.dart';
import '../../utils/user.utils.dart';
import '../user-info-cache.service.dart';

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

  // Store initial message when app is launched from terminated state,
  // it shows which message launched the app
  RemoteMessage? _initialMessage;
  bool _hasProcessedInitialMessage = false;

  // Stream controllers for different notification types
  final StreamController<ChatMessagePayload> _messageNotificationController =
      StreamController<ChatMessagePayload>.broadcast();

  // Pending navigation payload - buffered for when stream has no listeners yet
  ChatMessagePayload? _pendingNavigationPayload;

  /// Consume (and clear) any pending navigation payload
  /// Call this after setting up the stream listener to handle buffered events
  ChatMessagePayload? consumePendingNavigationPayload() {
    final payload = _pendingNavigationPayload;
    _pendingNavigationPayload = null;
    return payload;
  }

  // Getters for streams
  Stream<ChatMessagePayload> get messageNotificationStream =>
      _messageNotificationController.stream;

  // Track notifications by conversation for grouped notifications
  // Key: conversationId, Value: List of {title, body, messageId}
  final Map<String, List<ChatMessagePayload>> _conversationNotifications = {};

  // Summary notification ID (fixed ID for the summary)
  static const int _summaryNotificationId = -1;

  // Message repository for storing messages from notifications
  final MessageRepository _messageRepo = MessageRepository();
  final ConversationRepository _conversationRepo = ConversationRepository();
  final MessageStatusRepository _messageStatusRepo = MessageStatusRepository();

  /// Lazy getter for ApiService - only accessed after initialization
  ApiService get apiService => ApiService();

  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp();

      // Initialize FirebaseMessaging after Firebase is initialized
      _firebaseMessaging = FirebaseMessaging.instance;

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      await _getFCMToken();
      debugPrint('[FCM] Token: ${_fcmToken?.substring(0, 20)}...');

      // Upload token to backend (fire-and-forget; only succeeds if user is logged in)
      if (_fcmToken != null) {
        apiService.auth.updateFCMToken(_fcmToken!).then((_) {
          debugPrint('[FCM] ✅ Token uploaded to backend');
        }).catchError((e) {
          debugPrint('[FCM] ❌ Token upload failed (user may not be logged in yet): $e');
        });
      }

      // Listen for token refresh and upload the new one
      _firebaseMessaging!.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed');
        _fcmToken = newToken;
        apiService.auth.updateFCMToken(newToken).then((_) {
          debugPrint('[FCM] ✅ Refreshed token uploaded');
        }).catchError((e) {
          debugPrint('[FCM] ❌ Refreshed token upload failed: $e');
        });
      });

      // Set up message handlers
      _setupMessageHandlers();
    } catch (e) {
      debugPrint('❌ Error initializing NotificationService: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    await _localNotifications.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }
  }

  /// Handle local notification taps (from flutter_local_notifications)
  /// Works for foreground and background taps. Terminated-state launch
  /// is handled separately via getNotificationAppLaunchDetails in
  /// processInitialMessage().
  void _onLocalNotificationTapped(NotificationResponse response) {
    _processNotificationPayload(response.payload);
  }

  /// Shared logic for processing a notification payload string (from tap)
  void _processNotificationPayload(String? payloadStr) {
    if (payloadStr == null || payloadStr.isEmpty) return;

    try {
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;

      // Handle summary notification tap — no specific chat to navigate to
      if (payload['type'] == 'message_summary') {
        debugPrint('📨 Summary notification tapped');
        return;
      }

      final chatPayload = ChatMessagePayload.fromJson(payload);

      // Clear this conversation's notifications
      clearConversationNotifications(chatPayload.convId.toString());

      // Store as pending in case stream has no listener yet (terminated state)
      _pendingNavigationPayload = chatPayload;

      // Emit to stream — if a listener is attached it will navigate immediately
      if (_messageNotificationController.hasListener) {
        _messageNotificationController.add(chatPayload);
        _pendingNavigationPayload = null; // consumed by listener
      }

      debugPrint(
        '📨 Notification tapped: conversation ${chatPayload.convId} '
        '(pending=${_pendingNavigationPayload != null})',
      );
    } catch (e) {
      debugPrint('❌ Error parsing notification payload: $e');
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel messageChannel =
        AndroidNotificationChannel(
          'messages',
          'Message notifications',
          description: 'Notifications for new messages',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );

    const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
      'calls',
      'Call notifications',
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
      for (int attempt = 0; attempt < 2; attempt++) {
        if (_firebaseMessaging != null) {
          _fcmToken = await _firebaseMessaging!.getToken();
          return;
        }
        await Future.delayed(const Duration(milliseconds: 300));
      }
      debugPrint('❌ FirebaseMessaging not initialized');
    } catch (e) {
      debugPrint('❌ Error getting FCM token');
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    if (_firebaseMessaging == null) return;

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(fcmBackgroundHandler);

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
  /// Handles both Firebase initial messages AND local notification launches.
  Future<void> processInitialMessage() async {
    if (_hasProcessedInitialMessage) {
      debugPrint('ℹ️ Initial message already processed');
      return;
    }

    // 1. Check Firebase initial message (FCM-managed notification tap from terminated)
    if (_initialMessage != null) {
      _hasProcessedInitialMessage = true;
      _handleNotificationTap(_initialMessage!);
      _initialMessage = null;
      debugPrint('📨 Processed Firebase initial message');
      return;
    }

    // 2. Check flutter_local_notifications launch details (local notification tap from terminated)
    try {
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse != null) {
        _hasProcessedInitialMessage = true;
        final response = launchDetails.notificationResponse!;
        debugPrint(
          '📨 App launched from local notification tap, processing payload...',
        );
        _processNotificationPayload(response.payload);

        // If payload was stored as pending, emit it now (listener should be ready)
        final pending = _pendingNavigationPayload;
        if (pending != null) {
          _pendingNavigationPayload = null;
          _messageNotificationController.add(pending);
          debugPrint('📨 Emitted pending navigation payload from launch');
        }
        return;
      }
    } catch (e) {
      debugPrint('❌ Error checking local notification launch details: $e');
    }

    // 3. Check for any pending payload (e.g., from onDidReceiveNotificationResponse
    //    that fired before stream listener was attached)
    final pending = _pendingNavigationPayload;
    if (pending != null) {
      _hasProcessedInitialMessage = true;
      _pendingNavigationPayload = null;
      _messageNotificationController.add(pending);
      debugPrint('📨 Emitted buffered pending navigation payload');
      return;
    }

    debugPrint('ℹ️ No initial notification to process');
  }

  /// Parse ws_message from notification data (single — used for calls)
  WSMessage? _parseWSMessage(Map<String, dynamic> data) {
    try {
      final wsMessageStr = data['ws_message'];
      if (wsMessageStr == null) return null;

      Map<String, dynamic> wsMessageJson;
      if (wsMessageStr is String) {
        wsMessageJson = jsonDecode(wsMessageStr);
      } else if (wsMessageStr is Map) {
        wsMessageJson = Map<String, dynamic>.from(wsMessageStr);
      } else {
        debugPrint('❌ Invalid ws_message format in notification');
        return null;
      }

      return WSMessage.fromJson(wsMessageJson);
    } catch (e) {
      debugPrint('❌ Error parsing ws_message: $e');
      return null;
    }
  }

  /// Parse ws_messages array from notification data (batched chat messages)
  List<WSMessage> _parseWSMessages(Map<String, dynamic> data) {
    try {
      final wsMessagesStr = data['ws_messages'];
      if (wsMessagesStr == null) {
        // Fall back to single ws_message
        final single = _parseWSMessage(data);
        return single != null ? [single] : [];
      }
      final List<dynamic> arr = jsonDecode(wsMessagesStr as String);
      return arr
          .map((item) => WSMessage.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error parsing ws_messages: $e');
      return [];
    }
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final notification = message.notification;
    final notificationType = data['type'] as String?;

    switch (notificationType) {
      case 'ws-message':
        // Parse the batch of ws_messages
        final wsMessages = _parseWSMessages(data);
        for (final wsMessage in wsMessages) {
          if (wsMessage.type == WSMessageType.messageNew) {
            final chatPayload = wsMessage.chatMessagePayload;
            if (chatPayload != null) {
              _handleMessageNotification(notification, chatPayload);
              await _storeMessageFromPayload(chatPayload);
            }
          } else if (wsMessage.type == WSMessageType.messageDelete) {
            final deletePayload = wsMessage.deleteMessagePayload;
            if (deletePayload != null) {
              await _handleMessageDelete(deletePayload);
            }
          }
        }
        break;
      case 'call':
        // Call notifications are handled by call-background.service.dart
        break;
      default:
        debugPrint('📨 Unhandled notification type: $notificationType');
    }
  }

  /// Handle notification taps (from Firebase when app is in background)
  void _handleNotificationTap(RemoteMessage message) async {
    final data = message.data;
    final notificationType = data['type'] as String?;

    // Parse ws_message if present
    final wsMessage = _parseWSMessage(data);

    switch (notificationType) {
      case 'ws-message':
        if (wsMessage != null) {
          if (wsMessage.type == WSMessageType.messageNew) {
            final chatPayload = wsMessage.chatMessagePayload;
            if (chatPayload != null) {
              // Clear this conversation's notifications
              clearConversationNotifications(chatPayload.convId.toString());
              
              // Emit to stream so main.dart can handle navigation
              _messageNotificationController.add(chatPayload);
              
              debugPrint(
                '📨 Firebase notification tapped: conversation ${chatPayload.convId}',
              );
            }
          } else if (wsMessage.type == WSMessageType.messageDelete) {
            final deletePayload = wsMessage.deleteMessagePayload;
            if (deletePayload != null) {
              await _handleMessageDelete(deletePayload);
            }
          }
        }
        break;
      case 'call':
        // Call notifications are handled by call-background.service.dart
        break;
      default:
        debugPrint('📨 Unhandled notification tap type: $notificationType');
    }
  }

  /// Handle message notifications
  void _handleMessageNotification(
    RemoteNotification? notification,
    ChatMessagePayload chatPayload,
  ) async {
    // Look up sender name from local DB since ChatMessagePayload
    // no longer carries senderName.
    final sender = await UserInfoCache.instance.getUser(chatPayload.senderId);
    final senderName = sender?.name ?? chatPayload.senderId;

    // Show local notification for new message
    showMessageNotification(
      title: notification?.title ?? senderName,
      body: notification?.body ?? chatPayload.body ?? 'You have a new message',
      chatPayload: chatPayload,
    );

    // DO NOT emit to stream here - only emit when user taps the notification
    // The stream emission happens in _handleNotificationTap
  }

  /// Store message from ChatMessagePayload to local database
  Future<void> _storeMessageFromPayload(ChatMessagePayload chatPayload) async {
    try {
      // Look up sender name from local DB
      final sender = await UserInfoCache.instance.getUser(chatPayload.senderId);

      // Convert to MessageModel and store in local DB
      final messageModel = MessageModel(
        id: chatPayload.id,
        chatId: chatPayload.convId,
        senderId: chatPayload.senderId,
        senderName: sender?.name ?? '',
        type: chatPayload.msgType,
        body: chatPayload.body,
        attachments: chatPayload.attachments is Map<String, dynamic>
            ? chatPayload.attachments as Map<String, dynamic>
            : null,
        repliedTo: chatPayload.repliedTo,
        sentAt: chatPayload.sentAt.toIso8601String(),
      );

      // Store in local database
      await _messageRepo.insertMessage(messageModel);
      debugPrint('✅ Stored message from FCM notification: ${chatPayload.id}');

      // update the conversation unread count
      final conversation = await _conversationRepo.getConversationById(
        chatPayload.convId,
      );
      await _conversationRepo.updateUnreadCount(
        chatPayload.convId,
        (conversation?.unreadCount ?? 0) + 1,
      );

      // Send delivery receipt to backend
      await sendDeliveryReceipt(chatPayload);
    } catch (e) {
      debugPrint('❌ Error storing message from FCM notification: $e');
    }
  }

  /// Handle message delete notification
  Future<void> _handleMessageDelete(DeleteMessagePayload payload) async {
    try {
      final conversationId = payload.convId;
      final deletedMessageIds = payload.messageIds;

      if (deletedMessageIds.isEmpty) {
        debugPrint('ℹ️ No message IDs to delete');
        return;
      }

      // Get current user ID to check which messages were unread
      final currentUser = await UserUtils().getUserDetails();
      if (currentUser == null) {
        debugPrint('⚠️ Cannot handle message delete: no current user');
        return;
      }
      final currentUserId = currentUser.id;

      // Get messages before deletion to check if they were unread
      final messagesToDelete = await _messageRepo.getMessagesByIds(
        deletedMessageIds,
      );

      if (messagesToDelete.isEmpty) {
        debugPrint(
          'ℹ️ Messages not found in local database, may have been already deleted',
        );
        return;
      }

      // Count unread messages (messages not sent by current user and not read by current user)
      int unreadCountToDecrement = 0;
      for (final message in messagesToDelete) {
        // Only count messages sent by others (not by current user)
        if (message.senderId != currentUserId) {
          // Check if message was unread
          final isRead = await _messageStatusRepo.isReadByUser(
            message.id,
            currentUserId,
          );
          if (!isRead) {
            unreadCountToDecrement++;
          }
        }
      }

      // Delete messages from local DB
      await _messageRepo.permanentlyDeleteMessages(deletedMessageIds);

      // Get conversation to update unread count
      final conversation = await _conversationRepo.getConversationById(
        conversationId,
      );

      if (conversation != null) {
        // Get the new last message after deletion
        final lastMessage = await _messageRepo.getLastMessage(conversationId);

        // Decrement unread count if unread messages were deleted
        final currentUnreadCount = conversation.unreadCount ?? 0;
        final newUnreadCount = currentUnreadCount > unreadCountToDecrement
            ? currentUnreadCount - unreadCountToDecrement
            : 0;

        // Update last message and unread count in database
        if (lastMessage != null) {
          await _conversationRepo.updateLastMessage(
            conversationId,
            lastMessage.id,
          );
        }

        await _conversationRepo.updateUnreadCount(
          conversationId,
          newUnreadCount,
        );

        debugPrint(
          '✅ [NOTIFICATION] Deleted ${deletedMessageIds.length} messages from conversation $conversationId, decremented unread count by $unreadCountToDecrement (new count: $newUnreadCount)',
        );
      } else {
        debugPrint(
          '⚠️ [NOTIFICATION] Conversation $conversationId not found in database',
        );
      }
    } catch (e) {
      debugPrint('❌ [NOTIFICATION] Error handling message delete: $e');
    }
  }

  /// Send delivery receipt to backend via API
  /// This notifies the sender that the message was delivered via FCM
  /// Uses API instead of WebSocket since app might be killed/not connected
  Future<void> sendDeliveryReceipt(ChatMessagePayload message) async {
    try {
      // Get current user ID
      final currentUser = await UserUtils().getUserDetails();
      if (currentUser == null) {
        debugPrint('⚠️ Cannot send delivery receipt: no current user');
        return;
      }

      // Only send receipt if we have a canonical (server) message ID
      // final messageId = message.id;
      // if (messageId == null) {
      //   debugPrint('⚠️ Cannot send delivery receipt: no canonical message ID');
      //   return;
      // }

      // Send delivery receipt via API
      // The backend will handle WebSocket broadcast to the sender
      await apiService.chat.markMessageDelivered(
        messageId: message.id,
        conversationId: message.convId,
      );

      debugPrint(
        '📬 Sent delivery receipt for message ${message.id} to sender ${message.senderId}',
      );
    } catch (e) {
      debugPrint('⚠️ Error sending delivery receipt: $e');
      // Don't throw - delivery receipt is best-effort
      // The sync mechanism will handle it if API fails
    }
  }

  /// Show message notification with WhatsApp-like MessagingStyle
  Future<void> showMessageNotification({
    required String title,
    required String body,
    ChatMessagePayload? chatPayload,
  }) async {
    if (chatPayload == null) {
      // Simple notification fallback (e.g. missed call)
      await _showSimpleNotification(title: title, body: body);
      return;
    }

    final convId = chatPayload.convId;

    // Look up conversation type from local DB since ChatMessagePayload
    // no longer carries convType.
    final convRecord = await _conversationRepo.getConversationById(convId);
    final convType = convRecord?.type != null
        ? ChatType.fromString(convRecord!.type)
        : null;
    final isGroup = convType == ChatType.group ||
        convType == ChatType.communityGroup;

    // 1. Accumulate messages (persisted via SharedPreferences for cross-isolate support)
    final messages = await _accumulateMessage(convId, chatPayload);

    // Look up sender name from local DB
    final senderUser = await UserInfoCache.instance.getUser(chatPayload.senderId);
    final senderName = senderUser?.name;

    // 2. Resolve conversation title
    String conversationTitle;
    if (isGroup) {
      try {
        conversationTitle =
            convRecord?.title ?? senderName ?? 'Group Chat';
      } catch (_) {
        conversationTitle = senderName ?? 'Group Chat';
      }
    } else {
      // For DMs, try to get display name from users table
      try {
        final sender =
            await UserRepository().getUserById(chatPayload.senderId);
        conversationTitle =
            sender?.displayName ?? senderName ?? 'Unknown';
      } catch (_) {
        conversationTitle = senderName ?? 'Unknown';
      }
    }

    // 3. Download sender profile pictures for Person icons
    //    Cache downloaded avatars by senderId to avoid duplicate downloads
    final avatarCache = <String, Uint8List?>{};
    final userRepo = UserRepository();

    Future<Uint8List?> getAvatar(String senderId) async {
      if (avatarCache.containsKey(senderId)) return avatarCache[senderId];
      Uint8List? bytes;
      try {
        final sender = await userRepo.getUserById(senderId);
        if (sender?.profilePic != null && sender!.profilePic!.isNotEmpty) {
          bytes = await _downloadImage(sender.profilePic!);
        }
      } catch (_) {}
      avatarCache[senderId] = bytes;
      return bytes;
    }

    // 4. Build Person + Message list for MessagingStyle
    // Cache sender names by userId to avoid repeated lookups
    final nameCache = <String, String>{};
    Future<String> getSenderName(String senderId) async {
      if (nameCache.containsKey(senderId)) return nameCache[senderId]!;
      final u = await UserInfoCache.instance.getUser(senderId);
      final name = u?.name ?? 'Unknown';
      nameCache[senderId] = name;
      return name;
    }

    final messagingMessages = <Message>[];
    for (final msg in messages) {
      final senderAvatar = await getAvatar(msg.senderId);
      final msgSenderName = await getSenderName(msg.senderId);
      final person = Person(
        name: msgSenderName,
        key: msg.senderId.toString(),
        icon: senderAvatar != null
            ? ByteArrayAndroidIcon(senderAvatar)
            : null,
      );

      final messageBody = msg.body != null && msg.body!.isNotEmpty
          ? msg.body!
          : _formatMessageType(msg.msgType);

      messagingMessages.add(Message(messageBody, msg.sentAt, person));
    }

    // 5. Latest sender avatar as the notification large icon
    final latestAvatar = await getAvatar(chatPayload.senderId);

    // 6. Build MessagingStyle notification
    final messagingStyle = MessagingStyleInformation(
      Person(name: 'Me'),
      conversationTitle: conversationTitle,
      groupConversation: isGroup,
      messages: messagingMessages,
    );

    final conversationNotificationId = convId.hashCode;

    final androidDetails = AndroidNotificationDetails(
      'messages',
      'Message notifications',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      groupKey: 'amigo_messages',
      setAsGroupSummary: false,
      groupAlertBehavior: GroupAlertBehavior.children,
      styleInformation: messagingStyle,
      largeIcon: latestAvatar != null
          ? ByteArrayAndroidBitmap(latestAvatar)
          : null,
      category: AndroidNotificationCategory.message,
    );

    await _localNotifications.show(
      conversationNotificationId,
      conversationTitle,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(chatPayload),
    );

    // 7. Update or create summary notification (for multi-chat grouping)
    await _updateSummaryNotification();
  }

  /// Accumulate messages per conversation using SharedPreferences
  /// Returns the list of accumulated messages (max 5) for the conversation
  Future<List<ChatMessagePayload>> _accumulateMessage(
    String convId,
    ChatMessagePayload newMessage,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'notif_messages_$convId';

    List<ChatMessagePayload> messages = [];

    // Load existing messages from SharedPreferences
    final existing = prefs.getString(key);
    if (existing != null) {
      try {
        final List<dynamic> decoded = jsonDecode(existing);
        messages =
            decoded.map((e) => ChatMessagePayload.fromJson(e)).toList();
      } catch (_) {}
    }

    // Append new message
    messages.add(newMessage);

    // Keep last 5 messages only
    if (messages.length > 5) {
      messages = messages.sublist(messages.length - 5);
    }

    // Persist back
    await prefs.setString(
      key,
      jsonEncode(messages.map((m) => m.toJson()).toList()),
    );

    // Track this convId in the active notification set
    final activeConvs =
        prefs.getStringList('active_notification_convs') ?? [];
    if (!activeConvs.contains(convId.toString())) {
      activeConvs.add(convId.toString());
      await prefs.setStringList('active_notification_convs', activeConvs);
    }

    // Keep in-memory map in sync
    _conversationNotifications[convId] = messages;

    return messages;
  }

  /// Download an image from URL and return bytes (with timeout)
  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  /// Format a non-text message type into a human-readable string
  String _formatMessageType(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎵 Voice message';
      case MessageType.attachment:
        return '📎 File';
      case MessageType.document:
        return '📄 Document';
      default:
        return 'New message';
    }
  }

  /// Show a simple notification without chat context (fallback)
  Future<void> _showSimpleNotification({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Message notifications',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Update the summary notification showing all conversations (InboxStyle)
  /// Only shown when there are 2+ active conversations with notifications
  Future<void> _updateSummaryNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final activeConvs =
        prefs.getStringList('active_notification_convs') ?? [];

    // Only show summary when there are 2+ conversations
    if (activeConvs.length < 2) {
      await _localNotifications.cancel(_summaryNotificationId);
      return;
    }

    final totalConversations = activeConvs.length;
    final List<String> inboxLines = [];
    int totalMessages = 0;

    for (final convIdStr in activeConvs) {
      final key = 'notif_messages_$convIdStr';
      final existing = prefs.getString(key);
      if (existing == null) continue;

      try {
        final List<dynamic> decoded = jsonDecode(existing);
        final messages =
            decoded.map((e) => ChatMessagePayload.fromJson(e)).toList();
        totalMessages += messages.length;

        if (messages.isNotEmpty) {
          final latest = messages.last;
          final convId = convIdStr;

          // Look up conversation type from local DB
          final convRec = await _conversationRepo.getConversationById(convId);
          final cType = convRec?.type != null
              ? ChatType.fromString(convRec!.type)
              : null;
          final isGroup = cType == ChatType.group ||
              cType == ChatType.communityGroup;

          // Look up sender name from local DB
          final latestSender = await UserInfoCache.instance.getUser(latest.senderId);
          final latestSenderName = latestSender?.name;

          // Resolve conversation title
          String convTitle;
          if (isGroup && convId.isNotEmpty) {
            try {
              convTitle = convRec?.title ?? latestSenderName ?? 'Group';
            } catch (_) {
              convTitle = latestSenderName ?? 'Group';
            }
          } else {
            convTitle = latestSenderName ?? 'Unknown';
          }

          final msgBody =
              latest.body ?? _formatMessageType(latest.msgType);
          final preview =
              msgBody.length > 40 ? '${msgBody.substring(0, 40)}...' : msgBody;

          if (isGroup) {
            inboxLines
                .add('<b>$convTitle</b>  ${latestSenderName ?? 'Unknown'}: $preview');
          } else {
            inboxLines.add('<b>$convTitle</b>  $preview');
          }
        }
      } catch (_) {}
    }

    final summaryTitle =
        '$totalMessages messages from $totalConversations chats';

    final inboxStyle = InboxStyleInformation(
      inboxLines,
      htmlFormatLines: true,
      contentTitle: summaryTitle,
      htmlFormatContentTitle: true,
      summaryText: '$totalConversations chats',
      htmlFormatSummaryText: true,
    );

    final androidDetails = AndroidNotificationDetails(
      'messages',
      'Message notifications',
      channelDescription: 'Notifications for new messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      groupKey: 'amigo_messages',
      setAsGroupSummary: true,
      styleInformation: inboxStyle,
    );

    await _localNotifications.show(
      _summaryNotificationId,
      summaryTitle,
      '$totalConversations chats',
      NotificationDetails(android: androidDetails),
      payload: jsonEncode({'type': 'message_summary'}),
    );
  }

  /// Clear notifications for a specific conversation
  Future<void> clearConversationNotifications(String conversationId) async {
    // Remove from in-memory tracking
    _conversationNotifications.remove(conversationId);

    // Remove from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notif_messages_$conversationId');
    final activeConvs =
        prefs.getStringList('active_notification_convs') ?? [];
    activeConvs.remove(conversationId);
    await prefs.setStringList('active_notification_convs', activeConvs);

    // Cancel the individual notification for this conversation
    await _localNotifications.cancel(conversationId.hashCode);

    // Update summary notification
    await _updateSummaryNotification();
  }

  /// Send FCM token to backend
  Future<void> sendTokenToBackend(String userId) async {
    if (_fcmToken == null) return;

    try {
      await apiService.auth.updateFCMToken(_fcmToken!);
    } catch (e) {
      debugPrint('❌ Error sending FCM token to backend');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    _conversationNotifications.clear();
    await _clearPersistedNotifications();
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

    print("notification show: started for call");
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
      await _clearPersistedNotifications();

      // Clear FCM token
      _fcmToken = null;
    } catch (e) {
      debugPrint('❌ Error clearing notification data');
    }
  }

  /// Clear all persisted notification data from SharedPreferences
  Future<void> _clearPersistedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeConvs =
          prefs.getStringList('active_notification_convs') ?? [];
      for (final convId in activeConvs) {
        await prefs.remove('notif_messages_$convId');
      }
      await prefs.remove('active_notification_convs');
    } catch (_) {}
  }

  /// Dispose resources
  void dispose() {
    _messageNotificationController.close();
  }
}
