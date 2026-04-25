part of 'group-messaging.screen.dart';

extension _GroupActions on _InnerGroupChatPageState {
  void _replyToMessage(MessageModel message) {
    _safeSetState(() {
      _replyToMessageData = message;
    });
    // Keep keyboard open — re-request focus after the layout settles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _messageFocusNode.requestFocus();
    });
  }

  void _openGroupInfo() async {
    final result = await Navigator.push(
      context,
      // MaterialPageRoute(
      //   builder: (context) => GroupInfoPage(group: widget.group),
      // ),
      SlideRightRoute(page: GroupInfoPage(group: widget.group)),
    );

    // Check if the group was deleted
    if (result is Map && result['action'] == 'deleted') {
      // Group was deleted, navigate back to groups page with the same result
      if (mounted) {
        Navigator.pop(context, {'action': 'deleted'});
      }
    }
  }

  /// Toggle search mode

  void _toggleMessageSelection(String messageId) {
    _safeSetState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
      } else {
        _selectedMessages.add(messageId);
      }
    });
  }

  /// Build selection mode actions with conditional delete button

  void _exitSelectionMode() {
    _safeSetState(() {
      _selectedMessages.clear();
    });
  }

  void _enterSelectionMode(String messageId) {
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
    _safeSetState(() {
      _pinnedMessage = wasPinned ? null : message;
    });

    await ChatHelpers.togglePinMessage(
      message: message,
      conversationId: widget.group.chatId,
      currentPinnedMessageId: pinnedMessageId,
      setPinnedMessageId: (value) {
        // This is called inside togglePinMessage's setState, but we already updated above
        // Keep it for consistency
        _pinnedMessage = value;
      },
      currentUserId: _currentUserDetails?.id,
      setState: _safeSetState,
    );

    // Update provider state immediately for UI consistency
    ref
        .read(chatProvider.notifier)
        .updatePinnedMessageInState(
          widget.group.chatId,
          newPinnedMessageId,
        );
  }

  // Starring is temporarily disabled during the UUIDv7 migration.
  static const bool _starEnabled = false;

  void _toggleStarMessage(String messageId) async {
    if (_starEnabled) {
      /* star disabled */
    }
  }

  /// React to a message with an emoji (toggle: add if not reacted, remove if already reacted)

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

    await _messageStatusRepo.upsertReaction(
      messageId: message.id,
      userId: _currentUserDetails!.id,
      chatId: widget.group.chatId,
      emoji: action == 'add' ? emoji : null,
    );

    try {
      await apiService.chat.reactToMessage(
        messageId: message.id,
        conversationId: widget.group.chatId,
        emoji: emoji,
        action: action,
        senderName: _currentUserDetails!.name,
      );
    } catch (e) {
      debugPrint('❌ Failed to send reaction: $e');
    }
  }

  void _bulkDeleteMessages() async {
    final selectedIds = _selectedMessages.toList();
    final result = await apiService.chat.deleteMessage(
      selectedIds,
      isAdminOrStaff: _isAdminOrStaff,
    );

    if (result.isSuccess) {
      _safeSetState(() {
        _messages.removeWhere(
          (message) => _selectedMessages.contains(message.id),
        );
      });

      ref
          .read(chatProvider.notifier)
          .handleMessageDelete(
            DeleteMessagePayload(
              messageIds: selectedIds,
              convId: widget.group.chatId,
              senderId: _currentUserDetails?.id ?? '',
            ),
          )
          .catchError((e) {
            debugPrint('❌ Error deleting messages: $e');
            return;
          });

      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      final deleteMessagePayload = DeleteMessagePayload(
        messageIds: selectedIds,
        convId: widget.group.chatId,
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
      // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
      _exitSelectionMode();
    }
  }

  /// Scroll to a specific message (reply-tap or pinned message tap)

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
        currentConversationId: widget.group.chatId,
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
        sourceConversationId: widget.group.chatId,
        context: context,
        mounted: mounted,
        clearMessagesToForward: (messages) {
          _safeSetState(() {
            _messagesToForward.clear();
          });
        },
        showErrorDialog: _showErrorDialog,
        debugPrefix: 'group',
      ),
    );
  }

  void _cancelReply() {
    _safeSetState(() {
      _replyToMessageData = null;
    });
  }

  void _forwardMessage(MessageModel message) async {
    _safeSetState(() {
      _messagesToForward.clear();
      _messagesToForward.add(message.id);
    });
    await _showForwardModal();
  }

  void _deleteMessage(String messageId) async {
    _safeSetState(() {
      _messages.removeWhere((message) => message.id == messageId);
    });

    ref
        .read(chatProvider.notifier)
        .handleMessageDelete(
          DeleteMessagePayload(
            messageIds: [messageId],
            convId: widget.group.chatId,
            senderId: _currentUserDetails?.id ?? '',
          ),
        )
        .catchError((e) {
          debugPrint('❌ Error deleting messages: $e');
          return;
        });

    await apiService.chat.deleteMessage([
      messageId,
    ], isAdminOrStaff: _isAdminOrStaff);

    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
    final deleteMessagePayload = DeleteMessagePayload(
      messageIds: [messageId],
      convId: widget.group.chatId,
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
    // >>>>>-- sending to ws -->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
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

  Future<void> _showMessageActions(
    MessageModel message,
    bool isMyMessage,
  ) async {
    final isPinned = _pinnedMessage?.id == message.id;
    final isStarred = _starredMessages.contains(message.id);

    // Check if the current user is group admin or user role = staff
    bool isAdmin = false;

    // Check if user is group admin
    if (widget.group.role == 'admin') {
      isAdmin = true;
      _safeSetState(() {
        _isAdminOrStaff = true;
      });
    } else {
      // Check if user role is 'staff'
      try {
        if (_currentUserDetails != null &&
            _currentUserDetails!.role == 'staff') {
          isAdmin = true;
          _safeSetState(() {
            _isAdminOrStaff = true;
          });
        }
      } catch (e) {
        debugPrint('❌ Error checking user role: $e');
      }
    }

    if (!mounted) return;

    // Determine which emojis the current user has already reacted with
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
        isAdmin: isAdmin,
        showReadBy: true,
        onReply: () => _replyToMessage(message),
        onPin: () => _togglePinMessage(message),
        onStar: () => _toggleStarMessage(message.id),
        onForward: () => _forwardMessage(message),
        onSelect: () => _enterSelectionMode(message.id),
        onReadBy: (message.senderId == _currentUserDetails?.id)
            ? () => _showReadByModal(message)
            : null,
        onDelete: isAdmin || _isAdminOrStaff
            ? () => _deleteMessage(message.id)
            : null,
        onReact: (emoji) => _reactToMessage(message, emoji),
        myReactions: myReactions,
      ),
    );
  }

  // Media handling methods from inner_chat_page.dart

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

  /// Build message status ticks for group messages
  /// Shows different icons based on isFailed / in-flight state

  void _openImagePreview(String imageUrl, String? caption) async {
    await openImagePreview(
      context: context,
      imageUrl: imageUrl,
      caption: caption,
      messages: _messages,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      mounted: mounted,
      checkExistingCache: false,
      debugPrefix: 'group message',
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
        if (index != -1 && mounted) {
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

  // Voice recording methods

  Future<void> _showReadByModal(MessageModel message) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReadByModal(
        message: message,
        members: _conversationMembers,
        currentUserId: _currentUserDetails!.id,
      ),
    );
  }
}
