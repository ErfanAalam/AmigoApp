import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../db/repositories/conversations.repo.dart';
import '../../db/repositories/user.repo.dart';
import '../../types/socket.types.dart';
import '../../utils/navigation-helper.util.dart';
import '../user-status.service.dart';
import '../auth/auth.service.dart';
import 'transport.manager.dart';

/// Centralized WebSocket message handler that processes all messages once
/// and distributes them via filtered streams for widgets to consume
class WebSocketMessageHandler {
  static final WebSocketMessageHandler _instance =
      WebSocketMessageHandler._internal();
  factory WebSocketMessageHandler() => _instance;
  WebSocketMessageHandler._internal();

  final TransportManager _transportManager = TransportManager();
  final UserStatusService _userStatusService = UserStatusService();
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  // Stream controllers for different message types
  final StreamController<ConnectionStatusPayload> _onlineStatusController =
      StreamController<ConnectionStatusPayload>.broadcast();

  final StreamController<ChatMessagePayload> _messageNewController =
      StreamController<ChatMessagePayload>.broadcast();

  final StreamController<MessageSentAckPayload> _messageSentAckController =
      StreamController<MessageSentAckPayload>.broadcast();

  final StreamController<MessageStatusAckPayload> _messageStatusAckController =
      StreamController<MessageStatusAckPayload>.broadcast();

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

  final StreamController<ConvJoinPayload> _joinConversationController =
      StreamController<ConvJoinPayload>.broadcast();

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

  final StreamController<CallPayload> _callRingingController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callTerminateController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callErrorController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callHoldController =
      StreamController<CallPayload>.broadcast();

  final StreamController<CallPayload> _callMissedController =
      StreamController<CallPayload>.broadcast();

  // Emoji reactions controller
  final StreamController<MessageReactPayload> _messageReactController =
      StreamController<MessageReactPayload>.broadcast();

  // Profile updates from peers (name / profile pic changes)
  final StreamController<UserUpdatePayload> _userUpdateController =
      StreamController<UserUpdatePayload>.broadcast();

  // Disappearing-messages duration changes from peers
  final StreamController<ConversationDisappearingPayload>
  _conversationDisappearingController =
      StreamController<ConversationDisappearingPayload>.broadcast();

  final UserRepository _userRepo = UserRepository();
  final ConversationRepository _convRepo = ConversationRepository();

  bool _isInitialized = false;

  /// Get stream for online status (type: 'connection:status')
  Stream<ConnectionStatusPayload> get onlineStatusStream =>
      _onlineStatusController.stream;

  /// Get stream for messages (type: 'message:new')
  Stream<ChatMessagePayload> get messageNewStream =>
      _messageNewController.stream;

  /// Get stream for sent ack (type: 'message:sent:ack')
  Stream<MessageSentAckPayload> get messageSentAckStream =>
      _messageSentAckController.stream;

  /// Get stream for status ack (type: 'message:status:ack')
  Stream<MessageStatusAckPayload> get messageStatusAckStream =>
      _messageStatusAckController.stream;

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

  /// Get stream for conversation join events (type: 'conversation:join')
  Stream<ConvJoinPayload> get joinConversationStream =>
      _joinConversationController.stream;

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

  /// Get stream for call ringing events (type: 'call:ringing')
  Stream<CallPayload> get callRingingStream => _callRingingController.stream;

  /// Get stream for call terminate events (type: 'call:terminate')
  Stream<CallPayload> get callTerminateStream =>
      _callTerminateController.stream;

  /// Get stream for call error events (type: 'call:error')
  Stream<CallPayload> get callErrorStream => _callErrorController.stream;

  /// Get stream for call hold events (type: 'call:hold')
  Stream<CallPayload> get callHoldStream => _callHoldController.stream;

  /// Get stream for call missed events (type: 'call:missed')
  Stream<CallPayload> get callMissedStream => _callMissedController.stream;

  /// Get stream for emoji reactions (type: 'message:react')
  Stream<MessageReactPayload> get messageReactStream =>
      _messageReactController.stream;

  /// Get stream for peer profile updates (type: 'user:update')
  Stream<UserUpdatePayload> get userUpdateStream =>
      _userUpdateController.stream;

  /// Get stream for disappearing-messages setting changes
  /// (type: 'conversation:disappearing')
  Stream<ConversationDisappearingPayload> get conversationDisappearingStream =>
      _conversationDisappearingController.stream;

  /// Add a message directly to the messageNewStream
  /// This is used by transports (like LongPollingTransport) to add synced messages
  void addMessage(ChatMessagePayload payload) {
    _messageNewController.add(payload);
  }

