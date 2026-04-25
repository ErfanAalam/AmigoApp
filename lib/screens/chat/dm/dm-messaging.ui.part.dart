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
    if (_displayMessages.isEmpty && !_isLoading && !_isInJumpMode) {
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
      _displayMessages,
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
          _displayMessages.length + (_isLoadingMore && !_isInJumpMode ? 1 : 0),
      physics:
          const ClampingScrollPhysics(), // Better performance than bouncing
      cacheExtent: 200,
      addAutomaticKeepAlives: false, // Don't keep all items alive
      addRepaintBoundaries:
          true, // Add repaint boundaries for better performance
      itemBuilder: (context, index) {
        // Show load-more spinner at the top (highest index in reversed list)
        if (!_isInJumpMode &&
            _isLoadingMore &&
            index == _displayMessages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        // Calculate the actual message index, accounting for indicators
        int messageIndex = index;
        // Bounds check to prevent index out of bounds errors
        if (messageIndex < 0 || messageIndex >= _displayMessages.length) {
          return const SizedBox.shrink(); // Return empty widget for invalid indices
        }

        final actualIndex = _displayMessages.length - 1 - messageIndex;
        final message = _displayMessages[actualIndex];

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
                _displayMessages,
                messageIndex,
              ))
                DateSeparator(dateTimeString: message.sentAt),
              // Message bubble with long press
              _buildMessageWithActions(message, isMyMessage),
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
            _displayMessages,
            _displayMessages.length - 1 - actualIndex,
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
      showErrorDialog: _showErrorDialog,
      starredMessages: _starredMessages,
    );
  }

  Widget _buildStickyDateSeparator() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showStickyDate,
      builder: (context, showDate, child) {
        if (!showDate) {
          return const SizedBox.shrink();
        }

        return ValueListenableBuilder<String?>(
          valueListenable: _currentStickyDate,
          builder: (context, currentDate, child) {
            if (currentDate == null) {
              return const SizedBox.shrink();
            }

            // Find a message with the current date to get the formatted date string
            final messageWithCurrentDate = _displayMessages.firstWhere(
              (message) =>
                  ChatHelpers.getMessageDateString(message.sentAt) ==
                  currentDate,
              orElse: () => _displayMessages.first,
            );

            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                ),
                // show a loading indicator when  _isLoadingMore is true else day
                child: Text(
                  ChatHelpers.formatDateSeparator(
                    messageWithCurrentDate.sentAt,
                  ),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageWithActions(MessageModel message, bool isMyMessage) {
    if (message.type == MessageType.system) {
      return _buildSystemMessage(message);
    }

    final themeColor = ref.watch(themeColorProvider);
    final isSelected = _selectedMessages.contains(message.id);
    final isPinned = _pinnedMessage?.id == message.id;
    final isStarred = _starredMessages.contains(message.id);

    // Wrap in RepaintBoundary to isolate repaints and improve scroll performance
    return RepaintBoundary(
      key: ValueKey(message.id), // Add key for better widget identification
      child: GestureDetector(
        onLongPress: () => _showMessageActions(message, isMyMessage),
        onTap: _selectedMessages.isNotEmpty
            ? () => _toggleMessageSelection(message.id)
            : null,
        onPanStart: (details) => _onSwipeStart(message, details),
        onPanUpdate: (details) => _onSwipeUpdate(message, details, isMyMessage),
        onPanEnd: (details) => _onSwipeEnd(message, details, isMyMessage),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: isMyMessage
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
            color: isSelected
                ? themeColor.primary.withAlpha(100)
                : (_highlightedMessageIds.contains(message.id)
                      ? (_highlightedMessageId == message.id
                            ? Color.fromARGB(50, 0, 27, 41)
                            : Color.fromARGB(25, 0, 27, 41))
                      : (_highlightedMessageId == message.id
                            ? Color.fromARGB(50, 0, 27, 41)
                            : Colors.transparent)),
          ),
          child: Stack(
            children: [
              _buildSwipeableMessageBubble(
                message,
                isMyMessage,
                isPinned,
                isStarred,
              ),
              if (_selectedMessages.isNotEmpty)
                Positioned(
                  left: isMyMessage ? 8 : null,
                  right: isMyMessage ? null : 8,
                  top: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? themeColor.primary : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? themeColor.primary
                            : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(MessageModel message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.body ?? '',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  void _onSwipeStart(MessageModel message, DragStartDetails details) {
    // Initialize swipe animation controller if not exists
    if (!_swipeAnimationControllers.containsKey(message.id)) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );
      _swipeAnimationControllers[message.id] = controller;
      _swipeAnimations[message.id] = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    }

    // Reset swipe tracking variables
    _swipeStartPosition = details.globalPosition;
    _swipeTotalDistance = 0.0;
    _isSwipeGesture = false;
  }

  void _onSwipeUpdate(
    MessageModel message,
    DragUpdateDetails details,
    bool isMyMessage,
  ) {
    if (_selectedMessages.isNotEmpty ||
        _swipeStartPosition == null ||
        _isScrolling) {
      return;
    }

    final currentPosition = details.globalPosition;
    final dx = currentPosition.dx - _swipeStartPosition!.dx;
    final dy = (currentPosition.dy - _swipeStartPosition!.dy).abs();

    // Classify gesture direction as soon as we have a few pixels of movement.
    // Using squared distance avoids sqrt and keeps things fast.
    if (!_isSwipeGesture) {
      final distSq = dx * dx + dy * dy;
      if (distSq < _InnerChatPageState._minSwipeDistanceSq) {
        return; // too little movement to classify
      }

      // Strictly left-to-right: vertical component must be < ~10° off horizontal
      if (dx > 0 && dy < dx * _InnerChatPageState._maxSwipeAngleRatio) {
        _isSwipeGesture = true;
      } else {
        // Any vertical tilt, left swipe, or diagonal → treat as scroll immediately
        _isScrolling = true;
        return;
      }
    }

    // Track finger in real-time with zero lag once classified as a swipe
    if (dx > 0) {
      final controller = _swipeAnimationControllers[message.id];
      if (controller != null) {
        controller.value = (dx / 100).clamp(0.0, 1.0);
      }
    }
  }

  void _onSwipeEnd(
    MessageModel message,
    DragEndDetails details,
    bool isMyMessage,
  ) {
    final controller = _swipeAnimationControllers[message.id];
    if (controller != null) {
      // Only trigger reply if this was confirmed as a horizontal swipe gesture
      if (_isSwipeGesture &&
          (details.velocity.pixelsPerSecond.dx > _InnerChatPageState._minSwipeVelocity ||
              controller.value > _InnerChatPageState._swipeThreshold)) {
        // Animate to complete position then trigger reply
        controller.forward().then((_) {
          _replyToMessage(message);
          // Reset animation
          controller.reverse();
        });
      } else {
        // Animate back to original position
        controller.reverse();
      }
    }

    // Reset swipe tracking variables
    _swipeStartPosition = null;
    _swipeTotalDistance = 0.0;
    _isSwipeGesture = false;
    _isScrolling = false;
  }

  Widget _buildSwipeableMessageBubble(
    MessageModel message,
    bool isMyMessage,
    bool isPinned,
    bool isStarred,
  ) {
    final themeColor = ref.watch(themeColorProvider);
    final swipeAnimation = _swipeAnimations[message.id];

    if (swipeAnimation != null) {
      return AnimatedBuilder(
        animation: swipeAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              // Reply icon background
              if (swipeAnimation.value > 0.1)
                Positioned(
                  left: isMyMessage ? 16 : null,
                  right: isMyMessage ? null : 16,
                  top: 0,
                  bottom: 0,
                  child: Opacity(
                    opacity: swipeAnimation.value,
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: themeColor.primary.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.reply,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              // Message bubble with transform
              Transform.translate(
                offset: Offset(swipeAnimation.value * 50, 0),
                child: _buildMessageBubble(
                  message,
                  isMyMessage,
                  isPinned,
                  isStarred,
                ),
              ),
            ],
          );
        },
      );
    }

    return _buildMessageBubble(message, isMyMessage, isPinned, isStarred);
  }

  Widget _buildMessageBubble(
    MessageModel message,
    bool isMyMessage,
    bool isPinned,
    bool isStarred,
  ) {
    // Pre-calculate values for better performance
    final messageTime = ChatHelpers.formatMessageTime(message.sentAt);

    // Check if this message should be animated
    final shouldAnimate = _messageAnimationControllers.containsKey(message.id);
    final slideAnimation = _messageSlideAnimations[message.id];
    final fadeAnimation = _messageFadeAnimations[message.id];

    // Check if this message is currently highlighted
    final isHighlighted = _highlightedMessageId == message.id;

    // Reactions are surfaced via the Drift stream; MessageModel no longer
    // carries them, so the bubble renders from the stream-backed map.
    final messageWithReactions = message;

    return MessageBubble(
      config: MessageBubbleConfig(
        message: messageWithReactions,
        isMyMessage: isMyMessage,
        isPinned: isPinned,
        isStarred: isStarred,
        isHighlighted: isHighlighted,
        messageTime: messageTime,
        shouldAnimate: shouldAnimate,
        animationController: _messageAnimationControllers[message.id],
        slideAnimation: slideAnimation,
        fadeAnimation: fadeAnimation,
        context: context,
        buildMessageContent: _buildMessageContent,
        isMediaMessage: _isMediaMessage,
        buildMessageStatusTicks: _buildMessageStatusTicks,
        onRetryFailedMessage: (message) {
          if (!_isResendingFailedMessage(message.id)) {
            resendFailedMessage(message.id);
          }
        },
        isResendingMessage: _isResendingFailedMessage(message.id),
        onResendFailedMessage: (String messageId) {
          resendFailedMessage(messageId);
        },
        onDeleteFailedMessage: (String messageId) async {
          // Remove from UI immediately
          if (_canSetState) {
            _safeSetState(() {
              _messages.removeWhere((message) => message.id == messageId);
            });
          }
          // Delete from local DB
          await _messagesRepo.permanentlyDeleteMessage(messageId);
        },
        isGroupChat: false,
        nonMyMessageBackgroundColor: Colors.white,
        useIntrinsicWidth: true,
        useStackContainer: true,
        currentUserId: _currentUserDetails?.id,
        conversationUserId: widget.dm.recipientId,
        onReplyTap: (String id) => _scrollToMessage(id),
        messagesRepo: _messagesRepo,
        userRepo: _userRepo,
        reactions: _reactionsByMessage[message.id] ?? {},
        onReact: (emoji) => _reactToMessage(message, emoji),
        onShowReactionUsers: (reactions) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => AllReactorsSheet(reactions: reactions),
          );
        },
      ),
    );
  }

  bool _isMediaMessage(MessageModel message) {
    return ChatHelpers.isMediaMessage(message);
  }

  Widget _buildMessageContent(MessageModel message, bool isMyMessage) {
    // Check if this is a contact message
    if (isContactMessage(message)) {
      final contacts = parseContactsFromMessage(message);
      if (contacts.isNotEmpty) {
        return ContactMessageWidget(
          contacts: contacts,
          isMyMessage: isMyMessage,
        );
      }
    }

    // Handle attachments based on category
    if (message.attachments != null) {
      final attachmentData = message.attachments as Map<String, dynamic>;
      final category = attachmentData['category'] as String?;

      switch (category?.toLowerCase()) {
        case 'images':
          return _buildImageMessage(message, isMyMessage);
        case 'videos':
          return _buildVideoMessage(message, isMyMessage);
        case 'docs':
          return _buildDocumentMessage(message, isMyMessage);
        case 'audios':
          return _buildAudioMessage(message, isMyMessage);
        default:
          // Fallback to type-based handling for backward compatibility
          break;
      }
    }

    // Fallback to original type-based handling
    switch (message.type.value.toLowerCase()) {
      case 'image':
        return _buildImageMessage(message, isMyMessage);
      case 'video':
        return _buildVideoMessage(message, isMyMessage);
      case 'audio':
        return _buildAudioMessage(message, isMyMessage);
      case 'document':
        return _buildDocumentMessage(message, isMyMessage);
      case 'reply':
        // Reply messages show the reply UI with quoted message
        return Text(
          message.body!,
          style: TextStyle(
            color: isMyMessage ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        );
      case 'forwarded':
        // Forwarded messages show forwarded indicator
        return Text(
          message.body!,
          style: TextStyle(
            color: isMyMessage ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        );
      // Backward compatibility for old types
      case 'docs':
        return _buildDocumentMessage(message, isMyMessage);
      case 'attachment':
        // Server sends attachments with type="attachment" (backward compatibility)
        return _buildImageMessage(message, isMyMessage);
      case 'text':
      default:
        return Text(
          message.body!,
          style: TextStyle(
            color: isMyMessage ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        );
    }
  }

  MediaMessageConfig _buildMediaMessageConfig(
    MessageModel message,
    bool isMyMessage,
  ) {
    return MediaMessageConfig(
      message: message,
      isMyMessage: isMyMessage,
      isStarred: _starredMessages.contains(message.id),
      mounted: () => mounted,
      setState: () => _safeSetState(() {}),
      showErrorDialog: _showErrorDialog,
      buildMessageStatusTicks: _buildMessageStatusTicks,
      onImagePreview: (url, caption) => _openImagePreview(url, caption),
      onRetryImage: (file, source, {MessageModel? failedMessage}) {
        // if (failedMessage != null) {
        //   _resendFailedMessage(failedMessage);
        // } else {
        _sendMediaMessageToServer(file, MessageType.image);
        // }
      },
      onCacheImage: (url, id) {
        ChatHelpers.cacheMediaForMessage(
          url: url,
          messageId: id.toString(),
          mediaCacheService: _mediaCacheService,
        );
      },
      onVideoPreview: (url, caption, fileName) =>
          _openVideoPreview(url, caption, fileName),
      onRetryVideo: (file, source, {MessageModel? failedMessage}) {
        // if (failedMessage != null) {
        //   _resendFailedMessage(failedMessage);
        // } else {
        _sendMediaMessageToServer(file, MessageType.video);
        // }
      },
      videoThumbnailCache: _videoThumbnailCache,
      videoThumbnailFutures: _videoThumbnailFutures,
      onDocumentPreview: (url, fileName, caption, fileSize) =>
          _openDocumentPreview(url, fileName, caption, fileSize),
      onRetryDocument:
          (file, fileName, extension, {MessageModel? failedMessage}) {
            // if (failedMessage != null) {
            //   _resendFailedMessage(failedMessage);
            // } else {
            _sendMediaMessageToServer(file, MessageType.document);
            // }
          },
      audioPlaybackManager: _audioPlaybackManager,
      onRetryAudio: ({MessageModel? failedMessage}) {
        // if (failedMessage != null) {
        //   _resendFailedMessage(failedMessage);
        // } else {
        _sendMediaMessageToServer(
          File(failedMessage?.attachments?['url'] ?? ''),
          MessageType.audio,
        );
        // }
      },
      onResendFailedMessage: (String messageId) {
        resendFailedMessage(messageId);
      },
      onDeleteFailedMessage: (String messageId) async {
        // Remove from UI immediately
        if (_canSetState) {
          _safeSetState(() {
            _messages.removeWhere((message) => message.id == messageId);
          });
        }
        // Delete from local DB
        await _messagesRepo.permanentlyDeleteMessage(messageId);
      },
    );
  }

  Widget _buildDocumentMessage(MessageModel message, bool isMyMessage) {
    return buildDocumentMessage(
      _buildMediaMessageConfig(message, isMyMessage),
      ref,
    );
  }

  Widget _buildAudioMessage(MessageModel message, bool isMyMessage) {
    return buildAudioMessage(
      _buildMediaMessageConfig(message, isMyMessage),
      ref,
    );
  }

  Widget _buildVideoMessage(MessageModel message, bool isMyMessage) {
    return buildVideoMessage(
      _buildMediaMessageConfig(message, isMyMessage),
      ref,
    );
  }

  Widget _buildImageMessage(MessageModel message, bool isMyMessage) {
    return buildImageMessage(
      _buildMediaMessageConfig(message, isMyMessage),
      ref,
    );
  }

  Widget _buildMessageInput() {
    return MessageInputContainer(
      messageController: _messageController,
      isOtherTypingNotifier: _isOtherTypingNotifier,
      typingIndicator: _buildTypingIndicator(),
      isReplying: _replyToMessageData != null,
      isSending: _isSendingMessage,
      replyToMessageData: _replyToMessageData,
      currentUserId: _currentUserDetails?.id,
      onSendMessage: (messageType) => _sendMessage(messageType),
      onSendVoiceNote: _sendVoiceNote,
      onAttachmentTap: _showAttachmentModal,
      onTyping: _handleTyping,
      onCancelReply: _cancelReply,
      focusNode: _messageFocusNode,
      onFocusChange: (isFocused) {
        if (!_canSetState) return;
        _safeSetState(() {
          _isInputFocused = isFocused;
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
            onRecommendationTap: _onRecommendationTap,
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
