import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_service.dart';
import '../../../db/repositories/message-status.repo.dart';
import '../../../models/message.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../utils/chat/chat-helpers.utils.dart';

/// Selection / reply / forward / pin / star / react actions shared by DM and
/// group messaging screens. State for the selection set, star set, forward
/// queue, reply target, and the "loading conversations" flag for the forward
/// modal lives here. Conversation-shaped data (id, current user, repos,
/// pinned message slot, reactions) is supplied by the host via abstract
/// hooks so the mixin stays free of DM/group conditionals.
mixin ChatActionsMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final Set<String> selectedMessages = {};
  final Set<String> starredMessages = {};
  final Set<String> messagesToForward = {};
  MessageModel? replyToMessageData;
  bool isLoadingConversations = false;

  // Star feature is dropped on the backend. Keep the toggle reachable behind
  // a compile-time flag so it can be restored without restructuring this mixin.
  static const bool _starEnabled = false;

  bool get canSetState;
  void safeSetState(VoidCallback fn);
  FocusNode get messageFocusNode;

  String get conversationId;
  String? get currentUserId;
  String? get currentUserName;
  MessageStatusRepository get messageStatusRepo;
  ApiService get chatApiService;

  MessageModel? get pinnedMessage;
  void setPinnedMessage(MessageModel? message);

  Map<String, Map<String, dynamic>> get reactionsByMessage;

  /// Host opens the forward modal. The modal needs widget-specific values
  /// (DM vs. group conversation id, debug prefix) that aren't worth pushing
  /// through abstracts, so the host owns the implementation.
  Future<void> showForwardModal();

  void toggleMessageSelection(String messageId) {
    if (!canSetState) return;
    safeSetState(() {
      if (selectedMessages.contains(messageId)) {
        selectedMessages.remove(messageId);
      } else {
        selectedMessages.add(messageId);
      }
    });
  }

  void exitSelectionMode() {
    if (!canSetState) return;
    safeSetState(() {
      selectedMessages.clear();
    });
  }

  void enterSelectionMode(String messageId) {
    if (!canSetState) return;
    safeSetState(() {
      selectedMessages.add(messageId);
    });
  }

  Future<void> togglePinMessage(MessageModel message) async {
    final messageId = message.id;
    final pinnedMessageId = pinnedMessage?.id;
    final wasPinned = messageId == pinnedMessageId && pinnedMessage != null;
    final newPinnedMessageId = wasPinned ? null : message.id;

    if (!canSetState) return;
    safeSetState(() {
      setPinnedMessage(wasPinned ? null : message);
    });

    await ChatHelpers.togglePinMessage(
      message: message,
      conversationId: conversationId,
      currentPinnedMessageId: pinnedMessageId,
      setPinnedMessageId: (value) {
        if (canSetState) {
          setPinnedMessage(value);
        }
      },
      currentUserId: currentUserId,
      setState: safeSetState,
    );

    ref
        .read(chatProvider.notifier)
        .updatePinnedMessageInState(conversationId, newPinnedMessageId);
  }

  void toggleStarMessage(String messageId) {
    if (_starEnabled) {
      /* star disabled */
    }
  }

  Future<void> reactToMessage(MessageModel message, String emoji) async {
    final userId = currentUserId;
    if (userId == null) return;

    final msgReactions = reactionsByMessage[message.id] ?? {};
    final emojiUsers =
        (msgReactions[emoji] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];
    final alreadyReacted = emojiUsers.any(
      (u) => u['user_id']?.toString() == userId,
    );
    final action = alreadyReacted ? 'remove' : 'add';

    await messageStatusRepo.upsertReaction(
      messageId: message.id,
      userId: userId,
      chatId: conversationId,
      emoji: action == 'add' ? emoji : null,
    );

    try {
      await chatApiService.chat.reactToMessage(
        messageId: message.id,
        conversationId: conversationId,
        emoji: emoji,
        action: action,
        senderName: currentUserName ?? '',
      );
    } catch (e) {
      debugPrint('❌ Failed to send reaction: $e');
    }
  }

  void replyToMessage(MessageModel message) {
    if (!canSetState) return;
    safeSetState(() {
      replyToMessageData = message;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (canSetState) messageFocusNode.requestFocus();
    });
  }

  void cancelReply() {
    if (!canSetState) return;
    safeSetState(() {
      replyToMessageData = null;
    });
  }

  Future<void> forwardMessage(MessageModel message) async {
    if (canSetState) {
      safeSetState(() {
        messagesToForward.clear();
        messagesToForward.add(message.id);
      });
    }
    await showForwardModal();
  }
}
