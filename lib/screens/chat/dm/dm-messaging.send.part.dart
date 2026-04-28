part of 'dm-messaging.screen.dart';

extension _DmSend on _InnerChatPageState {
  void _sendMessage(
    MessageType messageType, {
    MediaResponse? mediaResponse,
    String? messageId,
    int? retryCount = 0,
    String? body,
  }) async {
    if (mounted) {
      _safeSetState(() {
        _isSendingMessage = true;
      });
    }
    // grab the text from the text input controller or use provided body
    String messageText = '';
    if (messageType == MessageType.text ||
        messageType == MessageType.contact) {
      messageText = body ?? _messageController.text.trim();
      if (messageText.isEmpty) return;
    }

    // Check if this is a resend (body is provided)
    final isResend = body != null;

    // Clear draft when message is grabbed out of the text input for sending
    // Skip if resending (body is provided)
    if (!isResend) {
      final draftNotifier = ref.read(draftMessagesProvider.notifier);
      await draftNotifier.removeDraft(widget.dm.chatId);
    }

    // generate a UUIDv7 message ID (end-to-end, never rewritten)
    final id = messageId ?? newMessageId();

    // Create message for immediate display with current UTC time
    final nowUTC = DateTime.now().toUtc();

    // Merge contact metadata into attachments if present (a contact message
    // carries the picked contacts in attachments alongside any media payload).
    Map<String, dynamic>? combinedAttachments = mediaResponse?.toJson();
    if (!isResend && pendingContactMetadata != null) {
      combinedAttachments = Map<String, dynamic>.from(combinedAttachments ?? {})
        ..addAll(pendingContactMetadata!);
    }

    final newMsg = MessageModel(
      id: id,
      chatId: widget.dm.chatId,
      senderId: _currentUserDetails!.id,
      senderName: _currentUserDetails!.name,
      senderProfilePic: _currentUserDetails!.profilePic,
      repliedTo: replyToMessageData?.id,
      type: messageType,
      body: messageText,
      attachments: combinedAttachments,
      sentAt: nowUTC.toIso8601String(),
    );

    if (messageId == null && mediaResponse == null) {
      // storing the message into the local database
      await _messagesRepo.insertMessage(newMsg);
    } else if (messageId != null && mediaResponse != null) {
      // This is a media message, so we need to update the DB row with media attachments
      final result = await _messagesRepo.updateMessageFields(
        id,
        attachments: mediaResponse.toJson(),
      );
      if (result.isError) {
        debugPrint(
          "Failed to insert media message into local DB errorCode: ${result.errorCode}",
        );
        return;
      }
    }

    // Clear input and reply state immediately for better UX
    // Skip if resending (body is provided)
    if (!isResend) {
      _messageController.clear();
      // Clear pending contact metadata after using it
      pendingContactMetadata = null;
    }

    // Add message to UI immediately with animation
    if (_canSetState) {
      _safeSetState(() {
        final index = _messages.indexWhere((msg) => msg.id == id);
        if (index != -1) {
          _messages[index] = newMsg;
        } else {
          _messages.add(newMsg);
        }
        _sortMessagesBySentAt();
      });

      animateNewMessage(newMsg.id);
      // scroll to bottom when a new message is sent
      handleScrollToBottomTap();
    }

    // >>>>>-- sending to ws (fire-and-forget) -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    final messagePayload = ChatMessagePayload(
      id: id,
      convId: widget.dm.chatId,
      senderId: _currentUserDetails!.id,
      attachments: combinedAttachments,
      msgType: messageType,
      body: messageText,
      repliedTo: replyToMessageData?.id,
      sentAt: nowUTC,
    );

