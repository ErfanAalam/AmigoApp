import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/repositories/message.repo.dart';
import '../../../db/repositories/user.repo.dart';
import '../../../models/message.model.dart';
import '../../../providers/theme-color.provider.dart';
import '../../../types/socket.types.dart';
import '../../../ui/chat/contact-message.widget.dart';
import '../../../ui/chat/emoji-reaction.widget.dart';
import '../../../ui/chat/media-messages.widget.dart';
import '../../../ui/chat/message.widget.dart';
import '../../../utils/chat/chat-helpers.utils.dart';
import 'media-message-config.builder.dart' as shared_media;

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
}
