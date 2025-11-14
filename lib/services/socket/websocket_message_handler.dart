import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../chat/storage.service.dart';
import 'websocket_service.dart';
import '../user_status_service.dart';
import '../../utils/navigation_helper.dart';

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

  final StreamController<Map<String, dynamic>> _conversationAddedController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<Map<String, dynamic>> _messageDeleteController =
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

  /// Get stream for conversation added events (type: 'conversation_added')
  Stream<Map<String, dynamic>> get conversationAddedStream =>
      _conversationAddedController.stream;

  /// Get stream for message delete events (type: 'message_delete')
  Stream<Map<String, dynamic>> get messageDeleteStream =>
      _messageDeleteController.stream;

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
        case 'conversation:new':
          _conversationAddedController.add(message);

          break;

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
          // await ChatStorageService().storeMessageSqlite(
          //   message['conversation_id'],
          //   message,
          // );
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

        case 'message_delete':
          _messageDeleteController.add(message);
          break;

        case 'socket_health_check':
          _showHealthCheckDialog(message);
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

  /// Get a filtered stream for conversation added events in a specific conversation
  Stream<Map<String, dynamic>> conversationAddedForConversation(
    int conversationId,
  ) {
    return conversationAddedStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Get a filtered stream for message delete events in a specific conversation
  Stream<Map<String, dynamic>> messageDeletesForConversation(
    int conversationId,
  ) {
    return messageDeleteStream.where((message) {
      final msgConversationId =
          message['conversation_id'] ?? message['data']?['conversation_id'];
      return msgConversationId == conversationId;
    });
  }

  /// Show health check dialog
  void _showHealthCheckDialog(Map<String, dynamic> message) {
    final data = message['data'] as Map<String, dynamic>?;
    final time = data?['time'] as String? ?? 'Unknown time';
    final messageText = data?['message'] as String? ?? 'No message';

    // Get the navigator context
    final context = NavigationHelper.navigatorKey.currentContext;
    if (context == null) {
      debugPrint(
        '⚠️ Cannot show health check dialog: Navigator context is null',
      );
      return;
    }

    // Show the dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.health_and_safety, color: Colors.green[600], size: 28),
              const SizedBox(width: 12),
              const Text('Socket Health Check'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (messageText.isNotEmpty) ...[
                Text(
                  messageText,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'Time: $time',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
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
    _conversationAddedController.close();
    _messageDeleteController.close();
    _isInitialized = false;
  }
}
