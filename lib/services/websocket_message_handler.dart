import 'dart:async';
import 'package:flutter/foundation.dart';
import 'chat/storage.service.dart';
import 'websocket_service.dart';
import 'user_status_service.dart';

/// Centralized WebSocket message handler that processes all messages once
/// and distributes them via filtered streams for widgets to consume
class WebSocketMessageHandler {
  static final WebSocketMessageHandler _instance =
      WebSocketMessageHandler._internal();
  factory WebSocketMessageHandler() => _instance;
  WebSocketMessageHandler._internal();

  final WebSocketService _websocketService = WebSocketService();
  final UserStatusService _userStatusService = UserStatusService();
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  // Stream controllers for different message types
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _mediaController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _deliveryReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _readReceiptController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _messagePinController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _messageStarController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _messageReplyController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _onlineStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _isInitialized = false;

  /// Get stream for messages (type: 'message')
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Get stream for typing indicators (type: 'typing')
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;

  /// Get stream for media messages (type: 'media')
  Stream<Map<String, dynamic>> get mediaStream => _mediaController.stream;

  /// Get stream for delivery receipts (type: 'message_delivery_receipt')
  Stream<Map<String, dynamic>> get deliveryReceiptStream =>
      _deliveryReceiptController.stream;

  /// Get stream for read receipts (type: 'read_receipt')
  Stream<Map<String, dynamic>> get readReceiptStream =>
      _readReceiptController.stream;

  /// Get stream for message pins (type: 'message_pin')
  Stream<Map<String, dynamic>> get messagePinStream =>
      _messagePinController.stream;

  /// Get stream for message stars (type: 'message_star')
  Stream<Map<String, dynamic>> get messageStarStream =>
      _messageStarController.stream;

  /// Get stream for message replies (type: 'message_reply')
  Stream<Map<String, dynamic>> get messageReplyStream =>
      _messageReplyController.stream;

  /// Get stream for online status (type: 'online_status')
  Stream<Map<String, dynamic>> get onlineStatusStream =>
      _onlineStatusController.stream;

  /// Initialize the handler - call this once when app starts
  void initialize() {
    if (_isInitialized) {
      debugPrint('⚠️ WebSocketMessageHandler already initialized');
      return;
    }

    _messageSubscription = _websocketService.messageStream.listen(
      _handleMessage,
      onError: (error) {
        debugPrint('❌ WebSocketMessageHandler stream error: $error');
      },
    );

    _isInitialized = true;
    debugPrint('✅ WebSocketMessageHandler initialized');
  }

  /// Handle incoming WebSocket messages and route them to appropriate streams
  void _handleMessage(Map<String, dynamic> message) async {
    try {
      final messageType = message['type'] as String?;

      if (messageType == null) {
        debugPrint('⚠️ WebSocket message missing type: $message');
        return;
      }

      // Route messages to appropriate streams
      switch (messageType) {
        case 'message':
          await ChatStorageService().storeMessageSqlite(
            message['conversation_id'],
            message,
          );
          _messageController.add(message);
          break;

        case 'media':
          await ChatStorageService().storeMediaMessageSqlite(
            message['conversation_id'],
            message,
          );
          _mediaController.add(message);
          break;

        case 'typing':
          _typingController.add(message);
          break;

        case 'message_delivery_receipt':
          _deliveryReceiptController.add(message);
          break;

        case 'read_receipt':
          _readReceiptController.add(message);
          break;

        case 'message_pin':
          _messagePinController.add(message);
          break;

        case 'message_star':
          _messageStarController.add(message);
          break;

        case 'message_reply':
          await ChatStorageService().storeMessageSqlite(
            message['conversation_id'],
            message,
          );
          _messageReplyController.add(message);
          break;

        case 'online_status':
          _onlineStatusController.add(message);
          break;

        case 'user_online':
          _userStatusService.handleUserOnlineMessage(message);
          break;

        case 'user_offline':
          _userStatusService.handleUserOfflineMessage(message);
          break;

        default:
          // Unknown message type - ignore or log
          debugPrint('⚠️ Unknown WebSocket message type: $messageType');
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling WebSocket message: $e');
    }
  }

  /// Get a filtered stream for messages in a specific conversation
  Stream<Map<String, dynamic>> messagesForConversation(int conversationId) {
    return messageStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Get a filtered stream for typing indicators in a specific conversation
  Stream<Map<String, dynamic>> typingForConversation(int conversationId) {
    return typingStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Get a filtered stream for media messages in a specific conversation
  Stream<Map<String, dynamic>> mediaForConversation(int conversationId) {
    return mediaStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Get a filtered stream for delivery receipts in a specific conversation
  Stream<Map<String, dynamic>> deliveryReceiptsForConversation(
    int conversationId,
  ) {
    return deliveryReceiptStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Get a filtered stream for read receipts in a specific conversation
  Stream<Map<String, dynamic>> readReceiptsForConversation(int conversationId) {
    return readReceiptStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Get a filtered stream for message pins in a specific conversation
  Stream<Map<String, dynamic>> messagePinsForConversation(int conversationId) {
    return messagePinStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Get a filtered stream for message stars in a specific conversation
  Stream<Map<String, dynamic>> messageStarsForConversation(int conversationId) {
    return messageStarStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Get a filtered stream for message replies in a specific conversation
  Stream<Map<String, dynamic>> messageRepliesForConversation(
    int conversationId,
  ) {
    return messageReplyStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Get a filtered stream for online status in a specific conversation
  Stream<Map<String, dynamic>> onlineStatusForConversation(int conversationId) {
    return onlineStatusStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Dispose resources
  void dispose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _messageController.close();
    _typingController.close();
    _mediaController.close();
    _deliveryReceiptController.close();
    _readReceiptController.close();
    _messagePinController.close();
    _messageStarController.close();
    _messageReplyController.close();
    _onlineStatusController.close();
    _isInitialized = false;
  }
}
