import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_service.dart';
import '../../../db/repositories/message-status.repo.dart';
import '../../../db/repositories/message.repo.dart';
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
  // Reactive set of starred message ids for this chat — populated by the
  // host from `starredMessageIdsStreamProvider` so the bubble overlay
  // reflects SQLite truth without manual book-keeping.
  Set<String> starredMessages = <String>{};
  final Set<String> messagesToForward = {};
  MessageModel? replyToMessageData;
  bool isLoadingConversations = false;

  final MessageRepository _messageRepo = MessageRepository();

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

  Future<void> toggleStarMessage(String messageId) async {
    await _messageRepo.toggleStarMessage(messageId);
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

  Future<void> bulkStarMessages() async {
    if (selectedMessages.isEmpty) return;
    final ids = selectedMessages.toList(growable: false);
    // If every selected message is already starred, treat the action as
    // "unstar all". Otherwise star whatever isn't already starred so the
    // bulk action never has a no-op outcome.
    final allStarred = ids.every(starredMessages.contains);
    for (final id in ids) {
      if (allStarred) {
        await _messageRepo.unstarMessage(id);
      } else {
        await _messageRepo.starMessage(id);
      }
    }
    exitSelectionMode();
  }

  Future<void> bulkForwardMessages() => ChatHelpers.bulkForwardMessages(
    selectedMessages: selectedMessages,
    messagesToForward: messagesToForward,
    setState: safeSetState,
    exitSelectionMode: exitSelectionMode,
    showForwardModal: showForwardModal,
  );

  /// AppBar `actions` list rendered while selection-mode is active. DM passes
  /// no [onBulkDelete] (DM doesn't support bulk-delete from selection mode);
  /// group passes the bulk-delete callback only when the current user is
  /// admin/staff.
  List<Widget> buildSelectionModeActions({VoidCallback? onBulkDelete}) {
    return [
      IconButton(
        icon: const Icon(Icons.star_border, color: Colors.black),
        onPressed: bulkStarMessages,
        tooltip: 'Star messages',
      ),
      IconButton(
        icon: const Icon(Icons.forward, color: Colors.black),
        onPressed: bulkForwardMessages,
        tooltip: 'Forward messages',
      ),
      if (onBulkDelete != null)
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.black),
          onPressed: onBulkDelete,
          tooltip: 'Delete messages',
        ),
    ];
  }
}
