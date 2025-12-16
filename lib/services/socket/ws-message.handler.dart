import 'dart:async';
import 'package:flutter/material.dart';
import '../../types/socket.types.dart';
import '../../utils/navigation-helper.util.dart';
import '../user-status.service.dart';
import 'websocket.service.dart';

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
  final StreamController<ConnectionStatus> _onlineStatusController =
      StreamController<ConnectionStatus>.broadcast();

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

  final StreamController<ConversationActionPayload>
  _conversationActionController =
      StreamController<ConversationActionPayload>.broadcast();

  final StreamController<DeleteMessagePayload> _messageDeleteController =
      StreamController<DeleteMessagePayload>.broadcast();

  final StreamController<JoinLeavePayload> _joinConversationController =
      StreamController<JoinLeavePayload>.broadcast();

  final StreamController<JoinLeavePayload> _leaveConversationController =
      StreamController<JoinLeavePayload>.broadcast();

  // Call message stream controllers
  final StreamController<CallPayload> _callInitController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callInitAckController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callOfferController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callAnswerController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callIceController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callAcceptController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callDeclineController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callEndController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callRingingController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callMissedController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callErrorController =
      StreamController<CallPayload>.broadcast();

  bool _isInitialized = false;

  /// Get stream for online status (type: 'connection:status')
  Stream<ConnectionStatus> get onlineStatusStream =>
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

  /// Get stream for conversation member/admin actions (type: 'conversation:action')
  Stream<ConversationActionPayload> get conversationActionStream =>
      _conversationActionController.stream;

  /// Get stream for message delete events (type: 'message:delete')
  Stream<DeleteMessagePayload> get messageDeleteStream =>
      _messageDeleteController.stream;

  /// Get stream for conversation join/leave events (type: 'conversation:join')
  Stream<JoinLeavePayload> get joinConversationStream =>
      _joinConversationController.stream;

  /// Get stream for conversation leave events (type: 'conversation:leave')
  Stream<JoinLeavePayload> get leaveConversationStream =>
      _leaveConversationController.stream;

  /// Get stream for call init events (type: 'call:init')
  Stream<CallPayload> get callInitStream => _callInitController.stream;

  /// Get stream for call init ack events (type: 'call:init:ack')
  Stream<CallPayload> get callInitAckStream => _callInitAckController.stream;

  /// Get stream for call offer events (type: 'call:offer')
  Stream<CallPayload> get callOfferStream => _callOfferController.stream;

  /// Get stream for call answer events (type: 'call:answer')
  Stream<CallPayload> get callAnswerStream => _callAnswerController.stream;

  /// Get stream for call ice events (type: 'call:ice')
  Stream<CallPayload> get callIceStream => _callIceController.stream;

  /// Get stream for call accept events (type: 'call:accept')
  Stream<CallPayload> get callAcceptStream => _callAcceptController.stream;

  /// Get stream for call decline events (type: 'call:decline')
  Stream<CallPayload> get callDeclineStream => _callDeclineController.stream;

  /// Get stream for call end events (type: 'call:end')
  Stream<CallPayload> get callEndStream => _callEndController.stream;

  /// Get stream for call ringing events (type: 'call:ringing')
  Stream<CallPayload> get callRingingStream => _callRingingController.stream;

  /// Get stream for call missed events (type: 'call:missed')
  Stream<CallPayload> get callMissedStream => _callMissedController.stream;

  /// Get stream for call error events (type: 'call:error')
  Stream<CallPayload> get callErrorStream => _callErrorController.stream;

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

  /// Helper to convert payload to CallPayload
  // CallPayload? _payloadToCallPayload(dynamic payload, WSMessage message) {
  //   if (payload == null) return null;
  //
  //   Map<String, dynamic>? payloadMap;
  //   if (payload is Map<String, dynamic>) {
  //     payloadMap = payload;
  //   } else if (payload is Map) {
  //     payloadMap = Map<String, dynamic>.from(payload);
  //   } else if (payload is CallPayload) {
  //     return payload;
  //   } else {
  //     try {
  //       payloadMap = payload.toJson() as Map<String, dynamic>?;
  //     } catch (e) {
  //       return null;
  //     }
  //   }
  //
  //   if (payloadMap == null) return null;
  //
  //   // Try to extract call information from the payload
  //   // Different call message types have different structures
  //   try {
  //     // Extract common fields
  //     final callId = payloadMap['callId'] ??
  //                    payloadMap['call_id'] ??
  //                    payloadMap['data']?['callId'] ??
  //                    payloadMap['data']?['call_id'];
  //
  //     final callerId = payloadMap['callerId'] ??
  //                      payloadMap['caller_id'] ??
  //                      payloadMap['from'] ??
  //                      payloadMap['from_id'] ??
  //                      payloadMap['sender_id'];
  //
  //     final calleeId = payloadMap['calleeId'] ??
  //                      payloadMap['callee_id'] ??
  //                      payloadMap['to'] ??
  //                      payloadMap['to_id'];
  //
  //     // If we don't have basic info, return null
  //     if (callerId == null && calleeId == null) {
  //       return null;
  //     }
  //
  //     // Parse IDs with proper null handling
  //     int? parsedCallerId;
  //     if (callerId is int) {
  //       parsedCallerId = callerId;
  //     } else if (callerId is String) {
  //       parsedCallerId = int.tryParse(callerId);
  //     }
  //
  //     int? parsedCalleeId;
  //     if (calleeId is int) {
  //       parsedCalleeId = calleeId;
  //     } else if (calleeId is String) {
  //       parsedCalleeId = int.tryParse(calleeId);
  //     }
  //
  //     // At least one ID must be present
  //     if (parsedCallerId == null && parsedCalleeId == null) {
  //       return null;
  //     }
  //
  //     return CallPayload(
  //       callId: callId is int ? callId : (callId is String ? int.tryParse(callId) : null),
  //       callerId: parsedCallerId ?? 0,
  //       callerName: payloadMap['callerName'] ?? payloadMap['caller_name'],
  //       callerPfp: payloadMap['callerProfilePic'] ?? payloadMap['caller_pfp'] ?? payloadMap['caller_profile_pic'],
  //       calleeId: parsedCalleeId ?? 0,
  //       calleeName: payloadMap['calleeName'] ?? payloadMap['callee_name'],
  //       calleePfp: payloadMap['calleeProfilePic'] ?? payloadMap['callee_pfp'] ?? payloadMap['callee_profile_pic'],
  //       data: payloadMap,
  //       error: payloadMap['error'],
  //       timestamp: message.wsTimestamp ?? DateTime.now(),
  //     );
  //   } catch (e) {
  //     debugPrint('⚠️ Error converting payload to CallPayload: $e');
  //     return null;
  //   }
  // }

  /// Handle incoming WebSocket messages and route them to appropriate streams
  void _handleMessage(WSMessage message) async {
    try {
      // Route messages to appropriate streams based on type
      switch (message.type) {
        // ---------------------------------------------------
        case WSMessageType.connectionStatus:
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

        case WSMessageType.conversationAction:
          final actionPayload = message.conversationActionPayload;
          if (actionPayload != null) {
            _conversationActionController.add(actionPayload);

            // Push a synthetic system ChatMessagePayload so message listeners update in-place
            final systemMessagePayload = ChatMessagePayload(
              optimisticId: actionPayload.eventId,
              canonicalId: actionPayload.eventId,
              senderId: actionPayload.actorId ?? 0,
              senderName: actionPayload.actorName,
              convId: actionPayload.convId,
              convType: actionPayload.convType,
              msgType: MessageType.system,
              body: actionPayload.message,
              attachments: null,
              metadata: {
                'action': actionPayload.action.value,
                'members':
                    actionPayload.members.map((m) => m.toJson()).toList(),
              },
              replyToMessageId: null,
              sentAt: actionPayload.actionAt,
            );
            _messageNewController.add(systemMessagePayload);
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

        case WSMessageType.conversationJoin:
          final payload = message.joinLeavePayload;
          if (payload != null) {
            _joinConversationController.add(payload);
          }
          break;

        case WSMessageType.conversationLeave:
          final payload = message.joinLeavePayload;
          if (payload != null) {
            _joinConversationController.add(payload);
          }
          break;

        case WSMessageType.socketHealthCheck:
          final payload = message.miscPayload;
          if (payload != null) {
            _showHealthCheckDialog(payload);
          }
          break;

        case WSMessageType.ping:
          // final payload = message.miscPayload;
          // if (payload != null) {
          //   _showHealthCheckDialog(payload);
          // }
          debugPrint('🏓 Ping received from server');
          break;

        case WSMessageType.pong:
          // final payload = message.miscPayload;
          // if (payload != null) {
          //   _showHealthCheckDialog(payload);
          // }
          debugPrint('🏓 Pong received from server');
          break;

        case WSMessageType.socketError:
          debugPrint('❌ WebSocket error: ${message.miscPayload?.message}');
          break;

        // Call-related messages
        case WSMessageType.callInit:
          final payload = message.callPayload;
          if (payload != null) {
            _callInitController.add(payload);
          }
          break;

        case WSMessageType.callInitAck:
          final payload = message.callPayload;
          if (payload != null) {
            _callInitAckController.add(payload);
          }
          break;

        case WSMessageType.callOffer:
          final payload = message.callPayload;
          if (payload != null) {
            _callOfferController.add(payload);
          }
          break;

        case WSMessageType.callAnswer:
          final payload = message.callPayload;
          if (payload != null) {
            _callAnswerController.add(payload);
          }
          break;

        case WSMessageType.callIce:
          final payload = message.callPayload;
          if (payload != null) {
            _callIceController.add(payload);
          }
          break;

        case WSMessageType.callAccept:
          final payload = message.callPayload;
          if (payload != null) {
            _callAcceptController.add(payload);
          }
          break;

        case WSMessageType.callDecline:
          final payload = message.callPayload;
          if (payload != null) {
            _callDeclineController.add(payload);
          }
          break;

        case WSMessageType.callEnd:
          final payload = message.callPayload;
          if (payload != null) {
            _callEndController.add(payload);
          }
          break;

        case WSMessageType.callRinging:
          final payload = message.callPayload;
          if (payload != null) {
            _callRingingController.add(payload);
          }
          break;

        case WSMessageType.callMissed:
          final payload = message.callPayload;
          if (payload != null) {
            _callMissedController.add(payload);
          }
          break;

        case WSMessageType.callError:
          final payload = message.callPayload;
          if (payload != null) {
            _callErrorController.add(payload);
          }
          break;

        case WSMessageType.messageForward:
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
  Stream<ChatMessagePayload> messageRepliesForConversation(int conversationId) {
    return messageNewStream.where(
      (payload) =>
          payload.convId == conversationId && payload.replyToMessageId != null,
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

  /// Get a filtered stream for conversation join/leave events in a specific conversation
  Stream<JoinLeavePayload> joinConversation(int conversationId) {
    return joinConversationStream.where(
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
              if (messageText != null) ...[
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
    _conversationActionController.close();
    _messageDeleteController.close();
    _joinConversationController.close();
    _leaveConversationController.close();
    _callInitController.close();
    _callInitAckController.close();
    _callOfferController.close();
    _callAnswerController.close();
    _callIceController.close();
    _callAcceptController.close();
    _callDeclineController.close();
    _callEndController.close();
    _callRingingController.close();
    _callMissedController.close();
    _callErrorController.close();
    _isInitialized = false;
  }
}
