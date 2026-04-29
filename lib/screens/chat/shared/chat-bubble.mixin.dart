import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import '../../../db/repositories/message.repo.dart';
import '../../../db/repositories/user.repo.dart';
import '../../../models/message.model.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../services/media-cache.service.dart';
import '../../../types/socket.types.dart';
import '../../../ui/chat/contact-message.widget.dart';
import '../../../ui/chat/date.widgets.dart';
import '../../../ui/chat/emoji-reaction.widget.dart';
import '../../../ui/chat/media-grid.widget.dart';
import '../../../ui/chat/media-messages.widget.dart';
import '../../../ui/chat/message.widget.dart';
import '../../../utils/chat/chat-helpers.utils.dart';
import '../../../utils/chat/preview-media.utils.dart';
import 'media-message-config.builder.dart' as shared_media;

/// Status-tick variant shown while a media upload is in flight. Reads the
/// real percentage from `attachments.upload_progress` (0-100, written by
/// `ChatSendMixin.sendMediaMessageToServer` from the `onSendProgress`
/// callback) and renders it next to the cloud-up icon. Both DM and group
/// host status-tick builders call into this for the uploading branch so
/// the visual is identical.
Widget buildUploadingStatusTick(MessageModel message) {
  final progress = (message.attachments?['upload_progress'] as int?) ?? 0;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(
        Icons.cloud_upload_outlined,
        size: 16,
        color: Colors.greenAccent,
      ),
      const SizedBox(width: 2),
      Text(
        '$progress%',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.greenAccent,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

/// Message-bubble rendering shared between DM and group screens.
///
/// Lifts the long bubble-building chain — `buildMessageWithActions` (the
/// outer gesture / selection / animated-container shell), `buildMessageBubble`
/// (config wiring for the [MessageBubble] widget), `buildMessageContent`
/// (contact / media / text dispatch), and `buildSystemMessage`. Hosts plug
/// in via the conversation-shape getters and a couple of helper hooks.
mixin ChatBubbleMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  // ---- Conversation-shape config ----
  bool get isGroupChat;

  /// Background colour for messages from other people. DM uses pure white
  /// against a tinted background; group uses light grey.
  Color get nonMyMessageBackgroundColor => Colors.white;

  /// Whether the bubble wraps content in `IntrinsicWidth`. DM does, group
  /// doesn't (group bubbles stretch to fill more horizontal space).
  bool get useIntrinsicWidth => true;

  /// Whether the bubble uses the stacked-container layout. DM-only.
  bool get useStackContainer => true;

  /// DM passes the recipient id so the bubble's reply preview can resolve
  /// authors that aren't `currentUserId`. Group leaves this null and the
  /// bubble uses its full member-aware lookup instead.
  String? get conversationUserId => null;

  // ---- Host-provided helpers ----

  /// Renders the per-host status ticks (DM is a simple sent/delivered/read
  /// glyph; group folds in upload progress + per-member read counts).
  Widget buildMessageStatusTicks(MessageModel message);

  /// Long-press handler. Hosts wire to their own message-actions sheet
  /// (group adds admin-only delete; DM has delete-for-me / delete-for-everyone).
  void showMessageActions(MessageModel message, bool isMyMessage);

  /// Builds the [MediaMessageConfig] used by image/video/document/audio
  /// bubbles. Hosts call into [shared_media.buildMediaMessageConfig] with
  /// per-host wiring (group passes `cacheCheckExisting: false` etc.).
  MediaMessageConfig buildMediaMessageConfig(
    MessageModel message,
    bool isMyMessage,
  );

  /// Repos used to resolve reply-preview metadata.
  MessageRepository get messagesRepo;
  UserRepository get userRepo;

  /// Used by media-grid caching + the unified media preview.
  MediaCacheService get mediaCacheService;
  Map<String, String?> get videoThumbnailCache;
  Map<String, Future<String?>> get videoThumbnailFutures;

  /// Where the [ListView] anchors its scroll. Hosts hand back `_scrollController`.
  AutoScrollController get scrollController;

  /// Top-level loading flag (used by the empty-state guard so the placeholder
  /// only shows after the first sync completes).
  bool get isLoading;

  /// True while a `loadMoreMessages` request is in flight. Used to render the
  /// load-more spinner at the top of the list.
  bool get isLoadingMore;

  /// Status-tick builder used inside the unified media preview. Defaults to
  /// the host's [buildMessageStatusTicks]; group overrides with a simpler
  /// failed/sent glyph because the preview doesn't need member-aware ticks.
  Widget mediaPreviewStatusTicks(MessageModel message) =>
      buildMessageStatusTicks(message);

  /// Sends a media file to the server. Provided by [ChatAttachmentMixin] on
  /// the host; redeclared here so this mixin compiles against its abstracts.
  Future<void> sendMediaMessageToServer(File file, MessageType type);

  /// Shows the friendly error dialog. Provided by [ChatAttachmentMixin].
  void showErrorDialog(String message);

  // ---- Inherited from sibling mixins (declared here so this mixin compiles
  //      standalone; real impl is provided by ChatSearch / ChatActions /
  //      ChatScroll / ChatSwipeReply mixins on the host) ----
  bool get canSetState;
  void safeSetState(VoidCallback fn);
  List<MessageModel> get messages;
  Set<String> get selectedMessages;
  Set<String> get starredMessages;
  MessageModel? get pinnedMessage;
  String? get currentUserId;
  String? get highlightedMessageId;
  Set<String> get highlightedMessageIds;
  Map<String, Map<String, dynamic>> get reactionsByMessage;
  Map<String, AnimationController> get messageAnimationControllers;
  Map<String, Animation<double>> get messageSlideAnimations;
  Map<String, Animation<double>> get messageFadeAnimations;
  void toggleMessageSelection(String messageId);
  Future<void> reactToMessage(MessageModel message, String emoji);
  Future<void> scrollToMessage(String messageId);

  /// Tear-off of the host's `resendFailedMessage` (defined as an extension
  /// method on send.part — extensions don't satisfy mixin abstracts directly,
  /// so we go through a getter that hands back the function reference).
  Future<void> Function(String messageId) get onResendFailedMessage;
  void onSwipeStart(MessageModel message, DragStartDetails details);
  void onSwipeUpdate(
    MessageModel message,
    DragUpdateDetails details,
    bool isMyMessage,
  );
  void onSwipeEnd(
    MessageModel message,
    DragEndDetails details,
    bool isMyMessage,
  );
  Widget buildSwipeableMessageBubble({
    required MessageModel message,
    required bool isMyMessage,
    required Color replyIconBackgroundColor,
    required Widget Function() bubbleBuilder,
  });

  // ---- Builders ----

  Widget buildMessageWithActions(MessageModel message, bool isMyMessage) {
    if (message.type == MessageType.system) {
      return buildSystemMessage(message);
    }

    final themeColor = ref.watch(themeColorProvider);
    final isSelected = selectedMessages.contains(message.id);
    final isPinned = pinnedMessage?.id == message.id;
    final isStarred = starredMessages.contains(message.id);

    return RepaintBoundary(
      key: ValueKey(message.id),
      child: GestureDetector(
        onLongPress: () => showMessageActions(message, isMyMessage),
        onTap: selectedMessages.isNotEmpty
            ? () => toggleMessageSelection(message.id)
            : null,
        onPanStart: (details) => onSwipeStart(message, details),
        onPanUpdate: (details) => onSwipeUpdate(message, details, isMyMessage),
        onPanEnd: (details) => onSwipeEnd(message, details, isMyMessage),
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
            color: _bubbleBackgroundColor(
              themeColor: themeColor.primary,
              isSelected: isSelected,
              messageId: message.id,
            ),
          ),
          child: Stack(
            children: [
              buildSwipeableMessageBubble(
                message: message,
                isMyMessage: isMyMessage,
                replyIconBackgroundColor: themeColor.primary.withOpacity(0.8),
                bubbleBuilder: () =>
                    buildMessageBubble(message, isMyMessage, isPinned, isStarred),
              ),
              if (selectedMessages.isNotEmpty)
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

  Color _bubbleBackgroundColor({
    required Color themeColor,
    required bool isSelected,
    required String messageId,
  }) {
    if (isSelected) return themeColor.withAlpha(100);
    final isCurrentMatch = highlightedMessageId == messageId;
    final isAnyMatch = highlightedMessageIds.contains(messageId);
    if (isAnyMatch || isCurrentMatch) {
      return Color.fromARGB(isCurrentMatch ? 50 : 25, 0, 27, 41);
    }
    return Colors.transparent;
  }

  Widget buildSystemMessage(MessageModel message) {
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

  Widget buildMessageBubble(
    MessageModel message,
    bool isMyMessage,
    bool isPinned,
    bool isStarred,
  ) {
    return MessageBubble(
      config: MessageBubbleConfig(
        message: message,
        isMyMessage: isMyMessage,
        isPinned: isPinned,
        isStarred: isStarred,
        isHighlighted: highlightedMessageId == message.id,
        messageTime: ChatHelpers.formatMessageTime(message.sentAt),
        shouldAnimate: messageAnimationControllers.containsKey(message.id),
        animationController: messageAnimationControllers[message.id],
        slideAnimation: messageSlideAnimations[message.id],
        fadeAnimation: messageFadeAnimations[message.id],
        context: context,
        buildMessageContent: buildMessageContent,
        isMediaMessage: ChatHelpers.isMediaMessage,
        buildMessageStatusTicks: buildMessageStatusTicks,
        onResendFailedMessage: onResendFailedMessage,
        onDeleteFailedMessage: (messageId) async {
          if (canSetState) {
            safeSetState(() {
              messages.removeWhere((m) => m.id == messageId);
            });
          }
          await messagesRepo.permanentlyDeleteMessage(messageId);
        },
        isGroupChat: isGroupChat,
        nonMyMessageBackgroundColor: nonMyMessageBackgroundColor,
        useIntrinsicWidth: useIntrinsicWidth,
        useStackContainer: useStackContainer,
        currentUserId: currentUserId,
        conversationUserId: conversationUserId,
        onReplyTap: scrollToMessage,
        messagesRepo: messagesRepo,
        userRepo: userRepo,
        reactions: reactionsByMessage[message.id] ?? {},
        onReact: (emoji) => reactToMessage(message, emoji),
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

  Widget buildMessageContent(MessageModel message, bool isMyMessage) {
    if (message.type == MessageType.contact) {
      return ContactMessageWidget(
        contacts: parseContactsFromMessage(message),
        isMyMessage: isMyMessage,
      );
    }

    final mediaWidget = shared_media.buildMediaBubbleForMessage(
      message: message,
      config: buildMediaMessageConfig(message, isMyMessage),
      ref: ref,
    );
    if (mediaWidget != null) return mediaWidget;

    // Text / reply / forwarded all render as a plain text body.
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

  // ---- Messages list + media grouping ----

  Widget buildMessagesList() {
    if (displayMessages.isEmpty && !isLoading && !isInJumpMode) {
      return _buildEmptyState();
    }

    final mediaGroups = ChatHelpers.findConsecutiveMediaGroups(displayMessages);
    final groupedIndices = <int>{};
    for (final group in mediaGroups) {
      for (var i = group.startIndex; i <= group.endIndex; i++) {
        groupedIndices.add(i);
      }
    }

    return ListView.builder(
      controller: scrollController,
      reverse: true, // newest at the bottom
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount:
          displayMessages.length + (isLoadingMore && !isInJumpMode ? 1 : 0),
      physics: const ClampingScrollPhysics(),
      cacheExtent: 200,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        if (!isInJumpMode &&
            isLoadingMore &&
            index == displayMessages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (index < 0 || index >= displayMessages.length) {
          return const SizedBox.shrink();
        }
        final actualIndex = displayMessages.length - 1 - index;
        final message = displayMessages[actualIndex];

        final mediaGroup = mediaGroups.firstWhere(
          (g) => actualIndex >= g.startIndex && actualIndex <= g.endIndex,
          orElse: () => MediaGroup(startIndex: -1, endIndex: -1, messages: []),
        );

        // First message of a media group → render the grid in its place.
        if (mediaGroup.startIndex != -1 &&
            actualIndex == mediaGroup.startIndex) {
          return buildMediaGroup(mediaGroup, actualIndex);
        }

        // Subsequent messages of the same group are folded into the grid.
        if (groupedIndices.contains(actualIndex)) {
          return const SizedBox.shrink();
        }

        final isMyMessage = message.senderId == currentUserId;

        return AutoScrollTag(
          key: ValueKey(message.id),
          controller: scrollController,
          index: index,
          child: Column(
            children: [
              if (ChatHelpers.shouldShowDateSeparator(displayMessages, index))
                DateSeparator(dateTimeString: message.sentAt),
              buildMessageWithActions(message, isMyMessage),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
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

  Widget buildMediaGroup(MediaGroup group, int actualIndex) {
    if (group.messages.isEmpty) return const SizedBox.shrink();

    final firstMessage = group.messages.first;
    final isMyMessage = firstMessage.senderId == currentUserId;

    return Container(
      margin: EdgeInsets.only(
        left: isMyMessage ? 50 : 0,
        right: isMyMessage ? 0 : 50,
        bottom: 8,
      ),
      child: Column(
        crossAxisAlignment:
            isMyMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (ChatHelpers.shouldShowDateSeparator(
            displayMessages,
            displayMessages.length - 1 - actualIndex,
          ))
            DateSeparator(dateTimeString: firstMessage.sentAt),
          MediaGridWidget(
            mediaMessages: group.messages,
            isMyMessage: isMyMessage,
            onTap: (messages, index) =>
                openMediaGroupPreview(messages, index, isMyMessage),
            onCacheImage: (url, id) {
              ChatHelpers.cacheMediaForMessage(
                url: url,
                messageId: id.toString(),
                mediaCacheService: mediaCacheService,
                checkExistingCache: false,
                debugPrefix: 'media grid',
              );
            },
            videoThumbnailCache: videoThumbnailCache,
            videoThumbnailFutures: videoThumbnailFutures,
            generateVideoThumbnail: (url, _) async {
              return await generateVideoThumbnailWithCache(
                    url,
                    videoThumbnailCache,
                    videoThumbnailFutures,
                  ) ??
                  '';
            },
          ),
        ],
      ),
    );
  }

  Future<void> openMediaGroupPreview(
    List<MessageModel> messages,
    int initialIndex,
    bool isMyMessage,
  ) async {
    await openUnifiedMediaPreview(
      context: context,
      messages: messages,
      initialIndex: initialIndex,
      mediaCacheService: mediaCacheService,
      messagesRepo: messagesRepo,
      mounted: mounted,
      isMyMessage: isMyMessage,
      buildMessageStatusTicks: mediaPreviewStatusTicks,
      onRetryImage: (file, source, {MessageModel? failedMessage}) {
        sendMediaMessageToServer(file, MessageType.image);
      },
      onRetryVideo: (file, source, {MessageModel? failedMessage}) {
        sendMediaMessageToServer(file, MessageType.video);
      },
      showErrorDialog: showErrorDialog,
      starredMessages: starredMessages,
    );
  }

  // Provided by ChatScrollMixin; redeclared here so this mixin's body can
  // resolve the members without depending on that mixin explicitly. The
  // host's combined class will satisfy them.
  bool get isInJumpMode;
  List<MessageModel> get displayMessages;
}
