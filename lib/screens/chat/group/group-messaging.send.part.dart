part of 'group-messaging.screen.dart';

extension _GroupSend on _InnerGroupChatPageState {
  void _sendMessage(
    MessageType messageType, {
    MediaResponse? mediaResponse,
    String? messageId,
    int? retryCount = 0,
    String? body,
  }) async {
    if (_isRemovedFromGroup) {
      debugPrint('[GROUP] Blocked send — user removed from group');
      return;
    }
    if (mounted) {
      _safeSetState(() {
        _isSendingMessage = true;
      });
    }
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
      await draftNotifier.removeDraft(widget.group.chatId);
    }

    final id =
        messageId ??
        newMessageId();

    // Create optimistic message for immediate display with current UTC time
    final nowUTC = DateTime.now().toUtc();

    // Merge contact metadata into attachments if present (there is no longer
    // a top-level metadata field; we stash pending contact info inside
    // attachments so it survives the round-trip).
    Map<String, dynamic>? combinedAttachments = mediaResponse?.toJson();
    if (!isResend && pendingContactMetadata != null) {
      combinedAttachments = Map<String, dynamic>.from(combinedAttachments ?? {})
        ..addAll(pendingContactMetadata!);
    }

    final newMsg = MessageModel(
      id: id,
      chatId: widget.group.chatId,
      senderId: _currentUserDetails!.id,
      senderName: _currentUserDetails!.name,
      senderProfilePic: _currentUserDetails!.profilePic,
      attachments: combinedAttachments,
      type: messageType,
      body: messageText,
      repliedTo: replyToMessageData?.id,
      sentAt: nowUTC.toIso8601String(),
    );

