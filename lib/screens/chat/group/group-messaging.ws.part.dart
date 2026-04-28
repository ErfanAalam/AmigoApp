part of 'group-messaging.screen.dart';

extension _GroupWsHandlers on _InnerGroupChatPageState {
  void _setupWebSocketListener() {
    final convId = widget.group.chatId;

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

    // Listen to transport connection state changes:
    // 1. Re-send conversation:join so server knows we're still active
    // 2. Auto-resend any failed messages
    _transportConnectionSubscription = _transportManager.connectionStateStream
        .listen((state) {
          if (state == TransportConnectionState.connected) {
            debugPrint(
              '[GROUP] 🎐🎐🎐 Transport reconnected, re-joining conversation and resending failed messages',
            );
            _sendConversationJoin();
            _resendAllFailedMessages();
          }
        });
  }

  /// Send conversation:join to server (idempotent — safe to call multiple times).
  /// If offline, stores the event in MissedWsMessages for replay on reconnect.

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
      convId: widget.group.chatId,
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
      MissedWsMessagesRepository()
          .storeEvent('conversation:join', joinConvPayload.toJson());
    }
  }

  /// Handle incoming message from WebSocket

  void _handleMessageNew(ChatMessagePayload payload) async {
    try {
      final senderDetails = await UserInfoCache.instance.getUser(payload.senderId);

      // create message model from payload
      final message = MessageModel(
        id: payload.id,
        chatId: payload.convId,
        senderId: payload.senderId,
        attachments: payload.attachments is Map<String, dynamic>
            ? payload.attachments as Map<String, dynamic>
            : null,
        body: payload.body,
        senderName: senderDetails?.name ?? '',
        senderProfilePic: senderDetails?.profilePic ?? '',
        repliedTo: payload.repliedTo,
        type: payload.msgType,
        sentAt: payload.sentAt.toIso8601String(),
      );

      // If this is a message from the current user, check if we already have
      // the optimistic row (same UUIDv7 id) and update it instead of duplicating.
      int existingIndex = -1;
      if (payload.senderId == _currentUserDetails?.id) {
        existingIndex = _messages.indexWhere(
          (msg) => (msg.id == payload.id && msg.senderId == payload.senderId),
        );

        if (existingIndex != -1) {
          // Update existing message with server response
          if (mounted) {
            _safeSetState(() {
              final updatedMessage = message.copyWith(
                id: _messages[existingIndex].id,
              );
              _messages[existingIndex] = updatedMessage;
              _sortMessagesBySentAt();
            });
          }

          // Save to DB
          await _messagesRepo.insertMessage(message);
          return;
        }
      }

      // Check if message already exists (avoid duplicates)
      int duplicateIndex = existingIndex;
      if (duplicateIndex == -1) {
        duplicateIndex = _messages.indexWhere((msg) => msg.id == message.id);
      }

      // Add message to UI immediately with animation
      if (mounted) {
        _safeSetState(() {
          if (duplicateIndex == -1) {
            // New message - check if it should be at the end
            if (_messages.isEmpty) {
              _messages.add(message);
            } else {
              // Compare with last message to see if this is newer
              final lastMessage = _messages.last;
              try {
                final lastTime = DateTime.parse(lastMessage.sentAt);
                final newTime = DateTime.parse(message.sentAt);
                if (newTime.isAfter(lastTime) ||
                    newTime.isAtSameMomentAs(lastTime)) {
                  // New message is newer or same time - add at end (no sort needed)
                  _messages.add(message);
                } else {
                  // Message is older - add and sort
                  _messages.add(message);
                  _sortMessagesBySentAt();
                }
              } catch (e) {
                // If parsing fails, add at end and sort to be safe
                _messages.add(message);
                _sortMessagesBySentAt();
              }
            }
          } else {
            // Message already exists - update it in place
            _messages[duplicateIndex] = message;
          }
        });

        animateNewMessage(message.id);
      }
    } catch (e) {
      debugPrint('❌ Error processing incoming message: $e');
    }
  }

  void _handleSentAck(MessageSentAckPayload payload) async {
    try {
      // Find the message with matching UUIDv7 id — no reconciliation needed.
      final messageIndex = _messages.indexWhere((msg) => msg.id == payload.msgId);

      if (messageIndex == -1) {
        debugPrint('⚠️ Message with id ${payload.msgId} not found in _messages');
        return;
      }

      final currentMessage = _messages[messageIndex];

      // If the server assigned a new ID, use it
      final effectiveId = payload.newId ?? payload.msgId;

      // Clear isFailed on successful ack.
      final updatedMessage = currentMessage.copyWith(
        id: effectiveId,
        isFailed: !payload.isSent,
      );

      // Update in UI and DB
      if (mounted) {
        _safeSetState(() {
          _messages[messageIndex] = updatedMessage;
        });
      }

      try {
        await _messagesRepo.updateMessageFields(
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

  void _receiveTyping(TypingPayload payload) {
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
      if (mounted) {
        _isOtherTypingNotifier.value = false;
        _typingAnimationController.stop();
        _typingAnimationController.reset();
      }
    });
  }

  /// Handle incoming message pin from WebSocket

  void _handleTyping(String value) async {
    // final wasTyping = _isTyping;
    final isTyping = value.isNotEmpty;

    _safeSetState(() {
      _isTyping = isTyping;
    });

    if (isTyping) {
      final now = DateTime.now();

      // Send immediately on first keystroke, or if 2 seconds have passed since last message
      final shouldSend =
          _lastTypingMessageSent == null ||
          now.difference(_lastTypingMessageSent!).inSeconds >= 2;

      if (shouldSend) {
        // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
        final typingPayload = TypingPayload(
          convId: widget.group.chatId,
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
      _safeSetState(() {
        _pinnedMessage = pinnedMessage;
      });
    } else {
      _safeSetState(() {
        _pinnedMessage = null;
      });
    }
  }

  /// Handle message delete event from WebSocket
  // void _handleMessageDelete(Map<String, dynamic> message) async {
  //   await handleMessageDelete(
  //     HandleMessageDeleteConfig(
  //       message: message,
  //       mounted: () => mounted,
  //       setState: _safeSetState,
  //       messages: _messages,
  //       conversationId: widget.group.chatId,
  //       messagesRepo: _messagesRepo,
  //     ),
  //   );
  // }

  void _handleMessageDelete(DeleteMessagePayload payload) async {
    // find the message in _messages and set isDeleted to true
    for (final msgId in payload.messageIds) {
      final messageIndex = _messages.indexWhere((msg) => msg.id == msgId);
      if (messageIndex != -1) {
        _messages.removeAt(messageIndex);
      }
    }
    // update UI
    if (mounted) {
      _safeSetState(() {});
    }

    // delete messages from local DB
    // await _messagesRepo.deleteMessages(payload.messageIds);
  }

  // /// Send group message with immediate display (optimistic UI)
  // void _sendMessage(
  //   MessageType messageType, {
  //   MediaResponse? mediaResponse,
  // }) async {
  //   final messageText = _messageController.text.trim();
  //   if (messageText.isEmpty) return;

  //   // Store reply message reference
  //   final replyMessage = _replyToMessageData;
  //   final replyMessageId = _replyToMessageData?.id;

  //   // Clear input and reply state immediately for better UX
  //   _messageController.clear();
  //   _cancelReply();

  //   // Clear draft when message is sent
  //   final draftNotifier = ref.read(draftMessagesProvider.notifier);
  //   await draftNotifier.removeDraft(widget.group.chatId);

  //   // Create optimistic message for immediate display with current UTC time
  //   final nowUTC = DateTime.now().toUtc();
  //   final optimisticMessage = MessageModel(
  //     id: _optimisticMessageId, // Use negative ID for optimistic messages
  //     body: messageText,
  //     type: 'text',
  //     senderId: _currentUserId ?? 0,
  //     conversationId: widget.group.chatId,
  //     createdAt: nowUTC
  //         .toIso8601String(), // Store as UTC, convert to IST when displaying
  //     deleted: false,
  //     senderName: 'You', // Current user name
  //     senderProfilePic: null,
  //     replyToMessage: replyMessage,
  //     replyToMessageId: replyMessageId,
  //   );

  //   // Track this as an optimistic message
  //   _optimisticMessageIds.add(_optimisticMessageId);

  //   // Add message to UI immediately with animation
  //   if (mounted) {
  //     _safeSetState(() {
  //       _messages.add(optimisticMessage);
  //       // Update sticky date separator for new messages
  //       _currentStickyDate = ChatHelpers.getMessageDateString(
  //         optimisticMessage.createdAt,
  //       );
  //       _showStickyDate = true;
  //     });

  //     animateNewMessage(optimisticMessage.id);
  //     _scrollToBottom();
  //   }

  //   // Store message immediately in cache (optimistic storage)
  //   _storeMessageAsync(optimisticMessage);

  //   final prefs = await SharedPreferences.getInstance();
  //   final currentUserName = prefs.getString('current_user_name');
  //   try {
  //     // Check if this is a reply message
  //     if (replyMessageId != null) {
  //       debugPrint('🔄 Sending group reply message via WebSocket');
  //       // Send reply message via WebSocket
  //       await _websocketService.sendMessage({
  //         'type': 'message_reply',
  //         'data': {
  //           'new_message': messageText,
  //           'optimistic_id': _optimisticMessageId,
  //         },
  //         'conversation_id': widget.group.chatId,
  //         'message_ids': [
  //           replyMessageId,
  //         ], // Array of message IDs being replied to
  //       });
  //     } else {
  //       // Send regular message
  //       final messageData = {
  //         'type': 'text',
  //         'body': messageText,
  //         'optimistic_id': _optimisticMessageId,
  //       };

  //       await _websocketService.sendMessage({
  //         'type': 'message',
  //         'data': messageData,
  //         'conversation_id': widget.group.chatId,
  //         'sender_name': currentUserName,
  //       });
  //     }

  //     _optimisticMessageId--;
  //   } catch (e) {
  //     debugPrint('❌ Error sending group message: $e');
  //     _retryMessage(optimisticMessage.id);
  //     // Handle send failure - mark message as failed
  //     // _handleMessageSendFailure(optimisticMessage.id, e.toString());
  //   }
  // }
}
