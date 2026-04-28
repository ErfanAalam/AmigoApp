part of 'dm-messaging.screen.dart';

extension _DmWsHandlers on _InnerChatPageState {
  void _setupWebSocketListener() {
    final convId = widget.dm.chatId;

    // Listen to messages filtered for this conversation
    _messageSubscription = _wsMessageHandler
        .messagesForConversation(convId)
        .listen(
          (payload) {
            _handleMessageNew(payload);
          },
          onError: (error) {
            debugPrint('❌ Message stream error: $error');
          },
        );

    // Listen to sent-ack messages filtered for this conversation
    _messageAckSubscription = _wsMessageHandler
        .sentAckForConversation(convId)
        .listen(
          (payload) {
            _handleSentAck(payload);
          },
          onError: (error) {
            debugPrint('❌ Message stream error: $error');
          },
        );

    // Listen to typing events for this conversation
    _typingSubscription = _wsMessageHandler
        .typingForConversation(convId)
        .listen(
          (payload) => _receiveTyping(payload),
          onError: (error) {
            debugPrint('❌ Typing stream error: $error');
          },
        );

    // Listen to message pins for this conversation
    _messagePinSubscription = _wsMessageHandler
        .messagePinsForConversation(convId)
        .listen(
          (payload) => _handleMessagePin(payload),
          onError: (error) {
            debugPrint('❌ Message pin stream error: $error');
          },
        );

    // Listen to message delete events for this conversation
    _messageDeleteSubscription = _wsMessageHandler
        .messageDeletesForConversation(convId)
        .listen(
          (payload) => _handleMessageDelete(payload),
          onError: (error) {
            debugPrint('❌ Message delete stream error: $error');
          },
        );
    // joinConversation stream removed — read-receipt state is now sourced
    // from MessageInfoModel streams, so the join callback is a no-op.

    // Listen to transport connection state changes:
    // 1. Re-send conversation:join so server knows we're still active
    // 2. Auto-resend any failed messages
    _transportConnectionSubscription = _transportManager.connectionStateStream
        .listen((state) {
          if (state == TransportConnectionState.connected) {
            debugPrint(
              '[DM] 🎐🎐🎐 Transport reconnected, re-joining conversation and resending failed messages',
            );
            // Re-join conversation so server updates active_in_conv
            _sendConversationJoin();
            _resendAllFailedMessages();
          }
        });
  }

