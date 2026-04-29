part of 'group-messaging.screen.dart';

extension _GroupUi on _InnerGroupChatPageState {
  // Future<void> _loadInitialMessages() async {
  //   final conversationId = widget.group.chatId;

  //   await loadInitialMessages(
  //     LoadInitialMessagesConfig(
  //       conversationId: conversationId,
  //       messagesRepo: _messagesRepo,
  //       chatsServices: _chatsServices,
  //       mounted: () => mounted,
  //       setState: _safeSetState,
  //       hasCheckedCache: () => _hasCheckedCache,
  //       getMessages: () => _messages,
  //       getConversationMeta: () => _conversationMeta,
  //       getHasMoreMessages: () => _hasMoreMessages,
  //       getCurrentPage: () => _currentPage,
  //       getIsInitialized: () => _isInitialized,
  //       getIsLoading: () => _isLoading,
  //       getErrorMessage: () => _errorMessage,
  //       getIsCheckingCache: () => _isCheckingCache,
  //       getIsLoadingFromCache: () => _isLoadingFromCache,
  //       setHasCheckedCache: (value) => _hasCheckedCache = value,
  //       setMessages: (value) => _messages = value,
  //       setConversationMeta: (value) => _conversationMeta = value,
  //       setHasMoreMessages: (value) => _hasMoreMessages = value,
  //       setCurrentPage: (value) => _currentPage = value,
  //       setIsInitialized: (value) => _isInitialized = value,
  //       setIsLoading: (value) => _isLoading = value,
  //       setErrorMessage: (value) => _errorMessage = value,
  //       setIsCheckingCache: (value) => _isCheckingCache = value,
  //       setIsLoadingFromCache: (value) => _isLoadingFromCache = value,
  //       performSmartSync: _performSmartSync,
  //       validateMessages: (messages) {
  //         _validatePinnedMessage();
  //         _validateStarredMessages();
  //         _validateReplyMessages();
  //       },
  //       populateReplyMessageSenderNames: _populateReplyMessageSenderNames,
  //       cleanCachedMessages: (messages) {
  //         // Filter out old orphaned optimistic messages (messages with negative IDs older than 5 minutes)
  //         final now = DateTime.now();
  //         final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

  //         final cleanedMessages = messages.where((msg) {
  //           // Keep all messages with positive IDs (server-confirmed)
  //           if (msg.id >= 0) return true;

  //           // For optimistic messages (negative IDs), only keep recent ones
  //           try {
  //             final createdAt = DateTime.parse(msg.createdAt);
  //             return createdAt.isAfter(fiveMinutesAgo);
  //           } catch (e) {
  //             // If we can't parse the date, keep the message to be safe
  //             return true;
  //           }
  //         }).toList();

  //         // Remove duplicates by ID (keep the one with positive ID if both exist)
  //         final messageMap = <int, MessageModel>{};
  //         for (final msg in cleanedMessages) {
  //           final existingMsg = messageMap[msg.id.abs()];
  //           // Prefer positive IDs (server-confirmed) over negative IDs (optimistic)
  //           if (existingMsg == null || msg.id > 0) {
  //             messageMap[msg.id.abs()] = msg;
  //           }
  //         }
  //         final deduplicatedMessages = messageMap.values.toList()
  //           ..sort((a, b) => a.id.compareTo(b.id));

  //         return deduplicatedMessages;
  //       },
  //       onAfterLoadFromServer: _cacheUsersFromMetadata,
  //       getErrorMessageText: () => 'Failed to load group messages',
  //       getNoCacheMessage: () =>
  //           'ℹ️ No cached group messages found in local DB',
  //     ),
  //   );
  // }

  // Future<void> _loadMoreMessages() async {
  //   final conversationId = widget.group.chatId;

