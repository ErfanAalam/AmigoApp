part of 'group-messaging.screen.dart';

extension _GroupUi on _InnerGroupChatPageState {
  Widget _buildStickyDateSeparator() {
    if (!_showStickyDate || _currentStickyDate == null) {
      return const SizedBox.shrink();
    }

    // Find a message with the current date to get the formatted date string
    final messageWithCurrentDate = _displayMessages.firstWhere(
      (message) =>
          ChatHelpers.getMessageDateString(message.sentAt) ==
          _currentStickyDate,
      orElse: () => _displayMessages.first,
    );

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          ChatHelpers.formatDateSeparator(messageWithCurrentDate.sentAt),
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

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
    if (_displayMessages.isEmpty && !_isLoading && !_isInJumpMode) {
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
    if (_displayMessages.isEmpty && !_isLoading && !_isInJumpMode) {
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
      physics: const ClampingScrollPhysics(),
      cacheExtent: 200,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true, // Optimize repainting
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

        // Adjust index for reverse list
        final messageIndex = index;
        if (messageIndex < 0 || messageIndex >= _displayMessages.length) {
          return const SizedBox.shrink();
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
      showErrorDialog: _showErrorDialog,
      starredMessages: _starredMessages,
    );
  }

  Widget _buildMessageWithActions(MessageModel message, bool isMyMessage) {
    final themeColor = ref.watch(themeColorProvider);
    final isSelected = _selectedMessages.contains(message.id);
    final isPinned = _pinnedMessage?.id == message.id;
    final isStarred = _starredMessages.contains(message.id);

    return GestureDetector(
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
    );
  }

  // Swipe gesture handling methods

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
      if (distSq < _InnerGroupChatPageState._minSwipeDistanceSq)
        return; // too little movement to classify

      // Strictly left-to-right: vertical component must be < ~10° off horizontal
      if (dx > 0 && dy < dx * _InnerGroupChatPageState._maxSwipeAngleRatio) {
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
          (details.velocity.pixelsPerSecond.dx > _InnerGroupChatPageState._minSwipeVelocity ||
              controller.value > _InnerGroupChatPageState._swipeThreshold)) {
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
    if (message.type == MessageType.system) {
      return _buildSystemMessage(message);
    }

    // Pre-calculate values for better performance
    final messageTime = ChatHelpers.formatMessageTime(message.sentAt);

    // Check if this message should be animated
    final shouldAnimate = _messageAnimationControllers.containsKey(message.id);
    final slideAnimation = _messageSlideAnimations[message.id];
    final fadeAnimation = _messageFadeAnimations[message.id];

    // Check if this message is currently highlighted
    final isHighlighted = _highlightedMessageId == message.id;

    // Reactions are tracked in _reactionsByMessage; MessageModel no longer has
    // a reactions field. Downstream widgets read reactions via callbacks.
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
        onResendFailedMessage: (messageId) {
          if (!_isResendingFailedMessage(messageId)) {
            resendFailedMessage(messageId);
          }
        },
        onDeleteFailedMessage: (messageId) async {
          // Remove from UI immediately
          if (mounted) {
            _safeSetState(() {
              _messages.removeWhere((message) => message.id == messageId);
            });
          }
          // Delete from local database
          await _messagesRepo.permanentlyDeleteMessage(messageId);
        },
        isGroupChat: true,
        nonMyMessageBackgroundColor: Colors.grey[100]!,
        useIntrinsicWidth: false,
        useStackContainer: false,
        currentUserId: _currentUserDetails!.id,
        onReplyTap: _scrollToMessage,
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
          message.body ?? '',
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
          message.body ?? '',
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
          message.body ?? '',
          style: TextStyle(
            color: isMyMessage ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        );
    }
  }

  bool _isMediaMessage(MessageModel message) {
    return ChatHelpers.isMediaMessage(message);
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
    return MediaMessageConfig(
      message: message,
      isMyMessage: isMyMessage,
      isStarred: _starredMessages.contains(message.id),
      mounted: () => mounted,
      setState: () => _safeSetState(() {}),
      showErrorDialog: _showErrorDialog,
      buildMessageStatusTicks: _buildMessageStatusTicks,
      onResendFailedMessage: (messageId) {
        if (!_isResendingFailedMessage(messageId)) {
          resendFailedMessage(messageId);
        }
      },
      onDeleteFailedMessage: (messageId) async {
        // Remove from UI immediately
        if (mounted) {
          _safeSetState(() {
            _messages.removeWhere((message) => message.id == messageId);
          });
        }
        // Delete from local database
        await _messagesRepo.permanentlyDeleteMessage(messageId);
      },
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
          messageId: id,
          mediaCacheService: _mediaCacheService,
          checkExistingCache: false,
          debugPrefix: 'group message',
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
    );
  }

  // Add all missing media rendering methods

  Widget _buildImageMessage(MessageModel message, bool isMyMessage) {
    return buildImageMessage(
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
      isReplying: _replyToMessageData != null,
      isSending: _isSendingMessage,
      replyToMessageData: _replyToMessageData,
      currentUserId: _currentUserDetails?.id ?? '',
      onSendMessage: (messageType) => _sendMessage(messageType),
      onSendVoiceNote: _sendVoiceNote,
      onAttachmentTap: _showAttachmentModal,
      onTyping: _handleTyping,
      onCancelReply: _cancelReply,
      focusNode: _messageFocusNode,
      onFocusChange: (isFocused) {
        if (!mounted) return;
        _safeSetState(() {
          _isInputFocused = isFocused;
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
      isGroupChat: true,
    );
  }

  // Media preview methods
}
