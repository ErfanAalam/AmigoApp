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
        return buildUploadingStatusTick(message);
      case MessageStatusType.failed:
        return Icon(Icons.error_outline_rounded, size: 16, color: Colors.red);
    }
  }

  MessageStatusType _deriveStatus(MessageModel message) {
    if (message.isFailed) return MessageStatusType.failed;
    final atts = message.attachments;
    if (atts is Map<String, dynamic>) {
      if (atts['is_uploading'] == true) return MessageStatusType.uploading;
    }
    return deliveryStatusByMessage[message.id] ?? MessageStatusType.sent;
  }

  Widget _buildSyncProgressBar() => const SyncProgressPill();

  Widget _buildLoadingTargetPill() => const LoadingTargetPill();

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
      isSending: isSendingMessage,
      replyToMessageData: replyToMessageData,
      currentUserId: _currentUserDetails?.id,
      onSendMessage: sendMessage,
      onSendVoiceNote: sendVoiceNote,
      onAttachmentTap: showAttachmentModal,
      onTyping: handleTyping,
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
