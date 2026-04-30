import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_service.dart';
import '../../db/repositories/conversations.repo.dart';
import '../../providers/chat.provider.dart';
import '../blurred-dialog.widget.dart';
import '../snackbar.dart';

/// Group-level destructive actions reused across the messaging screen
/// (3-dot menu) and chat-details (delete card). Centralised so the
/// confirm copy + cleanup steps stay identical in both entry points.

/// Confirms with the user, then deletes the group on the server, removes
/// the local conversation row, and clears the chat state. Returns `true`
/// when the deletion succeeded — callers typically pop their route on
/// success and surface no further UI.
///
/// [groupTitle] is shown in the confirm copy ("Delete <title>?"). Pass the
/// freshest title you have so a recently-renamed group doesn't display its
/// stale name in the dialog.
Future<bool> confirmAndDeleteGroup({
  required BuildContext context,
  required WidgetRef ref,
  required String conversationId,
  required String groupTitle,
}) async {
  final confirmed = await showBlurredConfirm(
    context: context,
    title: 'Delete and leave group?',
    message:
        'This permanently deletes "$groupTitle" and all its messages. This cannot be undone.',
    confirmLabel: 'Delete',
    cancelLabel: 'Cancel',
    destructive: true,
  );
  if (confirmed != true) return false;

  final taskId = TaskSnack.show(message: 'Deleting group…');
  try {
    final res =
        (await ApiService().group.deleteGroup(conversationId)).toMap();
    if (res['success'] == true) {
      await ConversationRepository().deleteConversation(conversationId);
      ref.read(chatProvider.notifier).removeGroupFromState(conversationId);
      TaskSnack.resolve(
        id: taskId,
        isSuccess: true,
        message: 'Group deleted',
      );
      return true;
    }
    TaskSnack.resolve(
      id: taskId,
      isSuccess: false,
      message: res['message']?.toString() ?? 'Failed to delete group',
    );
    return false;
  } catch (e) {
    TaskSnack.dismiss();
    Snack.error('Error deleting group: $e');
    return false;
  }
}
