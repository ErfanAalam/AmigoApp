part of 'dm-messaging.screen.dart';

extension _DmUi on _InnerChatPageState {
  Widget _buildMessageStatusTicks(MessageModel message) {
    if (message.isFailed) {
      return Icon(Icons.error_outline_rounded, size: 16, color: Colors.red);
    }
    final status = _deriveStatus(message);
    switch (status) {
      case MessageStatusType.read:
        return Icon(Icons.done_all_rounded, size: 16, color: Colors.blue);
      case MessageStatusType.delivered:
        return Icon(Icons.done_all_rounded, size: 16, color: Colors.grey[500]);
      case MessageStatusType.sent:
        return Icon(Icons.done_rounded, size: 16, color: Colors.grey[500]);
      case MessageStatusType.unsent:
        return Icon(
          Icons.access_time_rounded,
          size: 16,
          color: Colors.grey[500],
        );
      case MessageStatusType.uploading:
        return Icon(
          Icons.cloud_upload_outlined,
          size: 16,
          color: Colors.greenAccent,
        );
      case MessageStatusType.failed:
        return Icon(Icons.error_outline_rounded, size: 16, color: Colors.red);
    }
  }

  Widget _buildSyncProgressBar() => const SyncProgressPill();

  Widget _buildLoadingTargetPill() => const LoadingTargetPill();

  Widget _buildMessagesList() {
    // Only show "No messages yet" if we've fully initialized and confirmed no messages
    if (displayMessages.isEmpty && !_isLoading && !isInJumpMode) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
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
      physics:
          const ClampingScrollPhysics(), // Better performance than bouncing
      cacheExtent: 200,
      addAutomaticKeepAlives: false, // Don't keep all items alive
      addRepaintBoundaries:
          true, // Add repaint boundaries for better performance
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

        // Calculate the actual message index, accounting for indicators
        int messageIndex = index;
        // Bounds check to prevent index out of bounds errors
        if (messageIndex < 0 || messageIndex >= displayMessages.length) {
          return const SizedBox.shrink(); // Return empty widget for invalid indices
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

        // Determine if message is from current user
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
    if (group.messages.isEmpty) return const SizedBox.shrink();
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
                messageId: id.toString(),
                mediaCacheService: _mediaCacheService,
                checkExistingCache: false,
                debugPrefix: 'dm media grid',
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
      buildMessageStatusTicks: _buildMessageStatusTicks,
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
        if (_canSetState) {
          _safeSetState(() {
            _messages.removeWhere((m) => m.id == messageId);
          });
        }
        await _messagesRepo.permanentlyDeleteMessage(messageId);
      },
    );
  }

  Widget _buildMessageInput() {
    return MessageInputContainer(
      messageController: _messageController,
      isOtherTypingNotifier: _isOtherTypingNotifier,
      typingIndicator: _buildTypingIndicator(),
      isReplying: replyToMessageData != null,
      isSending: _isSendingMessage,
      replyToMessageData: replyToMessageData,
      currentUserId: _currentUserDetails?.id,
      onSendMessage: (messageType) => _sendMessage(messageType),
      onSendVoiceNote: sendVoiceNote,
      onAttachmentTap: showAttachmentModal,
      onTyping: _handleTyping,
      onCancelReply: cancelReply,
      focusNode: _messageFocusNode,
      onFocusChange: (isFocused) {
        if (!_canSetState) return;
        _safeSetState(() {
          isInputFocused = isFocused;
        });
      },
      dm: widget.dm,
      recommendations: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _messageController,
        builder: (context, value, child) {
          final text = value.text.trim();
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
      isGroupChat: false,
      userProfilePic: widget.dm.recipientProfilePic,
      userName: widget.dm.recipientName,
    );
  }
}