  /// Initialize the handler - call this once when app starts
  void initialize() {
    if (_isInitialized) {
      debugPrint('⚠️ WebSocketMessageHandler already initialized');
      return;
    }

    _messageSubscription = _transportManager.messageStream.listen(
      (jsonMap) {
        try {
          debugPrint("passing through ws message handler: ${jsonMap['type']}");
          // Parse the JSON map into WSMessage
          final message = WSMessage.fromJson(jsonMap);
          _handleMessage(message);
        } catch (e, stackTrace) {
          debugPrint('❌ Error parsing message: $e');
          debugPrint('❌ Stack trace: $stackTrace');
        }
      },
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
        case WSMessageType.connectionStatus:
          final payload = message.connectionStatusPayload;
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
            // chat_details:update is a metadata change on the chat row
            // itself — apply to local DB so Drift watchers (group-list,
            // group AppBar, chat-details) re-emit and the UI updates in
            // place. The conv_action stream is still fired so legacy
            // listeners (e.g. chat provider) don't break.
            if (actionPayload.action ==
                ConversationActionType.chatDetailsUpdate) {
              await _applyChatDetailsUpdate(actionPayload);
            }

            _conversationActionController.add(actionPayload);

            // Push a synthetic system ChatMessagePayload so message listeners update in-place
            final systemMessagePayload = ChatMessagePayload(
              id: actionPayload.eventId,
              senderId: actionPayload.actorId ?? '',
              convId: actionPayload.convId,
              msgType: MessageType.system,
              body: actionPayload.message,
              attachments: null,
              repliedTo: null,
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

        case WSMessageType.messageSentAck:
          final payload = message.messageSentAckPayload;
          if (payload != null) {
            _messageSentAckController.add(payload);
          }
          break;

        case WSMessageType.messageStatusAck:
          final payload = message.messageStatusAckPayload;
          if (payload != null) {
            _messageStatusAckController.add(payload);
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

        case WSMessageType.messageDelete:
          final payload = message.deleteMessagePayload;
          if (payload != null) {
            _messageDeleteController.add(payload);
          }
          break;

        case WSMessageType.messageReact:
          final reactPayload = message.messageReactPayload;
          if (reactPayload != null) {
            _messageReactController.add(reactPayload);
          }
          break;

        case WSMessageType.conversationJoin:
          final payload = message.convJoinPayload;
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

        case WSMessageType.socketPing:
          // Ping messages have no payload
          debugPrint('🏓 Ping received from server');
          break;

        case WSMessageType.socketPong:
          // Pong messages have no payload
          debugPrint('🏓 Pong received from server');
          break;

        case WSMessageType.socketError:
          debugPrint('❌ WebSocket error: ${message.payload.toString()}');
          break;

        case WSMessageType.authForceLogout:
          debugPrint(
            '🚪 Force logout received: ${message.miscPayload?.message}',
          );
          // Handle force logout - user logged in on another device
          _handleForceLogout(message.miscPayload);
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

        case WSMessageType.callRinging:
          final payload = message.callPayload;
          if (payload != null) {
            _callRingingController.add(payload);
          }
          break;

        case WSMessageType.callTerminate:
          final payload = message.callPayload;
          if (payload != null) {
            _callTerminateController.add(payload);
          }
          break;

        case WSMessageType.callError:
          final payload = message.callPayload;
          if (payload != null) {
            _callErrorController.add(payload);
          }
          break;

        case WSMessageType.callHold:
          final holdPayload = message.callPayload;
          if (holdPayload != null) {
            _callHoldController.add(holdPayload);
          }
          break;

        case WSMessageType.callMissed:
          final missedPayload = message.callPayload;
          if (missedPayload != null) {
            _callMissedController.add(missedPayload);
          }
          break;

        case WSMessageType.messageForward:
          debugPrint('↩️ Message forward: ${message.type.value}');
          break;

        case WSMessageType.userUpdate:
          final payload = message.userUpdatePayload;
          if (payload != null) {
            await _applyUserUpdate(payload);
            _userUpdateController.add(payload);
          }
          break;

        case WSMessageType.conversationDisappearing:
          // Persist the new duration locally so any future message:new with
          // expires_at is consistent with the chat's setting, and surface the
          // change on the stream for the chat-details UI to update.
          final payload = message.conversationDisappearingPayload;
          if (payload != null) {
            try {
              await _convRepo.setDisappearingAfterSec(
                payload.convId,
                payload.durationSec,
              );
            } catch (e) {
              debugPrint('⚠️ setDisappearingAfterSec failed: $e');
            }
            _conversationDisappearingController.add(payload);
          }
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling WebSocket message');
    }
  }

  /// Get a filtered stream for messages in a specific conversation
  Stream<ChatMessagePayload> messagesForConversation(String conversationId) {
    return messageNewStream.where(
      (payload) => payload.convId == conversationId,
    );
  }

  /// Get a filtered stream for sent acks in a specific conversation
  Stream<MessageSentAckPayload> sentAckForConversation(String conversationId) {
    return messageSentAckStream.where(
      (payload) => payload.convId == conversationId,
    );
  }

  /// Get a filtered stream for status acks in a specific conversation
  Stream<MessageStatusAckPayload> statusAckForConversation(String conversationId) {
    return messageStatusAckStream.where(
      (payload) => payload.acks.any((ack) => ack.chatId == conversationId),
    );
  }

  /// Get a filtered stream for typing indicators in a specific conversation
  Stream<TypingPayload> typingForConversation(String conversationId) {
    return typingStream.where((payload) => payload.convId == conversationId);
  }

  /// Get a filtered stream for message pins in a specific conversation
  Stream<MessagePinPayload> messagePinsForConversation(String conversationId) {
    return messagePinStream.where(
      (payload) => payload.convId == conversationId,
    );
  }

  /// Get a filtered stream for message replies in a specific conversation
  Stream<ChatMessagePayload> messageRepliesForConversation(String conversationId) {
    return messageNewStream.where(
      (payload) =>
          payload.convId == conversationId && payload.repliedTo != null,
    );
  }

  /// Get a filtered stream for message delete events in a specific conversation
  Stream<DeleteMessagePayload> messageDeletesForConversation(
    String conversationId,
  ) {
    return messageDeleteStream.where(
      (payload) => payload.convId == conversationId,
    );
  }

  /// Get a filtered stream for conversation join events in a specific conversation
  Stream<ConvJoinPayload> joinForConversation(String conversationId) {
    return joinConversationStream.where(
      (payload) => payload.convId == conversationId,
    );
  }

  /// Persist a peer's profile update locally and evict their stale PFP
  /// from the on-disk image cache. Watchers of the Users table will
  /// re-render automatically thanks to Drift's reactive streams.
  Future<void> _applyUserUpdate(UserUpdatePayload payload) async {
    try {
      // Update name if provided
      if (payload.name != null && payload.name!.isNotEmpty) {
        await _userRepo.updateUserName(payload.userId, payload.name!);
      }

      // Update profile pic. Treat empty string the same as null so a user
      // who clears their PFP locally also clears it for peers.
      final newPic = payload.profilePic;
      final normalizedPic =
          (newPic == null || newPic.isEmpty) ? null : newPic;
      // Only touch the PFP column when the server actually included a value
      // — `name`-only updates leave profile_pic unchanged.
      if (newPic != null) {
        await _userRepo.updateUserProfilePic(payload.userId, normalizedPic);
      }

      // Evict the previous PFP from the disk + memory cache so widgets
      // pick up the new one without a force restart. CachedNetworkImage
      // is keyed by URL, so simply removing the stale URL is enough.
      final previousPic = payload.previousProfilePic;
      if (previousPic != null && previousPic.isNotEmpty) {
        try {
          await CachedNetworkImage.evictFromCache(previousPic);
          await DefaultCacheManager().removeFile(previousPic);
        } catch (e) {
          debugPrint('⚠️ Failed to evict previous PFP from cache: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Error applying user:update for ${payload.userId}: $e');
    }
  }

  /// Persist a chat_details:update locally and evict the previous group pfp
  /// from the image cache. Drift watchers on the chats row re-emit, so any
  /// AppBar / list tile subscribed via watchChatById / watchGroupConversations
  /// repaints with the new title or avatar without any setState plumbing.
  Future<void> _applyChatDetailsUpdate(
    ConversationActionPayload payload,
  ) async {
    try {
      if (payload.title != null) {
        await _convRepo.updateChatTitle(payload.convId, payload.title!);
      }

      if (payload.profilePicChanged) {
        final newPic = payload.profilePic;
        final normalizedPic =
            (newPic == null || newPic.isEmpty) ? null : newPic;
        await _convRepo.updateChatProfilePic(payload.convId, normalizedPic);

        final previousPic = payload.previousProfilePic;
        if (previousPic != null && previousPic.isNotEmpty) {
          try {
            await CachedNetworkImage.evictFromCache(previousPic);
            await DefaultCacheManager().removeFile(previousPic);
          } catch (e) {
            debugPrint('⚠️ Failed to evict previous group pfp: $e');
          }
        }
      }
    } catch (e) {
      debugPrint(
        '❌ Error applying chat_details:update for ${payload.convId}: $e',
      );
    }
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

  /// Handle force logout when user logs in on another device
  void _handleForceLogout(MiscPayload? payload) async {
    final messageText =
        payload?.message ??
        'You have been logged out because you logged in on another device';

    // Get the navigator context
    final context = NavigationHelper.navigatorKey.currentContext;
    if (context == null) {
      debugPrint(
        '⚠️ Cannot show force logout dialog: Navigator context is null',
      );
      // Still proceed with logout even without context
      await AuthService().logout();
      return;
    }

    // Show dialog first, then logout
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.orange[600], size: 28),
              const SizedBox(width: 12),
              const Text('Logged Out'),
            ],
          ),
          content: Text(messageText),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await AuthService().logout();
              },
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
    _messageSentAckController.close();
    _messageStatusAckController.close();
    _typingController.close();
    _messagePinController.close();
    _onlineStatusController.close();
    _conversationAddedController.close();
    _conversationActionController.close();
    _messageDeleteController.close();
    _joinConversationController.close();
    _callInitController.close();
    _callInitAckController.close();
    _callOfferController.close();
    _callAnswerController.close();
    _callIceController.close();
    _callAcceptController.close();
    _callRingingController.close();
    _callTerminateController.close();
    _callErrorController.close();
    _callHoldController.close();
    _callMissedController.close();
    _messageReactController.close();
    _userUpdateController.close();
    _conversationDisappearingController.close();
    _isInitialized = false;
  }
}