  //   await loadMoreMessages(
  //     LoadMoreMessagesConfig(
  //       conversationId: conversationId,
  //       messagesRepo: _messagesRepo,
  //       chatsServices: _chatsServices,
  //       mounted: () => mounted,
  //       setState: _safeSetState,
  //       isLoadingMore: () => _isLoadingMore,
  //       hasMoreMessages: () => _hasMoreMessages,
  //       currentPage: () => _currentPage,
  //       getMessages: () => _messages,
  //       getConversationMeta: () => _conversationMeta,
  //       setIsLoadingMore: (value) => _isLoadingMore = value,
  //       setHasMoreMessages: (value) => _hasMoreMessages = value,
  //       setCurrentPage: (value) => _currentPage = value,
  //       setMessages: (value) => _messages = value,
  //       setConversationMeta: (value) => _conversationMeta = value,
  //       populateReplyMessageSenderNames: _populateReplyMessageSenderNames,
  //       onAfterLoadMore: _cacheUsersFromMetadata,
  //     ),
  //   );
  // }

  /// Set up WebSocket message listener for real-time group messages

  Widget _buildSyncProgressBar() => const SyncProgressPill();

  Widget _buildLoadingTargetPill() => const LoadingTargetPill();

  /// Handle media upload failure
  /// Handle media upload failure - update only metadata to mark as failed
  // void _handleMediaUploadFailure(MessageModel loadingMessage, String error) {
  //   if (!mounted) return;

  //   // Find the message and update only metadata
  //   final index = _messages.indexWhere((msg) => msg.id == loadingMessage.id);
  //   if (index != -1) {
  //     final failedMessage = _messages[index];
  //     final updatedMetadata = Map<String, dynamic>.from(
  //       failedMessage.metadata ?? {},
  //     );
  //     updatedMetadata['is_uploading'] = false;
  //     updatedMetadata['upload_failed'] = true;

  //     _safeSetState(() {
  //       // Use copyWith to update only metadata, explicitly preserve attachments
  //       _messages[index] = failedMessage.copyWith(
  //         metadata: updatedMetadata,
  //         attachments:
  //             failedMessage.attachments, // Explicitly preserve attachments
  //       );
  //     });
  //   }
  // }

  Widget _buildMessageStatusTicks(MessageModel message) {
    // For failed messages, show error icon
    if (message.isFailed) {
      return Icon(Icons.error_outline_rounded, size: 16, color: Colors.red);
    }

    // If attachments indicate an in-flight upload, show cloud + live percent.
    final atts = message.attachments;
    if (atts is Map<String, dynamic> && atts['is_uploading'] == true) {
      return buildUploadingStatusTick(message);
    }

    final status = deliveryStatusByMessage[message.id] ?? MessageStatusType.sent;
    switch (status) {
      case MessageStatusType.read:
        return Icon(Icons.done_all_rounded, size: 16, color: Colors.blue);
      case MessageStatusType.delivered:
        return Icon(Icons.done_all_rounded, size: 16, color: Colors.grey[500]);
      default:
        return Icon(Icons.done_rounded, size: 16, color: Colors.grey[500]);
    }
  }

  /// Get the appropriate status tick icon based on read/delivered status

  Future<Widget> _getStatusTickIcon(MessageModel message) async {
    // Get total members excluding sender
    final totalMembers = _conversationMembers
        .where((member) => member.id != message.senderId)
        .length;

    if (totalMembers == 0) {
      // No other members, just show sent status
      return Icon(Icons.done_rounded, size: 16, color: Colors.grey[500]);
    }

    // Get read and delivered counts
    final readCount = await _messageStatusRepo.getReadCountByMessageId(
      message.id,
    );
    final deliveredCount = await _messageStatusRepo
        .getDeliveredCountByMessageId(message.id);

    // Check if all members have read the message
    if (readCount >= totalMembers) {
      // All members have read - double blue tick
      return Icon(Icons.done_all_rounded, size: 16, color: Colors.blue);
    }

    // Check if all members have delivered the message
    if (deliveredCount >= totalMembers) {
      // All members have delivered - double gray tick
      return Icon(Icons.done_all_rounded, size: 16, color: Colors.grey[500]);
    }

    // Message is sent but not all have delivered - single gray tick
    return Icon(Icons.done_rounded, size: 16, color: Colors.grey[500]);
  }