  Future<void> _sendConversationJoin() async {
    if (_currentUserDetails == null) return;
    // Walk backwards to find the latest NON-system message — system messages
    // are client-only and don't exist in the backend messages table.
    String latestMsgId = '';
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].type != MessageType.system) {
        latestMsgId = _messages[i].id;
        break;
      }
    }
    if (latestMsgId.isEmpty || latestMsgId == _lastSentReadMsgId) return;
    _lastSentReadMsgId = latestMsgId;
    final joinConvPayload = ConvJoinPayload(
      convId: widget.dm.chatId,
      userId: _currentUserDetails!.id,
      lastReadMsgId: latestMsgId,
    );
    final wsmsg = WSMessage(
      type: WSMessageType.conversationJoin,
      payload: joinConvPayload.toJson(),
      wsTimestamp: DateTime.now(),
    ).toJson();
    if (_transportManager.isConnected) {
      await _transportManager.sendMessage(wsmsg);
    } else {
      MissedWsMessagesRepository().storeEvent(
        'conversation:join',
        joinConvPayload.toJson(),
      );
    }
  }

  void _handleMessageDelete(DeleteMessagePayload payload) async {
    // Find all message indices to remove
    final indicesToRemove = <int>[];
    for (final msgId in payload.messageIds) {
      final messageIndex = _messages.indexWhere((msg) => msg.id == msgId);
      if (messageIndex != -1) {
        indicesToRemove.add(messageIndex);
      }
    }

    // Remove messages in reverse order to avoid index shifting issues
    if (indicesToRemove.isNotEmpty) {
      indicesToRemove.sort((a, b) => b.compareTo(a)); // Sort descending
      if (!_canSetState) return;
      _safeSetState(() {
        for (final index in indicesToRemove) {
          _messages.removeAt(index);
        }
      });
    }
  }

  void _handleMessageNew(ChatMessagePayload payload) async {
    try {
      final senderDetails = await UserInfoCache.instance.getUser(
        payload.senderId,
      );

      // create message model from payload
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

      // If this is a message from the current user, check if we have an optimistic message
      // that matches by id and update it instead of adding a duplicate
      if (payload.senderId == _currentUserDetails?.id) {
        final existingIndex = _messages.indexWhere(
          (msg) => (msg.id == payload.id && msg.senderId == payload.senderId),
        );

        if (existingIndex != -1) {
          // Update existing message with server response
          if (!_canSetState) {
            return;
          }
          _safeSetState(() {
            final updatedMessage = message.copyWith(
              id: _messages[existingIndex].id,
            );
            _messages[existingIndex] = updatedMessage;
            _sortMessagesBySentAt();
          });

          // Save to DB
          await _messagesRepo.insertMessage(message);
          return;
        }
      }

      // Add message to UI immediately with animation
      if (!_canSetState) {
        return;
      }
      _safeSetState(() {
        _messages.add(message);
        _sortMessagesBySentAt();
      });

      animateNewMessage(message.id);
    } catch (e) {
      debugPrint('❌ Error processing incoming message: $e');
    }
  }

  void _handleSentAck(MessageSentAckPayload payload) async {
    try {
      // Find the message with matching msgId
      final messageIndex = _messages.indexWhere(
        (msg) => msg.id == payload.msgId,
      );

      if (messageIndex == -1) {
        debugPrint(
          '⚠️ Message with Id ${payload.msgId} not found in _messages',
        );
        return;
      }

      final currentMessage = _messages[messageIndex];

      // Clear uploading state on attachments (if any) — there is no longer a
      // metadata field on MessageModel; upload progress is tracked inside
      // the attachments map instead.
      Map<String, dynamic>? updatedAttachments;
      if (currentMessage.attachments is Map<String, dynamic>) {
        updatedAttachments = Map<String, dynamic>.from(
          currentMessage.attachments!,
        );
        updatedAttachments['is_uploading'] = false;
        updatedAttachments.remove('upload_failed');
      }

      // If the server assigned a new ID, update the message ID
      final effectiveId = payload.newId ?? payload.msgId;

      // Under UUIDv7 the id the client generated is the permanent id — no
      // reconciliation needed. We only clear uploading state here and let
      // the MessageInfoModel rows (delivered/read) drive the tick UI.
      if (!_canSetState) {
        return;
      }

      _safeSetState(() {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          id: effectiveId,
          attachments: updatedAttachments ?? currentMessage.attachments,
          isFailed: !payload.isSent,
        );
      });

      // Save to DB
      try {
        await _messagesRepo.updateMessageFields(
          payload.msgId,
          attachments: updatedAttachments,
        );
      } catch (e) {
        debugPrint('❌ Error updating message in DB: $e');
      }

      // Determine status based on readBy and deliveredTo arrays
      // Only update status if this is a message sent by the current user
      // MessageStatusType? newStatus;
      // if (message.senderId == _currentUserDetails?.id) {
      //   if (payload.readBy != null && payload.readBy!.contains(recipientId)) {
      //     newStatus = MessageStatusType.read;
      //   } else if (payload.deliveredTo != null &&
      //       payload.deliveredTo!.contains(recipientId)) {
      //     newStatus = MessageStatusType.delivered;
      //   } else {
      //     newStatus = MessageStatusType.sent;
      //   }
      // }
    } catch (e) {
      debugPrint('❌ Error processing message_ack: $e');
    }
  }

  void _receiveTyping(TypingPayload payload) {
    if (_isDisposed) {
      return;
    }

    // Receiving a TypingPayload means the sender is typing.
    // The typing indicator auto-hides via a safety timeout.

    // Cancel any existing timeout
    _typingTimeout?.cancel();

    // Update the ValueNotifier directly without setState
    _isOtherTypingNotifier.value = true;

    // Control the typing animation
    _typingAnimationController.repeat(reverse: true);

    // Set a safety timeout to hide typing indicator after x seconds
    _typingTimeout = Timer(const Duration(seconds: 3), () {
      if (_isDisposed) {
        return;
      }
      _isOtherTypingNotifier.value = false;
      _typingAnimationController.stop();
      _typingAnimationController.reset();
    });
  }

  void _handleTyping(String value) async {
    // final wasTyping = _isTyping;
    final isTyping = value.isNotEmpty;

    if (!_canSetState) {
      return;
    }
    // _safeSetState(() {
    //   _isTyping = isTyping;
    // });

    if (isTyping) {
      final now = DateTime.now();

      // Send immediately on first keystroke, or if x seconds have passed since last message
      final shouldSend =
          _lastTypingMessageSent == null ||
          now.difference(_lastTypingMessageSent!).inSeconds >= 2;

      if (shouldSend) {
        // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        final typingPayload = TypingPayload(
          convId: widget.dm.chatId,
          senderId: _currentUserDetails!.id,
        ).toJson();

        final wsmsg = WSMessage(
          type: WSMessageType.conversationTyping,
          payload: typingPayload,
          wsTimestamp: now,
        ).toJson();

        await _transportManager.sendMessage(wsmsg).catchError((e) {
          debugPrint('Error sending conversation:typing message');
          return false;
        });

        // Update last sent time
        _lastTypingMessageSent = now;
        // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      }
    } else {
      // Reset timestamp when user stops typing so next typing session sends immediately
      _lastTypingMessageSent = null;
    }
  }

  void _handleMessagePin(MessagePinPayload payload) async {
    // load pinned message from prefs and then DB
    if (payload.pin) {
      final pinnedMessage = await _messagesRepo.getMessageById(
        payload.messageId,
      );
      if (!_canSetState) {
        return;
      }
      _safeSetState(() {
        _pinnedMessage = pinnedMessage;
      });
    } else {
      if (_canSetState) {
        _safeSetState(() {
          _pinnedMessage = null;
        });
      }
    }
  }

  void _handleConversationJoin(ConvJoinPayload payload) async {
    // Read-receipt state is now sourced from MessageInfoModel streams, so this
    // join callback no longer needs to walk _messages and mutate statuses.
    // Intentionally left as no-op.
  }
}
