import 'dart:async';
import 'package:flutter/material.dart';
import 'websocket_service.dart';
import '../user_status_service.dart';
import '../../utils/navigation_helper.dart';
import '../../types/socket.type.dart';

/// Centralized WebSocket message handler that processes all messages once
/// and distributes them via filtered streams for widgets to consume
class WebSocketMessageHandler {
  static final WebSocketMessageHandler _instance =
      WebSocketMessageHandler._internal();
  factory WebSocketMessageHandler() => _instance;
  WebSocketMessageHandler._internal();

  final WebSocketService _websocketService = WebSocketService();
  final UserStatusService _userStatusService = UserStatusService();
  StreamSubscription<WSMessage>? _messageSubscription;

  // Stream controllers for different message types
  final StreamController<OnlineStatusPayload> _onlineStatusController =
      StreamController<OnlineStatusPayload>.broadcast();

  final StreamController<ChatMessagePayload> _messageNewController =
      StreamController<ChatMessagePayload>.broadcast();

  final StreamController<ChatMessageAckPayload> _messageAckController =
      StreamController<ChatMessageAckPayload>.broadcast();

  final StreamController<TypingPayload> _typingController =
      StreamController<TypingPayload>.broadcast();

  final StreamController<MessagePinPayload> _messagePinController =
      StreamController<MessagePinPayload>.broadcast();

  final StreamController<NewConversationPayload> _conversationAddedController =
      StreamController<NewConversationPayload>.broadcast();

  final StreamController<DeleteMessagePayload> _messageDeleteController =
      StreamController<DeleteMessagePayload>.broadcast();

  bool _isInitialized = false;

  /// Get stream for online status (type: 'user:online_status')
  Stream<OnlineStatusPayload> get onlineStatusStream =>
      _onlineStatusController.stream;

  /// Get stream for messages (type: 'message:new')
  Stream<ChatMessagePayload> get messageNewStream =>
      _messageNewController.stream;

  /// Get stream for media messages (type: 'message:ack')
  Stream<ChatMessageAckPayload> get messageAckStream =>
      _messageAckController.stream;

  /// Get stream for typing indicators (type: 'conversation:typing')
  Stream<TypingPayload> get typingStream => _typingController.stream;

  /// Get stream for message pins (type: 'message:pin')
  Stream<MessagePinPayload> get messagePinStream =>
      _messagePinController.stream;

  /// Get stream for conversation added events (type: 'conversation:new')
  Stream<NewConversationPayload> get conversationAddedStream =>
      _conversationAddedController.stream;

  /// Get stream for message delete events (type: 'message:delete')
  Stream<DeleteMessagePayload> get messageDeleteStream =>
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
  void _handleMessage(WSMessage message) async {
    try {
      // Route messages to appropriate streams based on type
      switch (message.type) {
        // ---------------------------------------------------
        case WSMessageType.userOnlineStatus:
          final payload = message.onlineStatusPayload;
          if (payload != null) {
            _userStatusService.handleUserOnlineMessage(payload);
            _onlineStatusController.add(payload);
          }
          break;

        case WSMessageType.conversationNew:
          final newConvPayload = message.newConversationPayload;
          if (newConvPayload != null) {
            _conversationAddedController.add(newConvPayload);
          }
          break;

        case WSMessageType.messageNew:
          final payload = message.chatMessagePayload;
          if (payload != null) {
            _messageNewController.add(payload);
          }
          break;

        case WSMessageType.messageAck:
          final payload = message.chatMessageAckPayload;
          if (payload != null) {
            _messageAckController.add(payload);
          }
          break;

        case WSMessageType.conversationTyping:
          final payload = message.typingPayload;
          if (payload != null) _typingController.add(payload);
          break;

        case WSMessageType.messagePin:
          final payload = message.messagePinPayload;
          if (payload != null) {
            _messagePinController.add(payload);
          }
          break;

        case WSMessageType.messageReply:
          // Reply messages are now ChatMessagePayload with replyToMessageId
          final payload = message.chatMessagePayload;
          if (payload != null) {
            _messageNewController.add(payload);
          }
          break;

        case WSMessageType.messageDelete:
          final payload = message.deleteMessagePayload;
          if (payload != null) {
            _messageDeleteController.add(payload);
          }
          break;

        case WSMessageType.socketHealthCheck:
          final payload = message.miscPayload;
          if (payload != null) {
            _showHealthCheckDialog(payload);
          }
          break;

        case WSMessageType.socketError:
          debugPrint('❌ WebSocket error: ${message.miscPayload?.message}');
          break;

        // Call-related messages (handled elsewhere or can be added here)
        case WSMessageType.callInit:
        case WSMessageType.callOffer:
        case WSMessageType.callAnswer:
        case WSMessageType.callIce:
        case WSMessageType.callAccept:
        case WSMessageType.callDecline:
        case WSMessageType.callEnd:
        case WSMessageType.callRinging:
        case WSMessageType.callMissed:
          // Call messages are handled by call service
          debugPrint('📞 Call message received: ${message.type.value}');
          break;

        case WSMessageType.conversationJoin:
        case WSMessageType.conversationLeave:
          // Join/leave messages can be handled if needed
          debugPrint('👥 Conversation join/leave: ${message.type.value}');
          break;

        case WSMessageType.messageForward:
          // Forward messages can be handled if needed
          debugPrint('↩️ Message forward: ${message.type.value}');
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling WebSocket message');
    }
  }

  /// Get a filtered stream for messages in a specific conversation
  Stream<ChatMessagePayload> messagesForConversation(int conversationId) {
    return messageNewStream.where(
      (payload) => payload.convId == conversationId,
    );
  }

  /// Get a filtered stream for messages in a specific conversation
  Stream<ChatMessageAckPayload> messagesAckForConversation(int conversationId) {
    return messageAckStream.where(
      (payload) => payload.convId == conversationId,
    );
  }

  /// Get a filtered stream for typing indicators in a specific conversation
  Stream<TypingPayload> typingForConversation(int conversationId) {
    return typingStream.where((payload) => payload.convId == conversationId);
  }

  /// Get a filtered stream for message pins in a specific conversation
  Stream<MessagePinPayload> messagePinsForConversation(int conversationId) {
    return messagePinStream.where(
      (payload) => payload.convId == conversationId,
    );
  }

  /// Get a filtered stream for message replies in a specific conversation
  Stream<ChatMessagePayload> messageRepliesForConversation(
    int conversationId,
  ) {
    return messageNewStream.where(
      (payload) =>
          payload.convId == conversationId &&
          payload.replyToMessageId != null,
    );
  }

  /// Get a filtered stream for message delete events in a specific conversation
  Stream<DeleteMessagePayload> messageDeletesForConversation(
    int conversationId,
  ) {
    return messageDeleteStream.where(
      (payload) => payload.convId == conversationId,
    );
  }

  /// Show health check dialog
  void _showHealthCheckDialog(MiscPayload payload) {
    final data = payload.data as Map<String, dynamic>?;
    final time = data?['time'] as String? ?? 'Unknown time';
    final messageText = payload.message;

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
    _messageNewController.close();
    _messageAckController.close();
    _typingController.close();
    _messagePinController.close();
    _onlineStatusController.close();
    _conversationAddedController.close();
    _messageDeleteController.close();
    _isInitialized = false;
  }
}
