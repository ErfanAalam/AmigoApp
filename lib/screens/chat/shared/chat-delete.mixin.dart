import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_service.dart';
import '../../../db/repositories/message.repo.dart';
import '../../../models/message.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../services/socket/transport.manager.dart';
import '../../../types/socket.types.dart';
import '../../../ui/snackbar.dart';

/// Soft-delete pipeline shared by DM and group. Handles single + bulk
/// delete-for-everyone and (DM-only) delete-for-me. The shape across all
/// of them is identical — optimistic UI removal, soft-delete via REST,
/// provider notification, WS broadcast — so they collapse into a single
/// `deleteMessages(...)` method gated by two flags:
///
///  * `deleteForEveryone` – when true, only own messages are eligible
///    unless `isAdminOrStaff` is also true (group admins delete others'
///    messages). When false, falls through to the per-user soft-delete
///    endpoint and the WS broadcast is skipped.
///  * `isAdminOrStaff` – passed through to the REST endpoint so the
///    server allows the operation against messages the caller doesn't own.
mixin ChatDeleteMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  // ---- Inherited ----
  bool get canSetState;
  void safeSetState(VoidCallback fn);
  List<MessageModel> get messages;
  set messages(List<MessageModel> value);
  String get conversationId;
  String? get currentUserId;
  ApiService get chatApiService;
  MessageRepository get messagesRepo;
  TransportManager get transportManager;
  void sortMessagesBySentAt();

  /// Soft-delete one or more messages (default = "delete for everyone"
  /// path). When [deleteForEveryone] is `true`, the caller must own each
  /// message *or* be admin/staff; otherwise individual messages are
  /// dropped from the batch with a warning toast.
  Future<void> deleteMessages(
    List<String> messageIds, {
    bool deleteForEveryone = true,
    bool isAdminOrStaff = false,
  }) async {
    if (messageIds.isEmpty) return;

    // Eligibility filter for delete-for-everyone (skip when admin/staff —
    // admins can delete any message regardless of authorship).
    var ids = messageIds;
    if (deleteForEveryone && !isAdminOrStaff) {
      final ineligible = ids
          .where(
            (id) => messages
                .where((m) => m.id == id)
                .any((m) => m.senderId != currentUserId),
          )
          .toList();
      if (ineligible.isNotEmpty) {
        Snack.warning('You can only delete your own messages for everyone');
        ids = ids.where((id) => !ineligible.contains(id)).toList();
        if (ids.isEmpty) return;
      }
    }

    // For "delete for me", optimistically remove the message from the in-memory
    // list — it should vanish for this user only. For "delete for everyone",
    // we leave the row in place: the soft-delete write below flips
    // Messages.deletedAt and the watcher restreams it with a "this message was
    // deleted" placeholder, so removing it now would cause a brief flicker.
    if (!deleteForEveryone && canSetState) {
      safeSetState(() {
        messages.removeWhere((m) => ids.contains(m.id));
      });
    }

    try {
      // Local DB soft-delete for "for everyone" — flips Messages.deletedAt so
      // the watcher restreams the row and the UI renders the placeholder.
      // "for me" routes through MessageInfo.deletedAt below.
      if (deleteForEveryone) {
        for (final id in ids) {
          await messagesRepo.deleteMessage(id);
        }
      }

      final result = await chatApiService.chat.deleteMessage(
        ids,
        isAdminOrStaff: isAdminOrStaff ? true : null,
      );

      if (!result.isSuccess) {
        Snack.error('Failed to delete message');
        return;
      }

      final senderId = currentUserId ?? '';
      final payload = DeleteMessagePayload(
        messageIds: ids,
        convId: conversationId,
        senderId: senderId,
      );

      ref
          .read(chatProvider.notifier)
          .handleMessageDelete(payload)
          .catchError((e) => debugPrint('❌ Error deleting messages: $e'));

      if (deleteForEveryone) {
        final wsmsg = WSMessage(
          type: WSMessageType.messageDelete,
          payload: payload.toJson(),
          wsTimestamp: DateTime.now(),
        ).toJson();
        transportManager.sendMessage(wsmsg).catchError((e) {
          debugPrint('❌ Error sending message delete: $e');
          return false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      Snack.error('Failed to delete message');
    }
  }

  /// DM-only — a per-user soft-delete that hits a separate endpoint and
  /// does not broadcast on the WS. The local row is removed only after
  /// the server confirms; on error the in-memory list is rehydrated.
  Future<void> deleteMessagesForMe(List<String> messageIds) async {
    if (messageIds.isEmpty) return;

    if (canSetState) {
      safeSetState(() {
        messages.removeWhere((m) => messageIds.contains(m.id));
      });
    }

    try {
      final result = await chatApiService.chat.deleteMessageForMe(
        messageIds: messageIds,
        conversationId: conversationId,
      );
      if (result.isSuccess) {
        final uid = currentUserId;
        if (uid != null) {
          for (final id in messageIds) {
            await messagesRepo.markDeletedForMe(
              messageId: id,
              userId: uid,
              chatId: conversationId,
            );
          }
        }
      } else {
        await _rehydrateAfterFailedDelete();
      }
    } catch (e) {
      debugPrint('❌ Error deleting message for me: $e');
      await _rehydrateAfterFailedDelete();
      Snack.error('Failed to delete message');
    }
  }

  Future<void> _rehydrateAfterFailedDelete() async {
    if (!canSetState) return;
    final fromLocal = await messagesRepo.getMessagesByConversation(
      conversationId,
      limit: 100,
      offset: 0,
    );
    if (!canSetState) return;
    safeSetState(() {
      messages = fromLocal;
      sortMessagesBySentAt();
    });
  }
}
