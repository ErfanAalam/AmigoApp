part of 'group-messaging.screen.dart';

extension _GroupActions on _InnerGroupChatPageState {
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

  void _bulkDeleteMessages() async {
    final selectedIds = selectedMessages.toList();
    final result = await apiService.chat.deleteMessage(
      selectedIds,
      isAdminOrStaff: _isAdminOrStaff,
    );

    if (result.isSuccess) {
      _safeSetState(() {
        _messages.removeWhere(
          (message) => selectedMessages.contains(message.id),
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
      exitSelectionMode();
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
        messagesToForward: messagesToForward,
        dmList: dmList,
        groupList: groupList,
        isLoading: isLoadingConversations,
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
        messagesToForward: messagesToForward,
        selectedConversationIds: selectedConversationIds,
        currentUserId: _currentUserDetails?.id ?? '',
        sourceConversationId: widget.group.chatId,
        context: context,
        mounted: mounted,
        clearMessagesToForward: (messages) {
          _safeSetState(() {
            messagesToForward.clear();
          });
        },
        showErrorDialog: showErrorDialog,
        debugPrefix: 'group',
      ),
    );
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
      selectedMessages: selectedMessages,
      messagesToForward: messagesToForward,
      setState: _safeSetState,
      exitSelectionMode: exitSelectionMode,
      showForwardModal: _showForwardModal,
    );
  }

  Future<void> _showMessageActions(
    MessageModel message,
    bool isMyMessage,
  ) async {
    final isPinned = _pinnedMessage?.id == message.id;
    final isStarred = starredMessages.contains(message.id);

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
        onReply: () => replyToMessage(message),
        onPin: () => togglePinMessage(message),
        onStar: () => toggleStarMessage(message.id),
        onForward: () => forwardMessage(message),
        onSelect: () => enterSelectionMode(message.id),
        onReadBy: (message.senderId == _currentUserDetails?.id)
            ? () => _showReadByModal(message)
            : null,
        onDelete: isAdmin || _isAdminOrStaff
            ? () => _deleteMessage(message.id)
            : null,
        onReact: (emoji) => reactToMessage(message, emoji),
        myReactions: myReactions,
      ),
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