  MediaMessageConfig _buildMediaMessageConfig(
    MessageModel message,
    bool isMyMessage,
  ) {
    return shared_media.buildMediaMessageConfig(
      message: message,
      isMyMessage: isMyMessage,
      isStarred: starredMessages.contains(message.id),
      mounted: () => mounted,
      onSetState: () => _safeSetState(() {}),
      showErrorDialog: showErrorDialog,
      buildMessageStatusTicks: _buildMessageStatusTicks,
      onImagePreview: _openImagePreview,
      onVideoPreview: _openVideoPreview,
      onDocumentPreview: _openDocumentPreview,
      sendMediaMessageToServer: sendMediaMessageToServer,
      videoThumbnailCache: _videoThumbnailCache,
      videoThumbnailFutures: _videoThumbnailFutures,
      audioPlaybackManager: _audioPlaybackManager,
      mediaCacheService: _mediaCacheService,
      onResendFailedMessage: resendFailedMessage,
      onDeleteFailedMessage: (messageId) async {
        if (mounted) {
          _safeSetState(() {
            _messages.removeWhere((m) => m.id == messageId);
          });
        }
        await _messagesRepo.permanentlyDeleteMessage(messageId);
      },
      cacheCheckExisting: false,
      cacheDebugPrefix: 'group message',
    );
  }

  // Add all missing media rendering methods

List<Widget> _buildSelectionModeActions() {
    final actions = <Widget>[
      IconButton(
        icon: const Icon(Icons.star_border, color: Colors.white),
        onPressed: _bulkStarMessages,
        tooltip: 'Star messages',
      ),
      IconButton(
        icon: const Icon(Icons.forward, color: Colors.white),
        onPressed: _bulkForwardMessages,
        tooltip: 'Forward messages',
      ),
    ];

    // Show delete button if:
    // 1. User is admin/staff, OR
    // 2. All selected messages belong to the current user

    if (_isAdminOrStaff) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          onPressed: _bulkDeleteMessages,
          tooltip: 'Delete messages',
        ),
      );
    }

    return actions;
  }

  Widget _buildMessageInput() {
    if (_isRemovedFromGroup) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        color: Colors.grey[100],
        child: const Text(
          "You're no longer a member of this group",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return MessageInputContainer(
      messageController: _messageController,
      isOtherTypingNotifier: _isOtherTypingNotifier,
      typingIndicator: _buildTypingIndicator(),
      isReplying: replyToMessageData != null,
      isSending: isSendingMessage,
      replyToMessageData: replyToMessageData,
      currentUserId: _currentUserDetails?.id ?? '',
      onSendMessage: sendMessage,
      onSendVoiceNote: sendVoiceNote,
      onAttachmentTap: showAttachmentModal,
      onTyping: handleTyping,
      onCancelReply: cancelReply,
      focusNode: _messageFocusNode,
      onFocusChange: (isFocused) {
        if (!mounted) return;
        _safeSetState(() {
          isInputFocused = isFocused;
        });
      },
      isCommunityGroup: widget.isCommunityGroup,
      communityGroupMetadata: widget.communityGroupMetadata,
      recommendations: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _messageController,
        builder: (context, value, child) {
          // Show recommendations if text is empty OR if it matches one of the recommendations
          // if (text.isEmpty || _messageRecommendations.contains(text)) {
          return MessageRecommendations(
            recommendations: _messageRecommendations,
            onRecommendationTap: onRecommendationTap,
          );
          // }
          // return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return ChatHelpers.buildTypingIndicator(
      typingDotAnimations: _typingDotAnimations,
      isGroupChat: true,
    );
  }

  // Media preview methods
}
