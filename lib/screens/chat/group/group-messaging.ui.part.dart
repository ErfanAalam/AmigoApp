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

  Widget _buildMessagesList() {
    if (displayMessages.isEmpty && !_isLoading && !isInJumpMode) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.black, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // ElevatedButton(
            //   onPressed: null,
            //   child: const Text('Refresh'),
            // ),
          ],
        ),
      );
    }

    // Only show "No messages yet" if we've fully initialized and confirmed no messages
    if (displayMessages.isEmpty && !_isLoading && !isInJumpMode) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_rounded, size: 32, color: Colors.grey[400]),
            const SizedBox(height: 6),
            Text(
              "No message yet",
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // ElevatedButton(
            //   onPressed: _loadInitialMessages,
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.white,
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 20,
            //       vertical: 10,
            //     ),
            //     shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(10),
            //     ),
            //     elevation: 0,
            //   ),
            //   child: const Row(
            //     mainAxisSize: MainAxisSize.min,
            //     children: [
            //       Icon(Icons.refresh_rounded, size: 16, color: Colors.black),
            //       SizedBox(width: 6),
            //       Text(
            //         'Refresh',
            //         style: TextStyle(
            //           color: Colors.black,
            //           fontSize: 12,
            //           fontWeight: FontWeight.normal,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      );
    }

    // Find media groups (4+ consecutive media messages)
    final mediaGroups = ChatHelpers.findConsecutiveMediaGroups(
      displayMessages,
    );
    final Set<int> groupedMessageIndices = {};
    for (final group in mediaGroups) {
      for (int i = group.startIndex; i <= group.endIndex; i++) {
        groupedMessageIndices.add(i);
      }
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true, // Start from bottom (newest messages)
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount:
          displayMessages.length + (_isLoadingMore && !isInJumpMode ? 1 : 0),
      physics: const ClampingScrollPhysics(),
      cacheExtent: 200,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true, // Optimize repainting
      itemBuilder: (context, index) {
        // Show load-more spinner at the top (highest index in reversed list)
        if (!isInJumpMode &&
            _isLoadingMore &&
            index == displayMessages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        // Adjust index for reverse list
        final messageIndex = index;
        if (messageIndex < 0 || messageIndex >= displayMessages.length) {
          return const SizedBox.shrink();
        }
        final actualIndex = displayMessages.length - 1 - messageIndex;
        final message = displayMessages[actualIndex];

        // Check if this message is part of a media group
        final mediaGroup = mediaGroups.firstWhere(
          (group) =>
              actualIndex >= group.startIndex && actualIndex <= group.endIndex,
          orElse: () => MediaGroup(startIndex: -1, endIndex: -1, messages: []),
        );

        // If this is the first message of a media group, render the grid
        if (mediaGroup.startIndex != -1 &&
            actualIndex == mediaGroup.startIndex) {
          return _buildMediaGroup(mediaGroup, actualIndex);
        }

        // If this message is part of a media group but not the first, skip it
        if (groupedMessageIndices.contains(actualIndex) &&
            actualIndex != mediaGroup.startIndex) {
          return const SizedBox.shrink();
        }

        // Debug: Check user ID comparison
        final isMyMessage = message.senderId == _currentUserDetails?.id;

        // Wrap with AutoScrollTag so scrollToIndex can find this item
        return AutoScrollTag(
          key: ValueKey(message.id),
          controller: _scrollController,
          index: index,
          child: Column(
            children: [
              // Date separator - show the date for the group of messages that starts here
              if (ChatHelpers.shouldShowDateSeparator(
                displayMessages,
                messageIndex,
              ))
                DateSeparator(dateTimeString: message.sentAt),
              // Message bubble with long press
              buildMessageWithActions(message, isMyMessage),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaGroup(MediaGroup group, int actualIndex) {
    final firstMessage = group.messages.first;
    final isMyMessage = firstMessage.senderId == _currentUserDetails?.id;

    return Container(
      margin: EdgeInsets.only(
        left: isMyMessage ? 50 : 0,
        right: isMyMessage ? 0 : 50,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment: isMyMessage
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Date separator if needed
          if (ChatHelpers.shouldShowDateSeparator(
            displayMessages,
            displayMessages.length - 1 - actualIndex,
          ))
            DateSeparator(dateTimeString: firstMessage.sentAt),
          // Media grid
          MediaGridWidget(
            mediaMessages: group.messages,
            isMyMessage: isMyMessage,
            onTap: (messages, index) =>
                _openMediaGroupPreview(messages, index, isMyMessage),
            onCacheImage: (url, id) {
              ChatHelpers.cacheMediaForMessage(
                url: url,
                messageId: id,
                mediaCacheService: _mediaCacheService,
                checkExistingCache: false,
                debugPrefix: 'group media grid',
              );
            },
            videoThumbnailCache: _videoThumbnailCache,
            videoThumbnailFutures: _videoThumbnailFutures,
            generateVideoThumbnail: (url, _) async {
              return await generateVideoThumbnailWithCache(
                    url,
                    _videoThumbnailCache,
                    _videoThumbnailFutures,
                  ) ??
                  '';
            },
          ),
        ],
      ),
    );
  }

  void _openMediaGroupPreview(
    List<MessageModel> messages,
    int initialIndex,
    bool isMyMessage,
  ) async {
    await openUnifiedMediaPreview(
      context: context,
      messages: messages,
      initialIndex: initialIndex,
      mediaCacheService: _mediaCacheService,
      messagesRepo: _messagesRepo,
      mounted: mounted,
      isMyMessage: isMyMessage,
      buildMessageStatusTicks: (message) {
        // Status enum is gone; show generic double tick for non-failed messages.
        if (message.isFailed) {
          return const Icon(Icons.error_outline, size: 16, color: Colors.red);
        }
        return const Icon(Icons.done_all, size: 16, color: Colors.white70);
      },
      onRetryImage: (file, source, {MessageModel? failedMessage}) {
        // if (failedMessage != null) {
        //   _resendFailedMessage(failedMessage);
        // } else {
        _sendMediaMessageToServer(file, MessageType.image);
        // }
      },
      onRetryVideo: (file, source, {MessageModel? failedMessage}) {
        // if (failedMessage != null) {
        //   _resendFailedMessage(failedMessage);
        // } else {
        _sendMediaMessageToServer(file, MessageType.video);
        // }
      },
      showErrorDialog: showErrorDialog,
      starredMessages: starredMessages,
    );
  }

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

    // If attachments indicate an in-flight upload, show cloud icon
    final atts = message.attachments;
    if (atts is Map<String, dynamic> && atts['is_uploading'] == true) {
      return Icon(
        Icons.cloud_upload_outlined,
        size: 16,
        color: Colors.greenAccent,
      );
    }

    final status = _deliveryStatusByMessage[message.id] ?? MessageStatusType.sent;
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
      sendMediaMessageToServer: _sendMediaMessageToServer,
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
      isSending: _isSendingMessage,
      replyToMessageData: replyToMessageData,
      currentUserId: _currentUserDetails?.id ?? '',
      onSendMessage: (messageType) => _sendMessage(messageType),
      onSendVoiceNote: sendVoiceNote,
      onAttachmentTap: showAttachmentModal,
      onTyping: _handleTyping,
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