    final wsmsg = WSMessage(
      type: WSMessageType.messageNew,
      payload: messagePayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    // updating the last message on sending own message
    ref
        .read(chatProvider.notifier)
        .updateLastMessageOnSendingOwnMessage(widget.dm.chatId, newMsg);

    // remove the reply container if any
    cancelReply();

    // Fire-and-forget: send via transport without blocking UI.
    // The MessageSentAckPayload handler marks as "sent" on success or "failed" on failure.
    try {
      // Synchronous check: if transport is not connected, mark failed immediately
      if (!_transportManager.isConnected) {
        debugPrint('Transport not connected, marking message as failed');
        _markMessageAsFailed(newMsg.id);
      } else {
        unawaited(
          _transportManager
              .sendMessage(wsmsg)
              .then((sendResult) async {
                if (sendResult == true) {
                  await _messageStatusRepo
                      .insertMessageStatusesWithMultipleUserIds(
                        messageId: newMsg.id,
                        chatId: widget.dm.chatId,
                        userIds: <String>[widget.dm.recipientId],
                      );
                } else {
                  debugPrint('marking message as failed');
                  await _markMessageAsFailed(newMsg.id);
                }
              })
              .catchError((e) {
                debugPrint('Error sending message: $e');
                _markMessageAsFailed(newMsg.id);
              }),
        );
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      _markMessageAsFailed(newMsg.id);
    }
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

    if (mounted) {
      _safeSetState(() {
        _isSendingMessage = false;
      });
    }
  }

  Future<void> _sendMediaMessageToServer(
    File mediaFile,
    MessageType messageType, {
    String? existingMessageId,
  }) async {
    final messageId = existingMessageId ?? newMessageId();
    final nowUTC = DateTime.now().toUtc();

    // Build attachments with local_path for UI to display during upload and
    // upload-progress flags (metadata field no longer exists on MessageModel).
    final fileName = mediaFile.path.split('/').last;
    final attachments = <String, dynamic>{
      'file_name': fileName,
      'local_path': mediaFile.path, // Required for UI to display local file
      'is_uploading': true,
      'upload_progress': 0,
    };

    final newMsg = MessageModel(
      id: messageId,
      chatId: widget.dm.chatId,
      senderId: _currentUserDetails!.id,
      senderName: _currentUserDetails!.name,
      senderProfilePic: _currentUserDetails!.profilePic,
      repliedTo: replyToMessageData?.id,
      attachments: attachments,
      type: messageType,
      sentAt: nowUTC.toIso8601String(),
    );

    if (_canSetState) {
      // If resending, update existing message; otherwise add new one
      if (existingMessageId != null) {
        final index = _messages.indexWhere((msg) => msg.id == messageId);
        if (index != -1) {
          _safeSetState(() {
            _messages[index] = newMsg;
            _sortMessagesBySentAt();
          });
          animateNewMessage(newMsg.id);
          handleScrollToBottomTap();
        }
        // Also update in DB
      } else {
        _safeSetState(() {
          _messages.add(newMsg);
          _sortMessagesBySentAt();
        });

        animateNewMessage(newMsg.id);
        handleScrollToBottomTap();

        // immediately insert message in the localDB for future reference
        await _messagesRepo.insertMessage(newMsg);
      }
    }

    int? lastProgressUpdate = -1;

    final response = (await apiService.chat.sendMediaMessage(
      mediaFile,
      onSendProgress: (sent, total) {
        // Calculate progress percentage
        final progress = total > 0 ? ((sent / total) * 100).round() : 0;

        // Update immediately if progress changed (remove throttling to see all updates)
        if (progress != lastProgressUpdate && _canSetState) {
          lastProgressUpdate = progress;

          final index = _messages.indexWhere((msg) => msg.id == messageId);

          if (index != -1) {
            final currentMsg = _messages[index];
            final updatedAttachments = Map<String, dynamic>.from(
              (currentMsg.attachments as Map<String, dynamic>?) ?? {},
            );
            updatedAttachments['upload_progress'] = progress;
            updatedAttachments['is_uploading'] = true;

            final updatedMessage = currentMsg.copyWith(
              attachments: updatedAttachments,
            );

            _safeSetState(() {
              _messages[index] = updatedMessage;
            });
          }
        }
      },
    )).toMap();

    if (response['success'] == true && response['data'] != null) {
      final mediaData = MediaResponse.fromJson(response['data']);

      // Clear upload progress before sending message
      if (_canSetState) {
        final index = _messages.indexWhere((msg) => msg.id == messageId);

        if (index != -1) {
          final currentMsg = _messages[index];
          final updatedAttachments = Map<String, dynamic>.from(
            (currentMsg.attachments as Map<String, dynamic>?) ?? {},
          );
          updatedAttachments.remove('is_uploading');
          updatedAttachments.remove('upload_progress');

          final updatedMessage = currentMsg.copyWith(
            attachments: updatedAttachments,
          );

          _safeSetState(() {
            _messages[index] = updatedMessage;
          });
        }
      }

      _sendMessage(messageType, mediaResponse: mediaData, messageId: messageId);

      debugPrint('Media data: $mediaData, messageType: $messageType');
    } else {
      // Update message to show upload failed state and save to DB
      await _markMessageAsFailed(messageId);
      if (_canSetState) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Failed to send media message')),
        // );
      }
    }
  }

