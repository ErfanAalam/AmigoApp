import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/repositories/message.repo.dart';
import '../../../db/repositories/missed-ws-messages.repo.dart';
import '../../../models/message.model.dart';
import '../../../services/socket/transport.manager.dart';
import '../../../services/socket/transport.service.dart';
import '../../../services/socket/ws-message.handler.dart';
import '../../../services/user-info-cache.service.dart';
import '../../../types/socket.types.dart';

/// WebSocket plumbing shared by DM and group messaging screens. Owns the
/// per-conversation stream subscriptions and the small dedup-state fields
/// that the typing/join handlers need. Hosts call [setupWebSocketListener]
/// from `initState` and [disposeWebSocketListener] from `dispose`.
mixin ChatWebSocketMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  // Subscriptions owned by this mixin.
  StreamSubscription<ChatMessagePayload>? _messageSubscription;
  StreamSubscription<MessageSentAckPayload>? _messageAckSubscription;
  StreamSubscription<TypingPayload>? _typingSubscription;
  StreamSubscription<MessagePinPayload>? _messagePinSubscription;
  StreamSubscription<DeleteMessagePayload>? _messageDeleteSubscription;
  StreamSubscription<TransportConnectionState>?
      _transportConnectionSubscription;

  /// Tracks the last `last_read_msg_id` we sent so re-joins on reconnect are
  /// idempotent.
  String? lastSentReadMsgId;

  /// Cancels itself a few seconds after the last incoming typing event so
  /// the indicator auto-hides if the sender goes quiet.
  Timer? typingTimeout;

  /// Throttles outgoing `conversation:typing` so we don't flood the server
  /// on every keystroke.
  DateTime? lastTypingMessageSent;

  // ---- Inherited from sibling mixins ----
  bool get canSetState;
  void safeSetState(VoidCallback fn);
  String get conversationId;
  String? get currentUserId;
  List<MessageModel> get messages;
  MessageRepository get messagesRepo;
  TransportManager get transportManager;
  void animateNewMessage(String messageId);
  void sortMessagesBySentAt();
  Future<void> resendAllFailedMessages();
  MessageModel? get pinnedMessage;
  void setPinnedMessage(MessageModel? message);
  String get scrollDebugPrefix;

  // ---- Host-provided ----

  /// The single WS message-handler the host owns; this mixin subscribes to
  /// its per-conversation streams.
  WebSocketMessageHandler get wsMessageHandler;

  /// `ValueNotifier`s and the typing-dot animation that drive the
  /// "other person is typing" UI; lifted onto the host to avoid taking on
  /// `TickerProviderStateMixin` here.
  ValueNotifier<bool> get isOtherTypingNotifier;
  AnimationController get typingAnimationController;

  // ---- Public lifecycle ----

  void setupWebSocketListener() {
    final convId = conversationId;

    _messageSubscription = wsMessageHandler
        .messagesForConversation(convId)
        .listen(
          handleMessageNew,
          onError: (error) =>
              debugPrint('❌ Message stream error: $error'),
        );

    _messageAckSubscription = wsMessageHandler
        .sentAckForConversation(convId)
        .listen(
          handleSentAck,
          onError: (error) =>
              debugPrint('❌ Message ack stream error: $error'),
        );

    _typingSubscription = wsMessageHandler
        .typingForConversation(convId)
        .listen(
          receiveTyping,
          onError: (error) =>
              debugPrint('❌ Typing stream error: $error'),
        );

    _messagePinSubscription = wsMessageHandler
        .messagePinsForConversation(convId)
        .listen(
          handleMessagePin,
          onError: (error) =>
              debugPrint('❌ Message pin stream error: $error'),
        );

    _messageDeleteSubscription = wsMessageHandler
        .messageDeletesForConversation(convId)
        .listen(
          handleMessageDelete,
          onError: (error) =>
              debugPrint('❌ Message delete stream error: $error'),
        );

    // On reconnect: re-join so the server marks us active in this
    // conversation, and resend any failed messages.
    _transportConnectionSubscription =
        transportManager.connectionStateStream.listen((state) {
      if (state == TransportConnectionState.connected) {
        debugPrint(
          '$scrollDebugPrefix 🎐🎐🎐 Transport reconnected — '
          're-joining conversation and resending failed messages',
        );
        sendConversationJoin();
        resendAllFailedMessages();
      }
    });
  }

  void disposeWebSocketListener() {
    _messageSubscription?.cancel();
    _messageAckSubscription?.cancel();
    _typingSubscription?.cancel();
    _messagePinSubscription?.cancel();
    _messageDeleteSubscription?.cancel();
    _transportConnectionSubscription?.cancel();
    typingTimeout?.cancel();
  }

  /// Sends `conversation:join` to the server (idempotent — the
  /// [lastSentReadMsgId] dedup keeps re-fires cheap). If the transport is
  /// down the event is queued for replay via [MissedWsMessagesRepository].
  Future<void> sendConversationJoin() async {
    final userId = currentUserId;
    if (userId == null) return;

    // Walk backwards to find the latest non-system message — system
    // messages are client-only and don't exist in the backend table.
    String latestMsgId = '';
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].type != MessageType.system) {
        latestMsgId = messages[i].id;
        break;
      }
    }
    if (latestMsgId.isEmpty || latestMsgId == lastSentReadMsgId) return;
    lastSentReadMsgId = latestMsgId;

    final payload = ConvJoinPayload(
      convId: conversationId,
      userId: userId,
      lastReadMsgId: latestMsgId,
    );
    final wsmsg = WSMessage(
      type: WSMessageType.conversationJoin,
      payload: payload.toJson(),
      wsTimestamp: DateTime.now(),
    ).toJson();

    if (transportManager.isConnected) {
      await transportManager.sendMessage(wsmsg);
    } else {
      MissedWsMessagesRepository().storeEvent(
        'conversation:join',
        payload.toJson(),
      );
    }
  }

  // ---- Stream handlers ----

  void handleMessageNew(ChatMessagePayload payload) async {
    try {
      final senderDetails = await UserInfoCache.instance.getUser(
        payload.senderId,
      );

      final attachments = payload.attachments is Map<String, dynamic>
          ? payload.attachments as Map<String, dynamic>
          : null;
      final message = MessageModel(
        id: payload.id,
        chatId: payload.convId,
        senderId: payload.senderId,
        attachments: attachments,
        body: payload.body,
        senderName: senderDetails?.name ?? '',
        senderProfilePic: senderDetails?.profilePic ?? '',
        repliedTo: payload.repliedTo,
        type: payload.msgType,
        sentAt: payload.sentAt.toIso8601String(),
      );

      // Echo of our own optimistic send: replace the placeholder with the
      // server-confirmed copy and persist.
      if (payload.senderId == currentUserId) {
        final existingIndex = messages.indexWhere(
          (msg) => msg.id == payload.id && msg.senderId == payload.senderId,
        );
        if (existingIndex != -1) {
          if (!canSetState) return;
          safeSetState(() {
            messages[existingIndex] = message.copyWith(
              id: messages[existingIndex].id,
            );
            sortMessagesBySentAt();
          });
          await messagesRepo.insertMessage(message);
          return;
        }
      }

      // De-dup against any existing row with the same id (handles late
      // arrivals after a sync pulled the same message).
      final duplicateIndex =
          messages.indexWhere((msg) => msg.id == message.id);

      if (!canSetState) return;
      safeSetState(() {
        if (duplicateIndex != -1) {
          messages[duplicateIndex] = message;
          return;
        }
        if (messages.isEmpty) {
          messages.add(message);
          return;
        }
        // Optimization: if the new message is at-or-after the tail, just
        // append. Older arrivals (rare — happens after reconnect / sync)
        // get a sort.
        try {
          final lastTime = DateTime.parse(messages.last.sentAt);
          final newTime = DateTime.parse(message.sentAt);
          messages.add(message);
          if (newTime.isBefore(lastTime)) {
            sortMessagesBySentAt();
          }
        } catch (_) {
          messages.add(message);
          sortMessagesBySentAt();
        }
      });

      animateNewMessage(message.id);
    } catch (e) {
      debugPrint('❌ Error processing incoming message: $e');
    }
  }

  void handleSentAck(MessageSentAckPayload payload) async {
    try {
      final messageIndex =
          messages.indexWhere((msg) => msg.id == payload.msgId);
      if (messageIndex == -1) {
        debugPrint(
          '⚠️ Message id ${payload.msgId} not found in messages list',
        );
        return;
      }

      // Server may stamp a new id (legacy path; under UUIDv7 the client
      // id is permanent and `newId` will match).
      final effectiveId = payload.newId ?? payload.msgId;

      if (!canSetState) return;
      safeSetState(() {
        messages[messageIndex] = messages[messageIndex].copyWith(
          id: effectiveId,
          isFailed: !payload.isSent,
        );
      });

      try {
        await messagesRepo.updateMessageFields(
          payload.msgId,
          isFailed: !payload.isSent,
        );
      } catch (e) {
        debugPrint('❌ Error updating message in DB: $e');
      }
    } catch (e) {
      debugPrint('❌ Error processing message_sent_ack: $e');
    }
  }

  void handleMessageDelete(DeleteMessagePayload payload) async {
    final indicesToRemove = <int>[];
    for (final msgId in payload.messageIds) {
      final idx = messages.indexWhere((msg) => msg.id == msgId);
      if (idx != -1) indicesToRemove.add(idx);
    }
    if (indicesToRemove.isEmpty) return;

    // Remove descending so prior removes don't shift later indices.
    indicesToRemove.sort((a, b) => b.compareTo(a));
    if (!canSetState) return;
    safeSetState(() {
      for (final idx in indicesToRemove) {
        messages.removeAt(idx);
      }
    });
  }

  void handleMessagePin(MessagePinPayload payload) async {
    if (!canSetState) return;
    if (payload.pin) {
      final pinned = await messagesRepo.getMessageById(payload.messageId);
      if (!canSetState) return;
      safeSetState(() {
        setPinnedMessage(pinned);
      });
    } else {
      safeSetState(() {
        setPinnedMessage(null);
      });
    }
  }

  void receiveTyping(TypingPayload payload) {
    if (!canSetState) return;

    typingTimeout?.cancel();
    isOtherTypingNotifier.value = true;
    typingAnimationController.repeat(reverse: true);

    typingTimeout = Timer(const Duration(seconds: 3), () {
      if (!canSetState) return;
      isOtherTypingNotifier.value = false;
      typingAnimationController.stop();
      typingAnimationController.reset();
    });
  }

  /// Outgoing typing throttler — wired to the message-input's `onChanged`.
  /// Sends `conversation:typing` on the first keystroke and at most once
  /// every 2s afterwards; resets the throttle when the user clears input.
  void handleTyping(String value) async {
    if (!canSetState) return;
    final isTyping = value.isNotEmpty;

    if (!isTyping) {
      lastTypingMessageSent = null;
      return;
    }

    final now = DateTime.now();
    final shouldSend = lastTypingMessageSent == null ||
        now.difference(lastTypingMessageSent!).inSeconds >= 2;
    if (!shouldSend) return;

    final userId = currentUserId;
    if (userId == null) return;

    final typingPayload = TypingPayload(
      convId: conversationId,
      senderId: userId,
    ).toJson();
    final wsmsg = WSMessage(
      type: WSMessageType.conversationTyping,
      payload: typingPayload,
      wsTimestamp: now,
    ).toJson();

    await transportManager.sendMessage(wsmsg).catchError((e) {
      debugPrint('Error sending conversation:typing message: $e');
      return false;
    });

    lastTypingMessageSent = now;
  }
}
