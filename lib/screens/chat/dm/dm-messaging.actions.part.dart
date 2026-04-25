part of 'dm-messaging.screen.dart';

extension _DmActions on _InnerChatPageState {
  void _toggleMessageSelection(String messageId) {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
      } else {
        _selectedMessages.add(messageId);
      }
    });
  }

  void _exitSelectionMode() {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _selectedMessages.clear();
    });
  }

  void _enterSelectionMode(String messageId) {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _selectedMessages.add(messageId);
    });
  }

  void _togglePinMessage(MessageModel message) async {
    // Check if this message is currently pinned by comparing IDs
    final messageId = message.id;
    final pinnedMessageId = _pinnedMessage?.id;
    final wasPinned = messageId == pinnedMessageId && _pinnedMessage != null;
    final newPinnedMessageId = wasPinned ? null : message.id;

    // Clear or set pinned message immediately for instant UI feedback
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _pinnedMessage = wasPinned ? null : message;
    });

    await ChatHelpers.togglePinMessage(
      message: message,
      conversationId: widget.dm.chatId,
      currentPinnedMessageId: pinnedMessageId,
      setPinnedMessageId: (value) {
        // This is called inside togglePinMessage's setState, but we already updated above
        // Keep it for consistency
        if (_canSetState) {
          _pinnedMessage = value;
        }
      },
      currentUserId: _currentUserDetails?.id,
      setState: _safeSetState,
    );

    // Update provider state immediately for UI consistency
    ref
        .read(chatProvider.notifier)
        .updatePinnedMessageInState(widget.dm.chatId, newPinnedMessageId);
  }

  void _toggleStarMessage(String messageId) async {
    if (_starEnabled) {
      /* star disabled */
    }
  }

  void _reactToMessage(MessageModel message, String emoji) async {
    if (_currentUserDetails == null) return;

    final msgReactions = _reactionsByMessage[message.id] ?? {};
    final emojiUsers =
        (msgReactions[emoji] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final alreadyReacted = emojiUsers.any(
      (u) => u['user_id']?.toString() == _currentUserDetails!.id,
    );
    final action = alreadyReacted ? 'remove' : 'add';

    // Write to local DB immediately so the Drift stream re-emits
    await _messageStatusRepo.upsertReaction(
      messageId: message.id,
      userId: _currentUserDetails!.id,
      chatId: widget.dm.chatId,
      emoji: action == 'add' ? emoji : null,
    );

    // Fire to backend (which will broadcast to other conversation members)
    try {
      await apiService.chat.reactToMessage(
        messageId: message.id,
        conversationId: widget.dm.chatId,
        emoji: emoji,
        action: action,
        senderName: _currentUserDetails!.name,
      );
    } catch (e) {
      debugPrint('❌ Failed to send reaction: $e');
    }
  }

  void _replyToMessage(MessageModel message) async {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _replyToMessageData = message;
    });
    // Keep keyboard open — re-request focus after the layout settles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_canSetState) _messageFocusNode.requestFocus();
    });
  }

  void _cancelReply() {
    if (!_canSetState) {
      return;
    }
    _safeSetState(() {
      _replyToMessageData = null;
    });
  }

  Future<void> _forwardMessage(MessageModel message) async {
    if (_canSetState) {
      _safeSetState(() {
        _messagesToForward.clear();
        _messagesToForward.add(message.id);
      });
    }
    await _showForwardModal();
  }

  void _deleteMessage(
    String messageId, {
    bool deleteForEveryone = false,
  }) async {
    try {
      if (deleteForEveryone) {
        // Delete for everyone - only own messages
        final message = _messages.firstWhere((m) => m.id == messageId);
        if (message.senderId != _currentUserDetails?.id) {
          Snack.warning('You can only delete your own messages for everyone');
          return;
        }

        // delete from local database
        await _messagesRepo.deleteMessage(messageId);

        // Remove from UI immediately
        if (_canSetState) {
          _safeSetState(() {
            _messages.removeWhere((message) => message.id == messageId);
          });
        }

        // Call API
        final response = (await apiService.chat.deleteMessage([
          messageId,
        ])).toMap();

        if (response['success'] == true) {
          // Update provider
          ref
              .read(chatProvider.notifier)
              .handleMessageDelete(
                DeleteMessagePayload(
                  messageIds: [messageId],
                  convId: widget.dm.chatId,
                  senderId: _currentUserDetails?.id ?? '',
                ),
              )
              .catchError((e) {
                debugPrint('❌ Error deleting messages: $e');
              });

          // Send WebSocket message
          final deleteMessagePayload = DeleteMessagePayload(
            messageIds: [messageId],
            convId: widget.dm.chatId,
            senderId: _currentUserDetails?.id ?? '',
          ).toJson();

          final wsmsg = WSMessage(
            type: WSMessageType.messageDelete,
            payload: deleteMessagePayload,
            wsTimestamp: DateTime.now(),
          ).toJson();

          _transportManager.sendMessage(wsmsg).catchError((e) {
            debugPrint('❌ Error sending message delete: $e');
            return false;
          });
        } else {
          Snack.error(response['message'] ?? 'Failed to delete message');
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      Snack.error('Failed to delete message');
    }
  }

  void _deleteMessageForMe(String messageId) async {
    try {
      // Remove from UI immediately
      if (_canSetState) {
        _safeSetState(() {
          _messages.removeWhere((message) => message.id == messageId);
        });
      }

      // Call API
      final response = (await apiService.chat.deleteMessageForMe(
        messageIds: [messageId],
        conversationId: widget.dm.chatId,
      )).toMap();

      if (response['success'] == true) {
        // delete from local database
        await _messagesRepo.deleteMessage(messageId);
      }
    } catch (e) {
      debugPrint('❌ Error deleting message for me: $e');
      // Restore message on error
      if (_canSetState) {
        final messagesFromLocal = await _messagesRepo.getMessagesByConversation(
          widget.dm.chatId,
          limit: 100,
          offset: 0,
        );
        _safeSetState(() {
          _messages = messagesFromLocal;
          _sortMessagesBySentAt();
        });
      }
      Snack.error('Failed to delete message');
    }
  }

  void _bulkStarMessages() async {
    if (_starEnabled) {
      /* star disabled */
    }
  }

  void _bulkForwardMessages() async {
    await ChatHelpers.bulkForwardMessages(
      selectedMessages: _selectedMessages,
      messagesToForward: _messagesToForward,
      setState: _safeSetState,
      exitSelectionMode: _exitSelectionMode,
      showForwardModal: _showForwardModal,
    );
  }

  void _showMessageActions(MessageModel message, bool isMyMessage) {
    final isPinned = _pinnedMessage?.id == message.id;
    final isStarred = _starredMessages.contains(message.id);

    // Determine which emojis the current user has already reacted with on this message
    final myReactions = <String>[];
    if (_currentUserDetails != null) {
      final msgReactions = _reactionsByMessage[message.id] ?? {};
      for (final entry in msgReactions.entries) {
        final users = (entry.value as List?) ?? [];
        if (users.any(
          (u) => u['user_id']?.toString() == _currentUserDetails!.id,
        )) {
          myReactions.add(entry.key);
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MessageActionSheet(
        message: message,
        isMyMessage: isMyMessage,
        isPinned: isPinned,
        isStarred: isStarred,
        showReadBy: false,
        onReply: () => _replyToMessage(message),
        onPin: () => _togglePinMessage(message),
        onStar: () => _toggleStarMessage(message.id),
        onForward: () => _forwardMessage(message),
        onSelect: () => _enterSelectionMode(message.id),
        onDeleteForMe: () => _deleteMessageForMe(message.id),
        onDeleteForEveryone: isMyMessage
            ? () => _deleteMessage(message.id, deleteForEveryone: true)
            : null,
        onReact: (emoji) => _reactToMessage(message, emoji),
        myReactions: myReactions,
      ),
    );
  }

  Future<void> _showForwardModal() async {
    final dmList = await ConversationRepository().getAllDmsWithRecipientInfo();
    final groupList = await ConversationRepository()
        .getGroupListWithoutMembers();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => ForwardMessageModal(
        messagesToForward: _messagesToForward,
        dmList: dmList,
        groupList: groupList,
        isLoading: _isLoadingConversations,
        onForward: _handleForwardToConversations,
        currentConversationId: widget.dm.chatId,
      ),
    );
  }

  Future<void> _handleForwardToConversations(
    List<String> selectedConversationIds,
  ) async {
    await handleForwardToConversations(
      HandleForwardToConversationsConfig(
        messagesToForward: _messagesToForward,
        selectedConversationIds: selectedConversationIds,
        currentUserId: _currentUserDetails?.id ?? '',
        sourceConversationId: widget.dm.chatId,
        context: context,
        mounted: mounted,
        clearMessagesToForward: (messages) {
          if (_canSetState) {
            _safeSetState(() {
              _messagesToForward.clear();
            });
          }
        },
        showErrorDialog: _showErrorDialog,
      ),
    );
  }

  void _showAttachmentModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => AttachmentActionSheet(
        onCameraTap: () => _handleCameraAttachment(),
        onGalleryTap: () => _handleGalleryAttachment(),
        onDocumentTap: () => _handleDocumentAttachment(),
        onContactTap: () => _handleContactAttachment(),
      ),
    );
  }

  void _handleCameraAttachment() async {
    await handleCameraAttachment(
      imagePicker: _imagePicker,
      context: context,
      onImageSelected: (imageFile, source) async {
        // Open image editor before sending
        final editedFile = await Navigator.of(context).push<File>(
          MaterialPageRoute(
            builder: (context) => ImageEditorScreen(imageFile: imageFile),
          ),
        );

        if (editedFile != null) {
          _sendMediaMessageToServer(editedFile, MessageType.image);
        }
      },
      onError: (message) {
        _showErrorDialog(message);
      },
      onPermissionDenied: (permissionType) {
        openAppSettings();
      },
    );
  }

  void _handleGalleryAttachment() async {
    await handleGalleryAttachment(
      context: context,
      onImageSelected: (imageFile, source) async {
        // Open image editor before sending
        final editedFile = await Navigator.of(context).push<File>(
          MaterialPageRoute(
            builder: (context) => ImageEditorScreen(imageFile: imageFile),
          ),
        );

        if (editedFile != null) {
          _sendMediaMessageToServer(editedFile, MessageType.image);
        }
      },
      onVideoSelected: (videoFile, source) {
        _sendMediaMessageToServer(videoFile, MessageType.video);
      },
      onError: (message) {
        _showErrorDialog(message);
      },
    );
  }

  void _handleDocumentAttachment() async {
    await handleDocumentAttachment(
      context: context,
      onDocumentSelected: (documentFile, fileName, extension) {
        _sendMediaMessageToServer(documentFile, MessageType.document);
      },
      onError: (message) {
        _showErrorDialog(message);
      },
    );
  }

  void _handleContactAttachment() async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactSelectionWidget(
          onContactsSelected: (List<ContactModel> contacts) {
            if (contacts.isEmpty) return;

            // Store contacts in metadata for special rendering
            final contactsMetadata = contacts
                .map(
                  (contact) => {
                    'name': contact.displayName,
                    'displayName': contact.displayName,
                    'firstName': contact.firstName,
                    'lastName': contact.lastName,
                    'phone': contact.phoneNumber,
                    'phoneNumber': contact.phoneNumber,
                  },
                )
                .toList();

            // Also format as text for backward compatibility
            final contactText = contacts
                .map(
                  (contact) => '${contact.displayName}: ${contact.phoneNumber}',
                )
                .join(',\n');

            // Set the formatted text in the message controller
            _messageController.text = contactText;

            // Store metadata before sending
            _pendingContactMetadata = {
              'contacts': contactsMetadata,
              'is_contact_message': true,
            };

            // Send the message
            _sendMessage(MessageType.text);
          },
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
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

  void _openImagePreview(String imageUrl, String? caption) async {
    await openImagePreview(
      context: context,
      imageUrl: imageUrl,
      caption: caption,
      messages: _messages,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      mounted: mounted,
    );
  }

  void _openVideoPreview(
    String videoUrl,
    String? caption,
    String? fileName,
  ) async {
    await openVideoPreview(
      context: context,
      videoUrl: videoUrl,
      caption: caption,
      fileName: fileName,
      messages: _messages,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      mounted: mounted,
      onMessageUpdated: (updatedMessage) {
        final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
        if (index != -1 && _canSetState) {
          _safeSetState(() {
            _messages[index] = updatedMessage;
          });
        }
      },
    );
  }

  void _openDocumentPreview(
    String documentUrl,
    String? fileName,
    String? caption,
    int? fileSize,
  ) {
    openDocumentPreview(
      context: context,
      documentUrl: documentUrl,
      fileName: fileName,
      caption: caption,
      fileSize: fileSize,
    );
  }
}
