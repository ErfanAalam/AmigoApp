import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/repositories/conversations.repo.dart';
import '../../../db/repositories/message.repo.dart';
import '../../../models/message.model.dart';
import '../../../services/media-cache.service.dart';
import '../../../ui/chat/forward-message.widget.dart';
import '../../../utils/chat/forward-message.utils.dart';
import '../../../utils/chat/preview-media.utils.dart';

/// Image / video / document preview launchers + the forward modal +
/// forward-handler glue. Shared by DM and group; both wrap the same
/// preview-media + forward-message utility functions with the same set of
/// host-supplied dependencies.
mixin ChatMediaPreviewMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  // ---- Inherited from sibling mixins / host ----
  bool get canSetState;
  void safeSetState(VoidCallback fn);
  List<MessageModel> get messages;
  String get conversationId;
  String? get currentUserId;
  Set<String> get messagesToForward;
  bool get isLoadingConversations;
  MessageRepository get messagesRepo;
  MediaCacheService get mediaCacheService;
  void showErrorDialog(String message);

  // ---- Hooks (group overrides) ----

  /// Optional `debugPrefix` forwarded to the underlying preview/cache
  /// helpers so log lines are distinguishable. Group passes
  /// `'group message'`; DM uses the default (no prefix).
  String? get mediaDebugPrefix => null;

  /// Whether image preview re-checks an existing cache entry. DMs share
  /// the same media file across the conversation pair and benefit from
  /// the existence check; groups force a fresh check (`false`) since the
  /// same URL may be cached against another conversation already.
  bool get mediaCheckExistingCache => true;

  /// Optional `debugPrefix` forwarded to `handleForwardToConversations`.
  /// Group passes `'group'`; DM omits.
  String? get forwardDebugPrefix => null;

  // ---- Methods ----

  Future<void> openImagePreviewForUrl(String imageUrl, String? caption) =>
      openImagePreview(
        context: context,
        imageUrl: imageUrl,
        caption: caption,
        messages: messages,
        mediaCacheService: mediaCacheService,
        messagesRepo: messagesRepo,
        mounted: mounted,
        checkExistingCache: mediaCheckExistingCache,
        debugPrefix: mediaDebugPrefix,
      );

  Future<void> openVideoPreviewForUrl(
    String videoUrl,
    String? caption,
    String? fileName,
  ) => openVideoPreview(
    context: context,
    videoUrl: videoUrl,
    caption: caption,
    fileName: fileName,
    messages: messages,
    mediaCacheService: mediaCacheService,
    messagesRepo: messagesRepo,
    mounted: mounted,
    onMessageUpdated: (updatedMessage) {
      final index = messages.indexWhere((m) => m.id == updatedMessage.id);
      if (index != -1 && canSetState) {
        safeSetState(() {
          messages[index] = updatedMessage;
        });
      }
    },
  );

  void openDocumentPreviewForUrl(
    String documentUrl,
    String? fileName,
    String? caption,
    int? fileSize,
  ) => openDocumentPreview(
    context: context,
    documentUrl: documentUrl,
    fileName: fileName,
    caption: caption,
    fileSize: fileSize,
  );

  /// Concretizes the `ChatActionsMixin.showForwardModal` abstract.
  Future<void> showForwardModal() async {
    final repo = ConversationRepository();
    final dmList = await repo.getAllDmsWithRecipientInfo();
    final groupList = await repo.getGroupListWithoutMembers();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => ForwardMessageModal(
        messagesToForward: messagesToForward,
        dmList: dmList,
        groupList: groupList,
        isLoading: isLoadingConversations,
        onForward: handleForwardToSelectedConversations,
        currentConversationId: conversationId,
      ),
    );
  }

  Future<void> handleForwardToSelectedConversations(
    List<String> selectedConversationIds,
  ) => handleForwardToConversations(
    HandleForwardToConversationsConfig(
      messagesToForward: messagesToForward,
      selectedConversationIds: selectedConversationIds,
      currentUserId: currentUserId ?? '',
      sourceConversationId: conversationId,
      context: context,
      mounted: mounted,
      clearMessagesToForward: (_) {
        if (canSetState) {
          safeSetState(messagesToForward.clear);
        }
      },
      showErrorDialog: showErrorDialog,
      debugPrefix: forwardDebugPrefix,
    ),
  );
}
