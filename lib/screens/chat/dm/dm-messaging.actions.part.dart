part of 'dm-messaging.screen.dart';

extension _DmActions on _InnerChatPageState {
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
      selectedMessages: selectedMessages,
      messagesToForward: messagesToForward,
      setState: _safeSetState,
      exitSelectionMode: exitSelectionMode,
      showForwardModal: _showForwardModal,
    );
  }

  void _showMessageActions(MessageModel message, bool isMyMessage) {
    final isPinned = _pinnedMessage?.id == message.id;
    final isStarred = starredMessages.contains(message.id);

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
        onReply: () => replyToMessage(message),
        onPin: () => togglePinMessage(message),
        onStar: () => toggleStarMessage(message.id),
        onForward: () => forwardMessage(message),
        onSelect: () => enterSelectionMode(message.id),
        onDeleteForMe: () => _deleteMessageForMe(message.id),
        onDeleteForEveryone: isMyMessage
            ? () => _deleteMessage(message.id, deleteForEveryone: true)
            : null,
        onReact: (emoji) => reactToMessage(message, emoji),
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
        messagesToForward: messagesToForward,
        dmList: dmList,
        groupList: groupList,
        isLoading: isLoadingConversations,
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
        messagesToForward: messagesToForward,
        selectedConversationIds: selectedConversationIds,
        currentUserId: _currentUserDetails?.id ?? '',
        sourceConversationId: widget.dm.chatId,
        context: context,
        mounted: mounted,
        clearMessagesToForward: (messages) {
          if (_canSetState) {
            _safeSetState(() {
              messagesToForward.clear();
            });
          }
        },
        showErrorDialog: showErrorDialog,
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