  Future<void> _markMessageAsFailed(String messageId) async {
    if (!_canSetState) return;

    final index = _messages.indexWhere((msg) => msg.id == messageId);

    if (index == -1) return;

    final failedMsg = _messages[index];
    // Reflect upload-failed state in the attachments map (there is no longer a
    // metadata field on MessageModel).
    Map<String, dynamic>? updatedAttachments;
    if (failedMsg.attachments is Map<String, dynamic>) {
      updatedAttachments = Map<String, dynamic>.from(failedMsg.attachments!);
      updatedAttachments['is_uploading'] = false;
      updatedAttachments['upload_failed'] = true;
    }

    final updatedMessage = failedMsg.copyWith(
      isFailed: true,
      attachments: updatedAttachments ?? failedMsg.attachments,
    );

    // Update in UI
    _safeSetState(() {
      _messages[index] = updatedMessage;
    });

    // Save to DB with failed status
    await _messagesRepo.updateMessageFields(
      messageId,
      isFailed: true,
      attachments: updatedAttachments,
    );

    // print("🎐 🎐 🎐  set states to failed in UI state and DB");
  }

  bool _isResendingFailedMessage(String messageId) {
    return _resendingFailedMessages[messageId] == true;
  }

  Future<void> resendFailedMessage(String messageId) async {
    // Skip if already resending this message
    if (_isResendingFailedMessage(messageId)) return;

    try {
      // Mark as resending in the map and update UI
      _safeSetState(() {
        _resendingFailedMessages[messageId] = true;
      });

      // Fetch the message from local DB
      final message = await _messagesRepo.getMessageById(messageId);

      if (message == null) {
        debugPrint('Message not found: $messageId');
        return;
      }

      // Check if message is marked as failed
      if (!message.isFailed) {
        debugPrint('Message is not in failed status');
        return;
      }

      // Preserve reply target if the failed message was a reply
      MessageModel? originalReplyToMessageData = replyToMessageData;
      final replyToMessageId = message.repliedTo;
      if (replyToMessageId != null) {
        final replyToMessage = await _messagesRepo.getMessageById(
          replyToMessageId,
        );
        if (replyToMessage != null) {
          replyToMessageData = replyToMessage;
        }
      }

      try {
        // Check if it's a media message (image, video, audio, document)
        final isMediaMessage =
            message.type == MessageType.image ||
            message.type == MessageType.video ||
            message.type == MessageType.audio ||
            message.type == MessageType.document;

        if (isMediaMessage) {
          // Check if attachments contain local_path
          final localPath = message.attachments?['local_path'] as String?;

          if (localPath == null || localPath.isEmpty) {
            debugPrint(
              'No local_path found in attachments for failed media message',
            );
            return;
          }

          // Check if file exists
          final mediaFile = File(localPath);
          if (!mediaFile.existsSync()) {
            debugPrint('Media file not found at path: $localPath');
            return;
          }

          // Resend via _sendMediaMessageToServer with existing messageId
          await _sendMediaMessageToServer(
            mediaFile,
            message.type,
            existingMessageId: messageId,
          );
        } else {
          // For text and other non-media messages, resend directly via _sendMessage
          _sendMessage(message.type, messageId: messageId, body: message.body);
        }
      } finally {
        // Restore original reply message data
        replyToMessageData = originalReplyToMessageData;
      }
    } catch (e) {
      debugPrint('Error resending failed message: $e');
    } finally {
      // Clear resending state for this message
      if (_canSetState) {
        _safeSetState(() {
          _resendingFailedMessages.remove(messageId);
        });
      } else {
        _resendingFailedMessages.remove(messageId);
      }
    }
  }

  Future<void> _resendAllFailedMessages() async {
    // Collect failed messages from the in-memory list (already loaded)
    final failedMessages = _messages
        .where(
          (msg) =>
              msg.isFailed &&
              msg.senderId == _currentUserDetails?.id &&
              !_isResendingFailedMessage(msg.id),
        )
        .toList();

    if (failedMessages.isEmpty) return;

    debugPrint(
      '[RESEND] Auto-resending ${failedMessages.length} failed messages',
    );

    // Resend sequentially to avoid overwhelming the server
    for (final msg in failedMessages) {
      if (!mounted) break;
      await resendFailedMessage(msg.id);
    }
  }

}
