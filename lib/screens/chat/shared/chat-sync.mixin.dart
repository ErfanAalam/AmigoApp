import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api_service.dart';
import '../../../db/repositories/conversation-member.repo.dart';
import '../../../db/repositories/conversations.repo.dart';
import '../../../db/repositories/message-status.repo.dart';
import '../../../db/repositories/message.repo.dart';
import '../../../db/repositories/user.repo.dart';
import '../../../models/conversations.model.dart';
import '../../../models/message.model.dart';
import '../../../models/user.model.dart';
import '../../../providers/chat.provider.dart';
import '../../../providers/draft.provider.dart';
import '../../../services/chat-prewarm.service.dart';
import '../../../services/draft-message.service.dart';
import '../../../types/socket.types.dart';
import '../../../utils/user.utils.dart';

/// Sync / chat-init plumbing shared by DM and group messaging screens.
/// Owns the three Drift watch-streams (messages, reactions, delivery
/// statuses) plus the bookkeeping flags they drive. Lifts the chat-open
/// init flow, paginated load-more, server-side message sync, status
/// backfill, and the chronological sort.
///
/// Group-specific concerns (member fetch, removed-from-group check) are
/// pushed through two virtual hooks ([onBeforeChatInit] and
/// [onMessagesStreamUpdate]) so they run inline with the shared init
/// flow without leaking group state into this mixin.
mixin ChatSyncMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  // ---- Lifted state ----
  bool isSyncingMessages = false;
  bool hasMoreOnServer = true;
  bool isLoadingMore = false;

  /// Unread count snapshot taken when the chat was opened — captured by the
  /// host in initState before initializeChat runs (which clears the count to
  /// zero). Drives the "$N unread messages" separator pill and the
  /// scroll-to-first-unread initial scroll position.
  int unreadAtOpen = 0;

  /// ID of the oldest unread message visible at chat-open time (computed on
  /// the first non-empty messages stream emit). Cleared when the user scrolls
  /// to bottom (caught up) or the screen disposes.
  String? firstUnreadMessageId;

  /// Tracks whether the messages stream has produced its first non-empty
  /// emission. Used to gate the one-shot first-unread compute + initial scroll.
  bool _firstMessagesEmitDone = false;

  StreamSubscription<List<MessageModel>>? messagesStreamSub;
  StreamSubscription<Map<String, Map<String, dynamic>>>? reactionsSubscription;
  StreamSubscription<Map<String, MessageStatusType>>?
      deliveryStatusSubscription;

  /// Drives view-layer re-evaluation of disappearing-messages so expired rows
  /// vanish without waiting for the server's message:delete event. The actual
  /// soft-delete is applied by handleMessageDelete when the server event
  /// arrives — this timer only nudges setState so [displayMessages] re-filters.
  Timer? _disappearingTicker;

  /// Reactions emoji → [{user_id, ...}] keyed by message id. Surfaced via
  /// the Drift stream from the [MessageStatusRepository].
  Map<String, Map<String, dynamic>> reactionsByMessage = {};

  /// Per-message delivery state (sent / delivered / read / unsent / failed
  /// / uploading). Read by host status-tick builders.
  Map<String, MessageStatusType> deliveryStatusByMessage = {};

  // ---- Inherited from sibling mixins ----
  bool get canSetState;
  void safeSetState(VoidCallback fn);
  String get conversationId;
  String? get currentUserId;
  String get scrollDebugPrefix;
  List<MessageModel> get messages;
  set messages(List<MessageModel> value);
  MessageRepository get messagesRepo;
  MessageStatusRepository get messageStatusRepo;
  ApiService get chatApiService;
  TextEditingController get messageController;

  /// `_isLoading` on host — flipped to false after the first messages
  /// arrive so the empty-state placeholder gets out of the way.
  set isLoading(bool value);

  /// Pinned-message slot (read+write). Lives on `ChatActionsMixin`.
  MessageModel? get pinnedMessage;
  void setPinnedMessage(MessageModel? message);

  /// `sendConversationJoin` from ChatWebSocketMixin — fired off after the
  /// chat is initialized.
  Future<void> sendConversationJoin();

  // ---- Host-provided ----
  ConversationRepository get conversationsRepo;
  ConversationMemberRepository get conversationMemberRepo;
  UserRepository get userRepo;
  UserUtils get userUtils;

  /// `widget.dm.lastMsgId` / `widget.group.lastMsgId` — used by the
  /// gap-detection sync to know whether local is behind.
  String? get serverLatestMsgId;

  /// `ChatType.dm` / `ChatType.group` — used for `setActiveConversation`
  /// and `clearUnreadCount` provider calls.
  ChatType get conversationType;

  /// Stores the fetched current-user details on the host (where the host
  /// uses it for senderId / senderName / senderProfilePic on outgoing
  /// messages).
  void setCurrentUserDetails(UserModel? user);

  // ---- Hooks ----

  /// Fires before the per-conversation streams are set up. Group uses this
  /// to fetch members and check whether the current user has been removed.
  /// Default no-op for DM.
  Future<void> onBeforeChatInit() async {}

  /// Fires after each message-stream batch lands. Group re-checks
  /// removed-from-group state because `memberRemoved` WS events
  /// soft-delete the chat row through the chat provider. Default no-op.
  void onMessagesStreamUpdate() {}

  /// Fires after the first non-empty messages stream emit. Hosts use this to
  /// position the initial scroll (to first-unread if any, else to bottom).
  /// Default no-op so DM screens that don't override still get current behaviour.
  void onFirstMessagesEmitted() {}

  /// Compute the oldest unread message at chat-open from the most recent
  /// `unreadAtOpen` messages. Skip own messages — the divider only marks
  /// what *I* haven't read. Returns null if all unread are own messages
  /// (no separator needed) or if unreadAtOpen is 0.
  String? _computeFirstUnreadId(List<MessageModel> sortedAsc) {
    if (unreadAtOpen <= 0 || sortedAsc.isEmpty) return null;
    final start = sortedAsc.length - unreadAtOpen;
    final tail = start <= 0 ? sortedAsc : sortedAsc.sublist(start);
    for (final m in tail) {
      if (m.senderId != null && m.senderId != currentUserId) return m.id;
    }
    return null;
  }

  // ---- Methods ----

  Future<void> loadDraft() async {
    final draft = await DraftMessageService().getDraft(conversationId);
    if (draft == null || draft.isEmpty) return;
    messageController.text = draft;
    ref.read(draftMessagesProvider.notifier).saveDraft(conversationId, draft);
  }

  bool isValidPinnedMessage(MessageModel msg) {
    if (msg.id.isEmpty) return false;
    return (msg.body != null && msg.body!.isNotEmpty) ||
        msg.type != MessageType.text;
  }

  Future<void> loadPinnedMessage() async {
    final conv = await conversationsRepo.getConversationById(conversationId);
    final pinnedId = conv?.pinnedMsgId;

    if (pinnedId == null) {
      if (!canSetState) return;
      safeSetState(() => setPinnedMessage(null));
      return;
    }

    final pinned = await messagesRepo.getMessageById(pinnedId);
    if (!canSetState) return;

    if (pinned != null && isValidPinnedMessage(pinned)) {
      safeSetState(() {
        setPinnedMessage(pinned);
        // If the pinned message hasn't been streamed yet, splice it in so
        // the in-memory list matches the pinned-pill.
        if (!messages.any((msg) => msg.id == pinned.id)) {
          messages.add(pinned);
          sortMessagesBySentAt();
        }
      });
    } else {
      // Pinned message no longer exists or isn't valid — clear it.
      await conversationsRepo.updatePinnedMessage(conversationId, null);
      safeSetState(() => setPinnedMessage(null));
    }
  }

  Future<void> initializeChat() async {
    final currentUser = await userUtils.getUserDetails();
    if (currentUser != null) {
      if (!canSetState) return;
      safeSetState(() => setCurrentUserDetails(currentUser));
    }

    ref
        .read(chatProvider.notifier)
        .setActiveConversation(conversationId, conversationType);

    await onBeforeChatInit();

    // Pre-warm fast path: if the chat-list tile fired off a one-shot DB
    // read on tap, it may already be resolved by the time we get here.
    // Seed the messages list from it so the skeleton clears immediately —
    // the stream subscription below will overwrite with the same data
    // (or fresher) shortly. We don't await: a slow prewarm shouldn't
    // delay the stream subscription. Whichever resolves first wins.
    final pendingPrewarm = ChatPrewarm.takeMessages(conversationId);
    if (pendingPrewarm != null) {
      pendingPrewarm.then((prewarmed) {
        if (!canSetState) return;
        if (messages.isNotEmpty || prewarmed.isEmpty) return;
        safeSetState(() {
          messages = prewarmed;
          sortMessagesBySentAt();
          isLoading = false;
        });
      });
    }

    // 30s heartbeat so the view-layer disappearing filter re-runs even when
    // the messages stream is otherwise idle. No DB writes — just setState.
    _disappearingTicker?.cancel();
    _disappearingTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!canSetState) return;
      // Empty setState fn is fine: displayMessages reads DateTime.now() each
      // build so the predicate re-evaluates on rebuild.
      safeSetState(() {});
    });

    // Messages stream is the critical-path subscription — it drives the
    // first paint (`isLoading = false` on first emission). Subscribe now.
    messagesStreamSub?.cancel();
    messagesStreamSub = messagesRepo
        .watchMessages(conversationId, currentUserId: currentUserId)
        .listen(
      (msgs) {
        if (!canSetState) return;
        safeSetState(() {
          messages = msgs;
          sortMessagesBySentAt();
          isLoading = false;
        });
        // One-shot first-emit work: compute the first-unread anchor (if any)
        // and let the host position the initial scroll. Subsequent emits
        // just refresh the list.
        if (!_firstMessagesEmitDone && messages.isNotEmpty) {
          _firstMessagesEmitDone = true;
          final firstUnread = _computeFirstUnreadId(messages);
          if (firstUnread != null && canSetState) {
            safeSetState(() => firstUnreadMessageId = firstUnread);
          }
          onFirstMessagesEmitted();
        }
        onMessagesStreamUpdate();
      },
      onError: (e) =>
          debugPrint('$scrollDebugPrefix messages stream error: $e'),
    );

    // Reactions + delivery-status streams don't gate first paint — defer
    // them to a post-frame callback so they don't compete with the message
    // list's first layout/render. Each one emits on subscription, which
    // would otherwise cause two extra setState rounds inside initializeChat.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!canSetState) return;
      reactionsSubscription?.cancel();
      reactionsSubscription = messageStatusRepo
          .watchReactionsByConversation(conversationId)
          .listen(
            (reactions) {
              if (!canSetState) return;
              safeSetState(() => reactionsByMessage = reactions);
            },
            onError: (e) =>
                debugPrint('$scrollDebugPrefix reactions stream error: $e'),
          );

      deliveryStatusSubscription?.cancel();
      deliveryStatusSubscription = messageStatusRepo
          .watchDeliveryStatusByConversation(conversationId)
          .listen(
            (statuses) {
              if (!canSetState) return;
              safeSetState(() => deliveryStatusByMessage = statuses);
            },
            onError: (e) => debugPrint(
              '$scrollDebugPrefix delivery status stream error: $e',
            ),
          );
    });

    // Independent async work: clear unread count + load pinned. Run in
    // parallel so chat-open isn't gated on the slower of the two.
    await Future.wait([
      conversationsRepo.updateUnreadCount(conversationId, 0),
      loadPinnedMessage(),
    ]);

    ref
        .read(chatProvider.notifier)
        .clearUnreadCount(conversationId, conversationType);

    // Fire-and-forget — these shouldn't block the chat opening.
    unawaited(
      sendConversationJoin().catchError(
        (e) => debugPrint('Error joining conversation: $e'),
      ),
    );
    unawaited(
      syncMessagesFromServer().catchError(
        (e) => debugPrint('Error syncing messages: $e'),
      ),
    );
  }

  Future<void> loadMoreMessages() async {
    if (isLoadingMore || !hasMoreOnServer) return;

    safeSetState(() {
      isLoadingMore = true;
    });

    try {
      final oldestMsgId = messages.isNotEmpty ? messages.first.id : null;
      final result = await chatApiService.chat.getConversationHistory(
        conversationId: conversationId,
        beforeMessageId: oldestMsgId,
        limit: 100,
      );

      if (result.isSuccess && result.data != null) {
        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
        if (history.messages.isNotEmpty) {
          await messagesRepo.insertMessages(history.messages);
          // Drift stream fires automatically — no setState for messages needed.
          hasMoreOnServer = history.hasMore;
        } else {
          hasMoreOnServer = false;
        }
      } else {
        hasMoreOnServer = false;
      }
    } catch (e) {
      debugPrint('$scrollDebugPrefix Error loading more messages: $e');
    } finally {
      if (canSetState) {
        safeSetState(() {
          isLoadingMore = false;
        });
      }
    }
  }

  /// One-shot member fetch on first chat open. Upserts into the local
  /// chat_members + users tables so reply-preview rendering and member
  /// lookups work offline.
  Future<void> fetchAndSaveChatMembers() async {
    try {
      final result = await chatApiService.chat.getChatMembers(
        conversationId: conversationId,
      );
      if (!result.isSuccess || result.data == null) return;

      final data = result.data as Map<String, dynamic>;
      final raw = (data['members'] ?? []) as List<dynamic>;
      if (raw.isEmpty) return;

      final members = raw
          .map(
            (e) => ConversationMemberModel(
              id: e['id']?.toString(),
              chatId: conversationId,
              userId: (e['user_id'] ?? '').toString(),
              role: (e['role'] ?? 'member').toString(),
              joinedAt: e['joined_at']?.toString(),
              removedAt: e['removed_at']?.toString(),
              lastReadMsgId: e['last_read_msg_id']?.toString(),
              lastDeliveredMsgId: e['last_delivered_msg_id']?.toString(),
            ),
          )
          .toList();

      final users = raw
          .map(
            (e) => UserModel(
              id: (e['user_id'] ?? '').toString(),
              name: (e['name'] ?? '').toString(),
              phone: (e['phone'] ?? '').toString(),
              profilePic: e['profile_pic']?.toString(),
              role: e['user_role']?.toString(),
            ),
          )
          .toList();

      await conversationMemberRepo.insertOrUpdateConversationMembers(members);
      await userRepo.insertOrUpdateUsers(users);
    } catch (e) {
      debugPrint('$scrollDebugPrefix Error fetching chat members: $e');
    }
  }

  /// First open: bulk-pull up to 300 messages. Subsequent opens: only fetch
  /// the gap between local-latest and server-latest, if any.
  Future<void> syncMessagesFromServer() async {
    final needSync = await conversationsRepo.getNeedSyncStatus(conversationId);

    if (needSync == false) {
      // Subsequent open: lightweight gap check.
      final localLatestId = messages.isNotEmpty ? messages.last.id : null;
      final serverLatestId = serverLatestMsgId;

      if (localLatestId == null ||
          localLatestId == serverLatestId ||
          serverLatestId == null) {
        hasMoreOnServer = true;
        return;
      }

      debugPrint(
        '[Sync] Gap detected: local=$localLatestId server=$serverLatestId',
      );
      final gapResponse = await chatApiService.chat.getConversationHistory(
        conversationId: conversationId,
        afterMessageId: localLatestId,
        limit: 100,
      );

      if (gapResponse.isSuccess && gapResponse.data != null) {
        final gapHistory = ConversationHistoryResponse.fromJson(
          gapResponse.data as Map<String, dynamic>,
        );
        if (gapHistory.messages.isNotEmpty) {
          await messagesRepo.insertMessages(gapHistory.messages);
          debugPrint(
            '[Sync] Gap filled: ${gapHistory.messages.length} messages',
          );
        }
      }

      hasMoreOnServer = true;
      return;
    }

    // First open: chat-members one-shot, then up to 3 batches × 100 messages.
    await fetchAndSaveChatMembers();

    const firstOpenMaxBatches = 3;
    const limit = 100;
    var batch = 0;
    var hasMore = true;
    String? beforeCursor;

    if (canSetState) {
      safeSetState(() {
        isSyncingMessages = true;
      });
    }

    try {
      while (batch < firstOpenMaxBatches && hasMore && canSetState) {
        final result = await chatApiService.chat.getConversationHistory(
          conversationId: conversationId,
          beforeMessageId: beforeCursor,
          limit: limit,
        );

        if (!result.isSuccess || result.data == null) break;

        final history = ConversationHistoryResponse.fromJson(
          result.data as Map<String, dynamic>,
        );
        if (history.messages.isEmpty) break;

        await messagesRepo.insertMessages(history.messages);

        beforeCursor = history.messages.first.id;
        hasMore = history.hasMore;
        batch++;
        await Future.delayed(const Duration(milliseconds: 30));
      }

      hasMoreOnServer = hasMore;

      if (canSetState) {
        safeSetState(() {
          isSyncingMessages = false;
        });
      }

      // First-open only: backfill statuses (no local data to overwrite).
      await syncMessageStatuses();
      await conversationsRepo.updateNeedSyncStatus(conversationId, false);
    } catch (e) {
      debugPrint('❌ Error syncing messages: $e');
      if (canSetState) {
        safeSetState(() {
          isSyncingMessages = false;
        });
      }
    }
  }

  Future<void> syncMessageStatuses() async {
    try {
      var page = 1;
      const limit = 1000;
      var hasMorePages = true;

      while (hasMorePages && canSetState) {
        final result = await chatApiService.chat.getMessageStatuses(
          conversationId: conversationId,
          page: page,
          limit: limit,
        );

        if (!result.isSuccess || result.data == null) break;

        final statusesData = result.data as Map<String, dynamic>;
        final statuses = (statusesData['statuses'] ?? []) as List<dynamic>;
        if (statuses.isEmpty) break;

        debugPrint('[StatusSync] Sample status: ${statuses.first}');

        // Drizzle returns camelCase; older responses used snake_case. Accept
        // both so a backend version skew doesn't drop status rows.
        final statusesToInsert = statuses.map((status) {
          return <String, dynamic>{
            'id': status['id'],
            'conversationId':
                status['chatId'] ?? status['chat_id'] ?? status['conv_id'],
            'messageId': status['messageId'] ?? status['message_id'],
            'userId': status['userId'] ?? status['user_id'],
            'deliveredAt': status['deliveredAt'] ?? status['delivered_at'],
            'readAt': status['readAt'] ?? status['read_at'],
            'reaction': status['reaction'],
          };
        }).toList();

        await messageStatusRepo.insertMessageStatuses(statusesToInsert);

        final pagination =
            statusesData['pagination'] as Map<String, dynamic>?;
        hasMorePages = (pagination?['hasNextPage'] as bool?) ?? false;
        page++;

        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      debugPrint('❌ Error syncing message statuses: $e');
      // Don't fail the entire sync if status sync fails.
    }
  }

  void sortMessagesBySentAt() {
    messages.sort((a, b) {
      try {
        return DateTime.parse(a.sentAt).compareTo(DateTime.parse(b.sentAt));
      } catch (_) {
        return a.sentAt.compareTo(b.sentAt);
      }
    });
  }

  void disposeSync() {
    messagesStreamSub?.cancel();
    reactionsSubscription?.cancel();
    deliveryStatusSubscription?.cancel();
    _disappearingTicker?.cancel();
  }
}