    if (messageId == null && mediaResponse == null) {
      // storing the message into the local database
      final result = await _messagesRepo.insertMessage(newMsg);
      // retry logic for handling unique constraint violation on message ID
      if (result["success"] == false && result["errorCode"] == 1555) {
        debugPrint("result : $result");
        if (retryCount! > 5) return;
        _sendMessage(
          messageType,
          mediaResponse: mediaResponse,
          retryCount: retryCount + 1,
        );
        return;
      }
    } else if (messageId != null && mediaResponse != null) {
      // This is a media message, so we need to insert it into the DB with the generated ID
      final result = await _messagesRepo.updateMessageFields(
        id,
        attachments: mediaResponse.toJson(),
        isFailed: false,
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
    if (mounted) {
      _safeSetState(() {
        // If optimisticId is provided, replace the existing optimistic message
        // if (optimisticId != null) {
        final index = _messages.indexWhere((msg) => msg.id == id);
        if (index != -1) {
          _messages[index] = newMsg;
          // Only sort if we replaced a message (might have changed position)
          _sortMessagesBySentAt();
        } else {
          // New message - add at end (newest messages are at end in reverse list)
          _messages.add(newMsg);
          // No need to sort - new message is already at the correct end position
        }
        // } else {
        //   // New message - add at end (newest messages are at end in reverse list)
        //   _messages.add(newMsg);
        //   // No need to sort - new message is already at the correct end position
        // }
      });

      animateNewMessage(newMsg.id);
      handleScrollToBottomTap();
    }

    // >>>>>-- sending to ws (fire-and-forget) -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    final messagePayload = ChatMessagePayload(
      id: id,
      convId: widget.group.chatId,
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
        .updateLastMessageOnSendingOwnMessage(
          widget.group.chatId,
          newMsg,
        );

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
          _transportManager.sendMessage(wsmsg).then((sendResult) async {
            if (sendResult == true) {
              await _messageStatusRepo.insertMessageStatusesWithMultipleUserIds(
                messageId: newMsg.id,
                chatId: widget.group.chatId,
                userIds: _conversationMembers
                    .where((member) => member.id != _currentUserDetails?.id)
                    .map((member) => member.id)
                    .toList(),
              );
            } else {
              debugPrint('Failed to send message (offline or error)');
              await _markMessageAsFailed(newMsg.id);
            }
          }).catchError((e) {
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

  /// Scroll to bottom of message list

  Future<void> _sendMediaMessageToServer(
    File mediaFile,
    MessageType messageType, {
    String? existingMessageId,
  }) async {
    final messageId =
        existingMessageId ??
        newMessageId();

    final nowUTC = DateTime.now().toUtc();

    // Build attachments with local_path for UI to display during upload
    final fileName = mediaFile.path.split('/').last;
    final attachments = <String, dynamic>{
      'file_name': fileName,
      'local_path': mediaFile.path, // Required for UI to display local file
      'is_uploading': true,
      'upload_progress': 0,
    };

    final newMsg = MessageModel(
      id: messageId,
      chatId: widget.group.chatId,
      senderId: _currentUserDetails!.id,
      senderName: _currentUserDetails!.name,
      senderProfilePic: _currentUserDetails!.profilePic,
      attachments: attachments,
      localMediaPath: mediaFile.path,
      type: messageType,
      repliedTo: replyToMessageData?.id,
      sentAt: nowUTC.toIso8601String(),
    );

    if (mounted) {
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

    final result = await apiService.chat.sendMediaMessage(
      mediaFile,
      onSendProgress: (sent, total) {
        // Calculate progress percentage
        final progress = total > 0 ? ((sent / total) * 100).round() : 0;

        // Update immediately if progress changed (remove throttling to see all updates)
        if (progress != lastProgressUpdate && mounted) {
          lastProgressUpdate = progress;

          final index = _messages.indexWhere((msg) => msg.id == messageId);

          if (index != -1) {
            final currentMsg = _messages[index];
            final updatedAttachments = Map<String, dynamic>.from(
              currentMsg.attachments ?? {},
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
    );
    if (result.isSuccess && result.data != null) {
      final mediaData = MediaResponse.fromJson(result.data!);
      // return mediaData;

      // Clear upload progress before sending message
      if (mounted) {
        final index = _messages.indexWhere((msg) => msg.id == messageId);

        if (index != -1) {
          final currentMsg = _messages[index];
          final updatedAttachments = Map<String, dynamic>.from(
            currentMsg.attachments ?? {},
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
      if (mounted) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Failed to send media message')),
        // );
      }
    }
  }

  /// Mark a message as failed in both UI and DB

  Future<void> _markMessageAsFailed(String messageId) async {
    if (!mounted) return;

    final index = _messages.indexWhere((msg) => msg.id == messageId);

    if (index == -1) return;

    final failedMsg = _messages[index];
    final updatedAttachments = Map<String, dynamic>.from(
      failedMsg.attachments ?? {},
    );
    updatedAttachments['is_uploading'] = false;
    updatedAttachments['upload_failed'] = true;

    final updatedMessage = failedMsg.copyWith(
      isFailed: true,
      attachments: updatedAttachments,
    );

    // Update in UI
    if (mounted) {
      _safeSetState(() {
        _messages[index] = updatedMessage;
      });
    }

    // Save to DB with failed status
    await _messagesRepo.updateMessageFields(
      messageId,
      isFailed: true,
      attachments: updatedAttachments,
    );
  }

  /// Resend a failed message
  // Future<void> _resendFailedMessage(MessageModel failedMessage) async {
  //   // Find the message index in the UI
  //   final index = _messages.indexWhere(
  //     (msg) =>
  //         msg.id == failedMessage.id ||
  //         msg.optimisticId == failedMessage.optimisticId,
  //   );
  //
  //   // Set uploading state immediately for visual feedback
  //   final uploadingMetadata = Map<String, dynamic>.from(
  //     failedMessage.metadata ?? {},
  //   );
  //   uploadingMetadata.remove('upload_failed');
  //   uploadingMetadata['is_uploading'] = true;
  //   uploadingMetadata['upload_progress'] = 0; // Initialize progress to 0
  //
  //   final uploadingMessage = failedMessage.copyWith(
  //     status: MessageStatusType.sent,
  //     metadata: uploadingMetadata,
  //   );
  //
  //   // Update in UI immediately to show uploading state
  //   if (index != -1 && mounted) {
  //     _safeSetState(() {
  //       _messages[index] = uploadingMessage;
  //     });
  //   }
  //
  //   // Save uploading state to DB
  //   await _messagesRepo.insertMessage(uploadingMessage);
  //
  //   // Handle media messages differently - need to upload first
  //   if (failedMessage.type != MessageType.text) {
  //     try {
  //       // Get the local file path from either localMediaPath or attachments
  //       String? localPath = failedMessage.localMediaPath;
  //       if (localPath == null || localPath.isEmpty) {
  //         localPath = failedMessage.attachments?['local_path'] as String?;
  //       }
  //
  //       if (localPath == null || localPath.isEmpty) {
  //         debugPrint('Error: No local path found for failed media message');
  //         await _markMessageAsFailed(
  //           failedMessage.optimisticId ?? failedMessage.id,
  //         );
  //         return;
  //       }
  //
  //       final mediaFile = File(localPath);
  //       if (!mediaFile.existsSync()) {
  //         debugPrint('Error: Media file not found at path: $localPath');
  //         await _markMessageAsFailed(
  //           failedMessage.optimisticId ?? failedMessage.id,
  //         );
  //         return;
  //       }
  //
  //       // Upload the media to server first
  //       int? lastProgressUpdate = -1;
  //
  //       final response = await _chatsServices.sendMediaMessage(
  //         mediaFile,
  //         onSendProgress: (sent, total) {
  //           // Calculate progress percentage
  //           final progress = total > 0 ? ((sent / total) * 100).round() : 0;
  //
  //           // Update immediately if progress changed
  //           if (progress != lastProgressUpdate && index != -1 && mounted) {
  //             lastProgressUpdate = progress;
  //
  //             final currentMsg = _messages[index];
  //             final updatedMetadata = Map<String, dynamic>.from(
  //               currentMsg.metadata ?? {},
  //             );
  //             updatedMetadata['upload_progress'] = progress;
  //             updatedMetadata['is_uploading'] = true;
  //
  //             final updatedMessage = currentMsg.copyWith(
  //               metadata: updatedMetadata,
  //             );
  //
  //             _safeSetState(() {
  //               _messages[index] = updatedMessage;
  //             });
  //           }
  //         },
  //       );
  //
  //       if (response['success'] == true && response['data'] != null) {
  //         final mediaData = MediaResponse.fromJson(response['data']);
  //
  //         // Update message with the new attachments (server URLs)
  //         final updatedMessage = uploadingMessage.copyWith(
  //           attachments: mediaData.toJson(),
  //         );
  //
  //         // Update in UI
  //         if (index != -1 && mounted) {
  //           _safeSetState(() {
  //             _messages[index] = updatedMessage;
  //           });
  //         }
  //
  //         // Save to DB
  //         await _messagesRepo.insertMessage(updatedMessage);
  //
  //         // Use current time for the resent message
  //         final newSentAt = DateTime.now().toUtc();
  //
  //         // Now send the message with proper MediaResponse
  //         final messagePayload = ChatMessagePayload(
  //           optimisticId: failedMessage.optimisticId ?? failedMessage.id,
  //           convId: failedMessage.conversationId,
  //           senderId: failedMessage.senderId,
  //           senderName: failedMessage.senderName,
  //           attachments: mediaData,
  //           convType: ChatType.group,
  //           msgType: failedMessage.type,
  //           body: failedMessage.body,
  //           replyToMessageId:
  //               failedMessage.metadata?['reply_to']?['message_id'],
  //           sentAt: newSentAt,
  //         );
  //
  //         final wsmsg = WSMessage(
  //           type: WSMessageType.messageNew,
  //           payload: messagePayload,
  //           wsTimestamp: DateTime.now(),
  //         ).toJson();
  //
  //         await _webSocket
  //             .sendMessage(wsmsg)
  //             .then((_) {
  //               // Keep the message in the list with loading state
  //               // The server will send back the message via WebSocket and we'll update it
  //               // Save success state to DB (server will send back the actual message)
  //               final successMetadata = Map<String, dynamic>.from(
  //                 updatedMessage.metadata ?? {},
  //               );
  //               successMetadata['is_uploading'] =
  //                   true; // Keep loading until server responds
  //               successMetadata.remove('upload_failed');
  //               final successMessage = updatedMessage.copyWith(
  //                 sentAt: newSentAt.toIso8601String(),
  //                 metadata: successMetadata,
  //               );
  //               _messagesRepo.insertMessage(successMessage);
  //             })
  //             .catchError((e) async {
  //               debugPrint('Error resending media message: $e');
  //               // Mark as failed again
  //               await _markMessageAsFailed(
  //                 failedMessage.optimisticId ?? failedMessage.id,
  //               );
  //             });
  //       } else {
  //         debugPrint('Error: Failed to upload media for resend');
  //         await _markMessageAsFailed(
  //           failedMessage.optimisticId ?? failedMessage.id,
  //         );
  //       }
  //     } catch (e) {
  //       debugPrint('Error resending media message: $e');
  //       // Mark as failed again
  //       await _markMessageAsFailed(
  //         failedMessage.optimisticId ?? failedMessage.id,
  //       );
  //     }
  //     return;
  //   }
  //
  //   // Handle text messages
  //   try {
  //     // Use current time for the resent message
  //     final newSentAt = DateTime.now().toUtc();
  //
  //     final messagePayload = ChatMessagePayload(
  //       optimisticId: failedMessage.optimisticId ?? failedMessage.id,
  //       convId: failedMessage.conversationId,
  //       senderId: failedMessage.senderId,
  //       senderName: failedMessage.senderName,
  //       attachments: failedMessage.attachments,
  //       convType: ChatType.group,
  //       msgType: failedMessage.type,
  //       body: failedMessage.body,
  //       replyToMessageId: failedMessage.metadata?['reply_to']?['message_id'],
  //       sentAt: newSentAt,
  //     );
  //
  //     final wsmsg = WSMessage(
  //       type: WSMessageType.messageNew,
  //       payload: messagePayload,
  //       wsTimestamp: DateTime.now(),
  //     ).toJson();
  //
  //     await _webSocket
  //         .sendMessage(wsmsg)
  //         .then((_) {
  //           // Keep the message in the list with loading state
  //           // The server will send back the message via WebSocket and we'll update it
  //           // Save success state to DB (server will send back the actual message)
  //           final successMetadata = Map<String, dynamic>.from(
  //             uploadingMessage.metadata ?? {},
  //           );
  //           successMetadata['is_uploading'] =
  //               true; // Keep loading until server responds
  //           successMetadata.remove(
  //             'upload_failed',
  //           ); // Explicitly remove upload_failed
  //           final successMessage = uploadingMessage.copyWith(
  //             sentAt: newSentAt.toIso8601String(),
  //             metadata: successMetadata,
  //           );
  //           _messagesRepo.insertMessage(successMessage);
  //         })
  //         .catchError((e) async {
  //           debugPrint('Error resending message: $e');
  //           // Mark as failed again
  //           await _markMessageAsFailed(
  //             failedMessage.optimisticId ?? failedMessage.id,
  //           );
  //         });
  //   } catch (e) {
  //     debugPrint('Error resending message: $e');
  //     // Mark as failed again
  //     await _markMessageAsFailed(
  //       failedMessage.optimisticId ?? failedMessage.id,
  //     );
  //   }
  // }

  /// Check if a specific message is currently being resent

  bool _isResendingFailedMessage(String messageId) {
    return _resendingFailedMessages[messageId] == true;
  }

  /// Resend all failed messages when connection is restored

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

      // Check if message is failed
      if (!message.isFailed) {
        debugPrint('Message is not in failed status');
        return;
      }

      // Preserve reply target if the failed message was a reply
      MessageModel? originalReplyToMessageData = replyToMessageData;
      if (message.repliedTo != null) {
        final replyToMessage = await _messagesRepo.getMessageById(
          message.repliedTo!,
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
      if (mounted) {
        _safeSetState(() {
          _resendingFailedMessages.remove(messageId);
        });
      } else {
        _resendingFailedMessages.remove(messageId);
      }
    }
  }

  /// Send message with immediate display (optimistic UI)

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

  /// Resend a failed message


  // // Media sending methods
  // void _sendImageMessage(
  //   File imageFile,
  //   String source, {
  //   MessageModel? failedMessage,
  // }) async {
  //   await sendImageMessage(
  //     SendMediaMessageConfig(
  //       mediaFile: imageFile,
  //       conversationId: widget.group.chatId,
  //       currentUserId: _currentUserId,
  //       optimisticMessageId: _optimisticMessageId,
  //       replyToMessage: replyToMessageData,
  //       replyToMessageId: replyToMessageData?.id,
  //       failedMessage: failedMessage,
  //       messageType: 'image',
  //       messages: _messages,
  //       optimisticMessageIds: _optimisticMessageIds,
  //       conversationMeta: _conversationMeta,
  //       messagesRepo: _messagesRepo,
  //       chatsServices: _chatsServices,
  //       websocketService: _websocketService,
  //       mounted: () => mounted,
  //       setState: _safeSetState,
  //       handleMediaUploadFailure: _handleMediaUploadFailure,
  //       animateNewMessage: animateNewMessage,
  //       scrollToBottom: _scrollToBottom,
  //       cancelReply: cancelReply,
  //       isReplying: _isReplying,
  //     ),
  //   );

  //   // Only decrement optimistic ID if this was a new message (not a retry)
  //   if (failedMessage == null) {
  //     _optimisticMessageId--;
  //   }
  // }

  // void _sendVideoMessage(
  //   File videoFile,
  //   String source, {
  //   MessageModel? failedMessage,
  // }) async {
  //   await sendVideoMessage(
  //     SendMediaMessageConfig(
  //       mediaFile: videoFile,
  //       conversationId: widget.group.chatId,
  //       currentUserId: _currentUserId,
  //       optimisticMessageId: _optimisticMessageId,
  //       replyToMessage: replyToMessageData,
  //       replyToMessageId: replyToMessageData?.id,
  //       failedMessage: failedMessage,
  //       messageType: 'video',
  //       messages: _messages,
  //       optimisticMessageIds: _optimisticMessageIds,
  //       conversationMeta: _conversationMeta,
  //       messagesRepo: _messagesRepo,
  //       chatsServices: _chatsServices,
  //       websocketService: _websocketService,
  //       mounted: () => mounted,
  //       setState: _safeSetState,
  //       handleMediaUploadFailure: _handleMediaUploadFailure,
  //       animateNewMessage: animateNewMessage,
  //       scrollToBottom: _scrollToBottom,
  //       cancelReply: cancelReply,
  //       isReplying: _isReplying,
  //     ),
  //   );

  //   // Only decrement optimistic ID if this was a new message (not a retry)
  //   if (failedMessage == null) {
  //     _optimisticMessageId--;
  //   }
  // }

  // void _sendDocumentMessage(
  //   File documentFile,
  //   String fileName,
  //   String extension, {
  //   MessageModel? failedMessage,
  // }) async {
  //   await sendDocumentMessage(
  //     SendMediaMessageConfig(
  //       mediaFile: documentFile,
  //       conversationId: widget.group.chatId,
  //       currentUserId: _currentUserId,
  //       optimisticMessageId: _optimisticMessageId,
  //       replyToMessage: replyToMessageData,
  //       replyToMessageId: replyToMessageData?.id,
  //       failedMessage: failedMessage,
  //       messageType: 'document',
  //       fileName: fileName,
  //       extension: extension,
  //       messages: _messages,
  //       optimisticMessageIds: _optimisticMessageIds,
  //       conversationMeta: _conversationMeta,
  //       messagesRepo: _messagesRepo,
  //       chatsServices: _chatsServices,
  //       websocketService: _websocketService,
  //       mounted: () => mounted,
  //       setState: _safeSetState,
  //       handleMediaUploadFailure: _handleMediaUploadFailure,
  //       animateNewMessage: animateNewMessage,
  //       scrollToBottom: _scrollToBottom,
  //       cancelReply: cancelReply,
  //       isReplying: _isReplying,
  //     ),
  //   );

  //   // Only decrement optimistic ID if this was a new message (not a retry)
  //   if (failedMessage == null) {
  //     _optimisticMessageId--;
  //   }
  // }

  // Voice recording methods moved to ChatVoiceRecordingMixin.
}
