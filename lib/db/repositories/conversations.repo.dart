import 'package:amigo/models/conversations.model.dart';
import 'package:drift/drift.dart';
import '../../models/group.model.dart';
import '../../types/socket.types.dart';
import '../../utils/user.utils.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';
import 'conversation-member.repo.dart';

/// Helper function to get preview text for media messages
String _getMessagePreviewText(
  String? messageType,
  String? body,
  Map<String, dynamic>? attachments,
) {
  // If body exists and is not empty, use it
  if (body != null && body.isNotEmpty) {
    return body;
  }

  // Generate preview text based on message type
  if (messageType != null && messageType.isNotEmpty) {
    switch (messageType) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
        return '🎵 Audio';
      case 'document':
        return '📄 Document';
      case 'attachment':
        return '📎 Attachment';
      case 'reply':
        return '↩️ Reply';
      case 'forwarded':
        return '↪️ Forwarded';
      default:
        break;
    }
  }

  // Fallback: check attachments to determine media type
  if (attachments != null && attachments.isNotEmpty) {
    final attachmentType =
        attachments['type']?.toString().toLowerCase() ??
        attachments['mimeType']?.toString().toLowerCase() ??
        '';

    if (attachmentType.contains('image')) return '📷 Photo';
    if (attachmentType.contains('video')) return '🎥 Video';
    if (attachmentType.contains('audio')) return '🎵 Audio';
    if (attachmentType.contains('pdf') || attachmentType.contains('document')) {
      return '📄 Document';
    }
    return '📎 Attachment';
  }

  return '';
}

class ConversationRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  /// Helper method to convert Chats row to ChatModel
  Future<ConversationModel> _conversationToModel(Chat conv) async {
    return ConversationModel(
      id: conv.id,
      type: conv.type,
      title: conv.title,
      profilePic: conv.profilePic,
      createrId: conv.createrId,
      lastMsgId: conv.lastMsgId,
      lastMsgAt: conv.lastMsgAt,
      pinnedMsgId: conv.pinnedMsgId,
      unreadCount: conv.unreadCount,
      deletedAt: conv.deletedAt,
      pinnedAt: conv.pinnedAt,
      mutedUntil: conv.mutedUntil,
      isFavorite: conv.isFavorite,
      createdAt: conv.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: conv.updatedAt,
      needSync: conv.needSync,
      disappearingAfterSec: conv.disappearingAfterSec,
    );
  }

  /// Set or clear the disappearing-messages duration on a conversation.
  /// Idempotent — called from the conversation:disappearing WS handler.
  Future<void> setDisappearingAfterSec(String chatId, int? durationSec) async {
    final db = sqliteDatabase.database;
    await (db.update(db.chats)..where((t) => t.id.equals(chatId))).write(
      ChatsCompanion(disappearingAfterSec: Value(durationSec)),
    );
  }

  /// Patch the title on a chat row. Drift watchers re-emit, so subscribed
  /// AppBars / list rows redraw without an explicit refresh.
  Future<void> updateChatTitle(String chatId, String title) async {
    final db = sqliteDatabase.database;
    await (db.update(db.chats)..where((t) => t.id.equals(chatId))).write(
      ChatsCompanion(title: Value(title)),
    );
  }

  /// Patch the profile pic on a chat row. Pass null to clear it. Drift
  /// watchers re-emit, so subscribed AppBars / list rows redraw.
  Future<void> updateChatProfilePic(String chatId, String? profilePic) async {
    final db = sqliteDatabase.database;
    await (db.update(db.chats)..where((t) => t.id.equals(chatId))).write(
      ChatsCompanion(profilePic: Value(profilePic)),
    );
  }

  /// Reactive single-row watcher for a chat — emits on every change to the
  /// row so AppBars (group-list, group-messaging, chat-details) auto-rebuild
  /// when chat_details:update applies new title/profilePic to local DB.
  Stream<Chat?> watchChatById(String chatId) {
    final db = sqliteDatabase.database;
    return (db.select(db.chats)..where((t) => t.id.equals(chatId)))
        .watchSingleOrNull();
  }

  /// Bulk insert conversations atomically. Uses InsertMode.insertOrIgnore so
  /// re-inserting an existing chat row preserves the user's local-only flags
  /// (pinnedAt/mutedUntil/isFavorite) instead of being clobbered by server data
  /// that doesn't carry them. db.batch wraps the whole thing in one
  /// transaction → one Drift watch emit, no partial loads, no per-row throws.
  Future<void> insertConversations(
    List<ConversationModel> conversations,
  ) async {
    if (conversations.isEmpty) return;
    final db = sqliteDatabase.database;

    await db.batch((b) {
      for (final conv in conversations) {
        final convCompanion = ChatsCompanion.insert(
          id: conv.id,
          type: conv.type,
          title: Value(conv.title),
          profilePic: Value(conv.profilePic),
          createrId: Value(conv.createrId),
          lastMsgId: Value(conv.lastMsgId),
          lastMsgAt: Value(conv.lastMsgAt),
          pinnedMsgId: Value(conv.pinnedMsgId),
          unreadCount: Value(conv.unreadCount ?? 0),
          createdAt: Value(conv.createdAt),
          deletedAt: Value(conv.deletedAt),
          pinnedAt: Value(conv.pinnedAt),
          mutedUntil: Value(conv.mutedUntil),
          isFavorite: Value(conv.isFavorite),
          updatedAt: Value(conv.updatedAt),
          disappearingAfterSec: Value(conv.disappearingAfterSec),
        );
        b.insert(db.chats, convCompanion, mode: InsertMode.insertOrIgnore);
      }
    });
  }

  // Get All members by conversation id with thier details from users table

  /// Get all conversations
  Future<List<ConversationModel>> getAllConversations() async {
    final db = sqliteDatabase.database;

    final query = db.select(db.chats)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);

    final conversations = await query.get();

    final result = <ConversationModel>[];
    for (final conv in conversations) {
      result.add(await _conversationToModel(conv));
    }

    return result;
  }

  /// Get all conversation IDs
  /// If [type] is provided, returns only IDs for that conversation type
  /// If [type] is null, returns all conversation IDs
  Future<List<String>> getAllConversationIds({ChatType? type}) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.chats);

    if (type != null) {
      query.where((t) => t.type.equals(type.value));
    }

    final conversations = await query.get();

    return conversations.map((conv) => conv.id).toList();
  }

  /// Clear all conversations from the database
  Future<void> clearAllConversations() async {
    final db = sqliteDatabase.database;
    await db.delete(db.chats).go();
  }

  /// Update a conversation
  Future<void> updateConversation(ConversationModel conversation) async {
    final db = sqliteDatabase.database;

    final companion = ChatsCompanion(
      id: Value(conversation.id),
      type: Value(conversation.type),
      title: Value(conversation.title),
      profilePic: Value(conversation.profilePic),
      createrId: Value(conversation.createrId),
      lastMsgId: Value(conversation.lastMsgId),
      lastMsgAt: Value(conversation.lastMsgAt),
      pinnedMsgId: Value(conversation.pinnedMsgId),
      unreadCount: Value(conversation.unreadCount ?? 0),
      createdAt: Value(conversation.createdAt),
      deletedAt: Value(conversation.deletedAt),
      pinnedAt: Value(conversation.pinnedAt),
      mutedUntil: Value(conversation.mutedUntil),
      isFavorite: Value(conversation.isFavorite),
      updatedAt: Value(
        conversation.updatedAt ?? DateTime.now().toIso8601String(),
      ),
      needSync: Value(conversation.needSync),
      disappearingAfterSec: Value(conversation.disappearingAfterSec),
    );

    await db.update(db.chats).replace(companion);
  }

  /// Get a conversation by ID
  Future<ConversationModel?> getConversationById(String conversationId) async {
    final db = sqliteDatabase.database;

    final conv = await (db.select(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    if (conv == null) return null;

    return await _conversationToModel(conv);
  }

  /// Get conversation type by ID
  Future<String?> getConversationTypeById(String conversationId) async {
    final db = sqliteDatabase.database;

    final conv = await (db.select(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    return conv?.type;
  }

  /// Get conversations by type (dm, group, etc.)
  Future<List<ConversationModel>> getConversationsByType(ChatType type) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.chats)
      ..where((t) => t.type.equals(type.value))
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);

    final conversations = await query.get();

    final result = <ConversationModel>[];
    for (final conv in conversations) {
      result.add(await _conversationToModel(conv));
    }

    return result;
  }

  /// Delete a conversation by ID
  Future<bool> deleteConversation(String conversationId) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).go();
    return deleted > 0;
  }

  /// Mark a conversation as soft-deleted (sets deletedAt).
  /// Used when the current user is removed from a group.
  Future<void> softDeleteConversation(String conversationId) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).write(
      ChatsCompanion(
        deletedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );
  }

  /// Update unread count for a conversation
  Future<void> updateUnreadCount(String conversationId, int unreadCount) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).write(
      ChatsCompanion(
        unreadCount: Value(unreadCount),
        // Do NOT touch updatedAt here — marking as read must not change
        // the list sort position. Only new-message writes should do that.
      ),
    );
  }

  /// Update pinnedMsgId for a conversation
  Future<void> updatePinnedMessage(
    String conversationId,
    String? pinnedMsgId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).write(
      ChatsCompanion(
        pinnedMsgId: Value(pinnedMsgId),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Reconcile the in-chat pinned-message id from an authoritative server
  /// sync. insertConversations uses insertOrIgnore + a new-rows-only filter, so
  /// an *existing* chat's pinnedMsgId is never refreshed there — a pin/unpin
  /// that happened while this client was offline (or whose WS event was missed)
  /// would otherwise never surface. Like updateUnreadCount, this deliberately
  /// does NOT touch updatedAt: pinnedMsgId is the message pinned *inside* the
  /// chat, unrelated to chat-list sort, and bumping updatedAt would reshuffle
  /// the list on every sync.
  Future<void> setPinnedMsgIdFromSync(
    String conversationId,
    String? pinnedMsgId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).write(
      ChatsCompanion(pinnedMsgId: Value(pinnedMsgId)),
    );
  }

  /// Mark conversation as read (set unread count to 0)
  Future<void> markAsRead(String conversationId) async {
    await updateUnreadCount(conversationId, 0);
  }

  /// Toggle pin status of a conversation. Stamps pinnedAt with now() to pin
  /// (which also drives the pinned-list ordering — most-recently-pinned wins),
  /// or nulls it out to unpin. Does NOT touch updatedAt, since pinning must
  /// not promote a chat in the activity-sorted unpinned list.
  Future<void> togglePin(String conversationId, bool isPinned) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).write(
      ChatsCompanion(
        pinnedAt: Value(
          isPinned ? DateTime.now().toUtc().toIso8601String() : null,
        ),
      ),
    );
  }

  /// Write the local mirror of muted_until for a conversation. The server is
  /// the source of truth — callers must persist via the /chat/mute or
  /// /chat/unmute API first and only land this row on success. Pass null to
  /// clear the mute. Does NOT touch updatedAt: muting is not "activity" and
  /// must not promote the chat in the list ordering.
  Future<void> setLocalMutedUntil(
    String conversationId,
    String? mutedUntilIso,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).write(
      ChatsCompanion(mutedUntil: Value(mutedUntilIso)),
    );
  }

  /// Toggle favorite status of a conversation
  Future<void> toggleFavorite(String conversationId, bool isFavorite) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).write(
      ChatsCompanion(
        isFavorite: Value(isFavorite),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Get pinned conversations, ordered with most-recently-pinned first.
  Future<List<ConversationModel>> getPinnedConversations() async {
    final db = sqliteDatabase.database;

    final query = db.select(db.chats)
      ..where((t) => t.pinnedAt.isNotNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.pinnedAt, mode: OrderingMode.desc),
      ]);

    final conversations = await query.get();

    final result = <ConversationModel>[];
    for (final conv in conversations) {
      result.add(await _conversationToModel(conv));
    }

    return result;
  }

  /// Get favorite conversations
  Future<List<ConversationModel>> getFavoriteConversations() async {
    final db = sqliteDatabase.database;

    final query = db.select(db.chats)
      ..where((t) => t.isFavorite.equals(true))
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      ]);

    final conversations = await query.get();

    final result = <ConversationModel>[];
    for (final conv in conversations) {
      result.add(await _conversationToModel(conv));
    }

    return result;
  }

  /// Update last message info for a conversation
  Future<void> updateLastMessage(
    String conversationId,
    String lastMsgId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).write(
      ChatsCompanion(
        lastMsgId: Value(lastMsgId),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  // update last message id only
  Future<void> updateLastMessageId(
    String conversationId,
    String lastMsgId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(db.chats)
          ..where((t) => t.id.equals(conversationId)))
        .write(ChatsCompanion(lastMsgId: Value(lastMsgId)));
  }

  /// Watch DM conversations as a reactive Drift stream ordered by last activity.
  /// Emits whenever the chats table changes (e.g. new message updates
  /// lastMsgId). Joins users/members asynchronously per emission.
  ///
  /// [currentUserId] is used to exclude the current user from the DM's
  /// member list when picking the "recipient". Without it, if chat_members
  /// contains both current user and recipient, the wrong user could be
  /// picked as the recipient → DM list shows your own name instead.
  Stream<List<DmModel>> watchDmConversations({String? currentUserId}) {
    final db = sqliteDatabase.database;

    return (db.select(db.chats)
          // Only surface DMs that have at least one message — empty chats
          // (e.g. stale rows from the old "create-dm-on-contact-tap" flow,
          // or chats the recipient created but never sent in) stay hidden
          // from the list until the first message lands.
          ..where(
            (t) =>
                t.type.equals('dm') &
                t.deletedAt.isNull() &
                t.lastMsgId.isNotNull(),
          )
          // pinnedAt DESC NULLS LAST keeps pinned chats on top, ordered by
          // most-recently-pinned first; non-pinned chats (NULL) fall through
          // to the activity tie-breakers below. A new message bumps updatedAt
          // but never reshuffles pinned rows, since their pinnedAt is set and
          // stable until the user unpins.
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.pinnedAt,
              mode: OrderingMode.desc,
              nulls: NullsOrder.last,
            ),
            (t) => OrderingTerm(
              expression: t.updatedAt,
              mode: OrderingMode.desc,
            ),
            (t) => OrderingTerm(
              expression: t.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch()
        .asyncMap((conversations) async {
          final result = <DmModel>[];
          for (final conv in conversations) {
            final members = await (db.select(db.chatMembers)
                  ..where(
                    (t) =>
                        t.chatId.equals(conv.id) &
                        t.removedAt.isNull(),
                  ))
                .get();
            if (members.isEmpty) continue;

            // Pick the first non-current-user member as the "recipient".
            String? recipientUserId;
            for (final m in members) {
              if (currentUserId == null || m.userId != currentUserId) {
                recipientUserId = m.userId;
                break;
              }
            }
            if (recipientUserId == null) continue;

            final recipientUser = await (db.select(db.users)
                  ..where((t) => t.id.equals(recipientUserId!)))
                .getSingleOrNull();
            if (recipientUser == null) continue;

            // Contact name from the local address book wins over the server
            // name in the DM list — see UserRepository for the canonical join.
            final recipientContact = await (db.select(db.contacts)
                  ..where((t) => t.id.equals(recipientUser.id)))
                .getSingleOrNull();

            String? lastMessageType;
            String? lastMessageBody;
            String? lastMessageAt;
            String? lastMsgId = conv.lastMsgId;

            if (conv.lastMsgId != null) {
              final lastMessage = await (db.select(db.messages)
                    ..where((t) => t.id.equals(conv.lastMsgId!)))
                  .getSingleOrNull();
              if (lastMessage != null) {
                lastMessageType = lastMessage.type;
                lastMessageBody = _getMessagePreviewText(
                  lastMessage.type,
                  lastMessage.body,
                  lastMessage.attachments,
                );
                lastMessageAt = lastMessage.sentAt;
                lastMsgId = lastMessage.id;
              }
            }

            result.add(DmModel(
              chatId: conv.id,
              recipientId: recipientUser.id,
              recipientName: recipientContact?.name ?? recipientUser.name,
              recipientPhone: recipientUser.phone,
              recipientProfilePic: recipientUser.profilePic,
              pinnedMsgId: conv.pinnedMsgId,
              lastMsgId: lastMsgId,
              lastMsgType: lastMessageType,
              lastMsgBody: lastMessageBody,
              lastMsgAt: lastMessageAt,
              unreadCount: conv.unreadCount,
              isRecipientOnline: recipientUser.isOnline,
              deletedAt: conv.deletedAt,
              pinnedAt: conv.pinnedAt,
              mutedUntil: conv.mutedUntil,
              isFavorite: conv.isFavorite,
              createdAt: conv.createdAt ?? DateTime.now().toIso8601String(),
              disappearingAfterSec: conv.disappearingAfterSec,
            ));
          }
          return result;
        });
  }

  /// Watch group conversations as a reactive Drift stream ordered by last activity.
  Stream<List<GroupModel>> watchGroupConversations() {
    final db = sqliteDatabase.database;

    return (db.select(db.chats)
          ..where((t) => t.type.equals('group'))
          // See watchDmConversations for the pinnedAt-first ordering rationale.
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.pinnedAt,
              mode: OrderingMode.desc,
              nulls: NullsOrder.last,
            ),
            (t) => OrderingTerm(
              expression: t.updatedAt,
              mode: OrderingMode.desc,
            ),
            (t) => OrderingTerm(
              expression: t.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .watch()
        .asyncMap((conversations) async {
          final currentUserInfo = await UserUtils().getUserDetails();
          final result = <GroupModel>[];

          for (final conv in conversations) {
            String? lastMessageType;
            String? lastMessageBody;
            String? lastMessageAt;
            String? lastMessageSenderName;
            String? lastMsgId = conv.lastMsgId;

            if (conv.lastMsgId != null) {
              final lastMessage = await (db.select(db.messages)
                    ..where((t) => t.id.equals(conv.lastMsgId!)))
                  .getSingleOrNull();
              if (lastMessage != null) {
                lastMessageType = lastMessage.type;
                lastMessageBody = _getMessagePreviewText(
                  lastMessage.type,
                  lastMessage.body,
                  lastMessage.attachments,
                );
                lastMessageAt = lastMessage.sentAt;
                lastMsgId = lastMessage.id;

                // Resolve sender display name for the "Aman: hi" prefix the
                // group list shows. Current user resolves to "You" so the row
                // matches WhatsApp's familiar convention.
                final senderId = lastMessage.senderId;
                if (senderId != null && senderId.isNotEmpty) {
                  if (currentUserInfo != null &&
                      senderId == currentUserInfo.id) {
                    lastMessageSenderName = 'You';
                  } else {
                    final senderUser = await (db.select(db.users)
                          ..where((t) => t.id.equals(senderId)))
                        .getSingleOrNull();
                    final senderContact = await (db.select(db.contacts)
                          ..where((t) => t.id.equals(senderId)))
                        .getSingleOrNull();
                    final fullName =
                        senderContact?.name ?? senderUser?.name;
                    // Show only the first whitespace-separated word so the
                    // list prefix stays short ("Aman: hi" instead of
                    // "Aman Kumar Sharma: hi"). trim() first so a leading
                    // space doesn't produce an empty first segment.
                    lastMessageSenderName =
                        fullName?.trim().split(RegExp(r'\s+')).first;
                  }
                }
              }
            }

            ConversationMemberModel? currentUserMemberInfo;
            if (currentUserInfo != null) {
              currentUserMemberInfo = await ConversationMemberRepository()
                  .getMemberByConversationAndUser(conv.id, currentUserInfo.id);
            }

            result.add(GroupModel(
              chatId: conv.id,
              title: conv.title ?? 'Group Chat',
              profilePic: conv.profilePic,
              pinnedMsgId: conv.pinnedMsgId,
              lastMsgId: lastMsgId,
              lastMsgType: lastMessageType,
              lastMsgBody: lastMessageBody,
              lastMsgAt: lastMessageAt,
              lastMsgSenderName: lastMessageSenderName,
              role: currentUserMemberInfo?.role,
              unreadCount: conv.unreadCount ?? 0,
              pinnedAt: conv.pinnedAt,
              mutedUntil: conv.mutedUntil,
              isFavorite: conv.isFavorite,
              joinedAt: currentUserMemberInfo?.joinedAt ??
                  DateTime.now().toIso8601String(),
              disappearingAfterSec: conv.disappearingAfterSec,
            ));
          }
          return result;
        });
  }

  /// get need sync from conversation id
  Future<bool> getNeedSyncStatus(String conversationId) async {
    final db = sqliteDatabase.database;

    final conv = await (db.select(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    if (conv == null) return false;

    return conv.needSync;
  }

  // update need sync status
  Future<void> updateNeedSyncStatus(
    String conversationId,
    bool needSync,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).write(
      ChatsCompanion(
        needSync: Value(needSync),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  // Get all DMs by type with recipient info and last message details
  Future<List<DmModel>> getAllDmsWithRecipientInfo() async {
    final db = sqliteDatabase.database;

    // Query conversations by type
    final conversations =
        await (db.select(db.chats)
              ..where((t) => t.type.equals('dm'))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final result = <DmModel>[];

    for (final conv in conversations) {
      // Get chat members
      final members =
          await (db.select(db.chatMembers)..where(
                (t) => t.chatId.equals(conv.id) & t.removedAt.isNull(),
              ))
              .get();

      // Skip if no members found
      if (members.isEmpty) {
        continue;
      }

      // Get recipient user info
      final recipientUser = await (db.select(
        db.users,
      )..where((t) => t.id.equals(members[0].userId))).getSingleOrNull();

      if (recipientUser == null) {
        // Skip if recipient user not found
        continue;
      }

      // Local-contact name override; see watchDmConversations for rationale.
      final recipientContact = await (db.select(
        db.contacts,
      )..where((t) => t.id.equals(recipientUser.id))).getSingleOrNull();

      // Get last message details if lastMsgId exists
      String? lastMessageType;
      String? lastMessageBody;
      String? lastMessageAt;
      String? lastMsgId = conv.lastMsgId;

      if (conv.lastMsgId != null) {
        final lastMessage =
            await (db.select(db.messages)
                  ..where((t) => t.id.equals(conv.lastMsgId!)))
                .getSingleOrNull();

        if (lastMessage != null) {
          lastMessageType = lastMessage.type;
          // Use helper to get preview text - handles media messages with empty body
          lastMessageBody = _getMessagePreviewText(
            lastMessage.type,
            lastMessage.body,
            lastMessage.attachments,
          );
          lastMessageAt = lastMessage.sentAt;
          lastMsgId = lastMessage.id;
        }
      }

      // Create DmListModel
      final dmModel = DmModel(
        chatId: conv.id,
        recipientId: recipientUser.id,
        recipientName: recipientContact?.name ?? recipientUser.name,
        recipientPhone: recipientUser.phone,
        recipientProfilePic: recipientUser.profilePic,
        pinnedMsgId: conv.pinnedMsgId,
        lastMsgId: lastMsgId,
        lastMsgType: lastMessageType,
        lastMsgBody: lastMessageBody,
        lastMsgAt: lastMessageAt,
        unreadCount: conv.unreadCount,
        isRecipientOnline: recipientUser.isOnline,
        deletedAt: conv.deletedAt,
        pinnedAt: conv.pinnedAt,
        mutedUntil: conv.mutedUntil,
        isFavorite: conv.isFavorite,
        createdAt: conv.createdAt ?? DateTime.now().toIso8601String(),
        disappearingAfterSec: conv.disappearingAfterSec,
      );

      result.add(dmModel);
    }

    return result;
  }

  // Get DM by conversation ID with recipient info and last message details
  Future<DmModel?> getDmByConversationId(String conversationId) async {
    final db = sqliteDatabase.database;

    // Query conversation by ID
    final conv = await (db.select(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    if (conv == null || conv.type != 'dm') {
      return null;
    }

    // Get chat members
    final members =
        await (db.select(db.chatMembers)..where(
              (t) => t.chatId.equals(conv.id) & t.removedAt.isNull(),
            ))
            .get();

    // Return null if no valid recipient found
    if (members.isEmpty) {
      return null;
    }

    // Get recipient user info
    final recipientUser = await (db.select(
      db.users,
    )..where((t) => t.id.equals(members[0].userId))).getSingleOrNull();

    if (recipientUser == null) {
      return null;
    }

    // Local-contact name override; see watchDmConversations for rationale.
    final recipientContact = await (db.select(
      db.contacts,
    )..where((t) => t.id.equals(recipientUser.id))).getSingleOrNull();

    // Get last message details if lastMsgId exists
    String? lastMessageType;
    String? lastMessageBody;
    String? lastMessageAt;
    String? lastMsgId = conv.lastMsgId;

    if (conv.lastMsgId != null) {
      final lastMessage =
          await (db.select(db.messages)
                ..where((t) => t.id.equals(conv.lastMsgId!)))
              .getSingleOrNull();

      if (lastMessage != null) {
        lastMessageType = lastMessage.type;
        lastMessageBody = _getMessagePreviewText(
          lastMessage.type,
          lastMessage.body,
          lastMessage.attachments,
        );
        lastMessageAt = lastMessage.sentAt;
        lastMsgId = lastMessage.id;
      }
    }

    // Create and return DmModel
    return DmModel(
      chatId: conv.id,
      recipientId: recipientUser.id,
      recipientName: recipientContact?.name ?? recipientUser.name,
      recipientPhone: recipientUser.phone,
      recipientProfilePic: recipientUser.profilePic,
      pinnedMsgId: conv.pinnedMsgId,
      lastMsgId: lastMsgId,
      lastMsgType: lastMessageType,
      lastMsgBody: lastMessageBody,
      lastMsgAt: lastMessageAt,
      unreadCount: conv.unreadCount,
      isRecipientOnline: recipientUser.isOnline,
      deletedAt: conv.deletedAt,
      pinnedAt: conv.pinnedAt,
      mutedUntil: conv.mutedUntil,
      isFavorite: conv.isFavorite,
      createdAt: conv.createdAt ?? DateTime.now().toIso8601String(),
      disappearingAfterSec: conv.disappearingAfterSec,
    );
  }

  /// Look up an existing DM whose only non-current-user member is
  /// [recipientUserId]. Returns null if no such chat exists locally.
  /// Used by the contact-tap flow to skip create-dm when the user already
  /// has a chat with the tapped contact.
  Future<DmModel?> getDmByRecipientUserId(String recipientUserId) async {
    final db = sqliteDatabase.database;
    final memberRows = await (db.select(db.chatMembers)
          ..where(
            (t) => t.userId.equals(recipientUserId) & t.removedAt.isNull(),
          ))
        .get();
    for (final m in memberRows) {
      final dm = await getDmByConversationId(m.chatId);
      if (dm != null && dm.recipientId == recipientUserId) {
        return dm;
      }
    }
    return null;
  }

  // get group list
  Future<List<GroupModel>> getGroupListWithoutMembers() async {
    final db = sqliteDatabase.database;

    final currentUserInfo = await UserUtils().getUserDetails();

    // Query conversations by type
    final conversations =
        await (db.select(db.chats)
              ..where((t) => t.type.equals('group'))
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.updatedAt,
                  mode: OrderingMode.desc,
                ),
                (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final result = <GroupModel>[];

    for (final conv in conversations) {
      // Get last message details if lastMsgId exists
      String? lastMessageType;
      String? lastMessageBody;
      String? lastMessageAt;
      String? lastMsgId = conv.lastMsgId;

      if (conv.lastMsgId != null) {
        final lastMessage =
            await (db.select(db.messages)
                  ..where((t) => t.id.equals(conv.lastMsgId!)))
                .getSingleOrNull();

        if (lastMessage != null) {
          lastMessageType = lastMessage.type;
          // Use helper to get preview text - handles media messages with empty body
          lastMessageBody = _getMessagePreviewText(
            lastMessage.type,
            lastMessage.body,
            lastMessage.attachments,
          );
          lastMessageAt = lastMessage.sentAt;
          lastMsgId = lastMessage.id;
        }
      }

      ConversationMemberModel? currentUserMemberInfo;
      if (currentUserInfo != null) {
        currentUserMemberInfo = await ConversationMemberRepository()
            .getMemberByConversationAndUser(conv.id, currentUserInfo.id);
      }

      // Create DmListModel
      final groupModel = GroupModel(
        chatId: conv.id,
        title: conv.title ?? 'Group Chat',
        profilePic: conv.profilePic,
        pinnedMsgId: conv.pinnedMsgId,
        lastMsgId: lastMsgId,
        lastMsgType: lastMessageType,
        lastMsgBody: lastMessageBody,
        lastMsgAt: lastMessageAt,
        role: currentUserMemberInfo?.role,
        unreadCount: conv.unreadCount ?? 0,
        pinnedAt: conv.pinnedAt,
        mutedUntil: conv.mutedUntil,
        isFavorite: conv.isFavorite,
        joinedAt:
            currentUserMemberInfo?.joinedAt ?? DateTime.now().toIso8601String(),
        disappearingAfterSec: conv.disappearingAfterSec,
      );

      result.add(groupModel);
    }

    return result;
  }

  // Get group by conversation ID without members
  Future<GroupModel?> getGroupWithoutMembersByConvId(
    String conversationId,
  ) async {
    final db = sqliteDatabase.database;

    final currentUserInfo = await UserUtils().getUserDetails();

    // Query conversation by ID
    final conv = await (db.select(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    if (conv == null || conv.type != 'group') {
      return null;
    }

    // Get last message details if lastMsgId exists
    String? lastMessageType;
    String? lastMessageBody;
    String? lastMessageAt;
    String? lastMsgId = conv.lastMsgId;

    if (conv.lastMsgId != null) {
      final lastMessage =
          await (db.select(db.messages)
                ..where((t) => t.id.equals(conv.lastMsgId!)))
              .getSingleOrNull();

      if (lastMessage != null) {
        lastMessageType = lastMessage.type;
        lastMessageBody = _getMessagePreviewText(
          lastMessage.type,
          lastMessage.body,
          lastMessage.attachments,
        );
        lastMessageAt = lastMessage.sentAt;
        lastMsgId = lastMessage.id;
      }
    }

    ConversationMemberModel? currentUserMemberInfo;
    if (currentUserInfo != null) {
      currentUserMemberInfo = await ConversationMemberRepository()
          .getMemberByConversationAndUser(conv.id, currentUserInfo.id);
    }

    // Create and return GroupModel
    return GroupModel(
      chatId: conv.id,
      title: conv.title ?? 'Group Chat',
      profilePic: conv.profilePic,
      pinnedMsgId: conv.pinnedMsgId,
      lastMsgId: lastMsgId,
      lastMsgType: lastMessageType,
      lastMsgBody: lastMessageBody,
      lastMsgAt: lastMessageAt,
      role: currentUserMemberInfo?.role,
      unreadCount: conv.unreadCount ?? 0,
      pinnedAt: conv.pinnedAt,
      mutedUntil: conv.mutedUntil,
      isFavorite: conv.isFavorite,
      joinedAt:
          currentUserMemberInfo?.joinedAt ?? DateTime.now().toIso8601String(),
      disappearingAfterSec: conv.disappearingAfterSec,
    );
  }

  /// Reactive stream of active members for a group, joined with their user
  /// row (display name + avatar). Re-emits whenever `chat_members` or
  /// `users` change for this conversation — so server-driven WS events
  /// (`member_added` / `removed` / `promoted` / `demoted`) that the chat
  /// provider applies to SQLite show up live in the chat-details screen
  /// without any manual refresh.
  Stream<List<GroupMember>> watchActiveGroupMembers(String conversationId) {
    final db = sqliteDatabase.database;

    final query = db.select(db.chatMembers).join([
          leftOuterJoin(
            db.users,
            db.users.id.equalsExp(db.chatMembers.userId),
          ),
          // contacts.id mirrors users.id, so the local contact name (when
          // saved) overrides the server name in the member list.
          leftOuterJoin(
            db.contacts,
            db.contacts.id.equalsExp(db.chatMembers.userId),
          ),
        ])
      ..where(db.chatMembers.chatId.equals(conversationId))
      ..where(db.chatMembers.removedAt.isNull())
      ..orderBy([
        OrderingTerm(
          expression: db.chatMembers.joinedAt,
          mode: OrderingMode.desc,
        ),
      ]);

    return query.watch().map((rows) {
      // Dedup by userId (the chat_members table can hold a removed-then-
      // re-added row pair; the JOIN preserves both).
      final map = <String, GroupMember>{};
      for (final row in rows) {
        final m = row.readTable(db.chatMembers);
        final u = row.readTableOrNull(db.users);
        final c = row.readTableOrNull(db.contacts);
        if (map.containsKey(m.userId)) continue;
        map[m.userId] = GroupMember(
          userId: m.userId,
          name: c?.name ?? u?.name ?? '',
          profilePic: u?.profilePic,
          role: m.role,
          joinedAt: m.joinedAt,
        );
      }
      return map.values.toList();
    });
  }

  // Get group by conversation ID with members
  Future<GroupModel?> getGroupWithMembersByConvId(
    String conversationId,
  ) async {
    final db = sqliteDatabase.database;

    final currentUserInfo = await UserUtils().getUserDetails();

    // Query conversation by ID
    final conv = await (db.select(
      db.chats,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    if (conv == null || conv.type != 'group') {
      return null;
    }

    // Single JOIN query: fetch active members + user details together.
    // Replaces an N+1 loop that did one users-table SELECT per member —
    // for a 100-member group that was 100 round-trips on every screen open.
    final memberJoin = await (db.select(db.chatMembers).join([
              leftOuterJoin(
                db.users,
                db.users.id.equalsExp(db.chatMembers.userId),
              ),
              leftOuterJoin(
                db.contacts,
                db.contacts.id.equalsExp(db.chatMembers.userId),
              ),
            ])
          ..where(db.chatMembers.chatId.equals(conversationId))
          ..where(db.chatMembers.removedAt.isNull())
          ..orderBy([
            OrderingTerm(
              expression: db.chatMembers.joinedAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();

    // Deduplicate by userId (keep the first occurrence — already ordered
    // newest first, which matches the previous behaviour).
    final membersMap = <String, GroupMember>{};
    for (final row in memberJoin) {
      final member = row.readTable(db.chatMembers);
      final user = row.readTableOrNull(db.users);
      final contact = row.readTableOrNull(db.contacts);
      if (membersMap.containsKey(member.userId)) continue;
      membersMap[member.userId] = GroupMember(
        userId: member.userId,
        name: contact?.name ?? user?.name ?? '',
        profilePic: user?.profilePic,
        role: member.role,
        joinedAt: member.joinedAt,
      );
    }

    final members = membersMap.values.toList();

    // Get last message details if lastMsgId exists
    String? lastMessageType;
    String? lastMessageBody;
    String? lastMessageAt;
    String? lastMsgId = conv.lastMsgId;

    if (conv.lastMsgId != null) {
      final lastMessage =
          await (db.select(db.messages)
                ..where((t) => t.id.equals(conv.lastMsgId!)))
              .getSingleOrNull();

      if (lastMessage != null) {
        lastMessageType = lastMessage.type;
        lastMessageBody = _getMessagePreviewText(
          lastMessage.type,
          lastMessage.body,
          lastMessage.attachments,
        );
        lastMessageAt = lastMessage.sentAt;
        lastMsgId = lastMessage.id;
      }
    }

    ConversationMemberModel? currentUserMemberInfo;
    if (currentUserInfo != null) {
      currentUserMemberInfo = await ConversationMemberRepository()
          .getMemberByConversationAndUser(conv.id, currentUserInfo.id);
    }

    // Create and return GroupModel with members
    return GroupModel(
      chatId: conv.id,
      title: conv.title ?? 'Group Chat',
      profilePic: conv.profilePic,
      members: members,
      pinnedMsgId: conv.pinnedMsgId,
      lastMsgId: lastMsgId,
      lastMsgType: lastMessageType,
      lastMsgBody: lastMessageBody,
      lastMsgAt: lastMessageAt,
      role: currentUserMemberInfo?.role,
      unreadCount: conv.unreadCount ?? 0,
      pinnedAt: conv.pinnedAt,
      mutedUntil: conv.mutedUntil,
      isFavorite: conv.isFavorite,
      joinedAt:
          currentUserMemberInfo?.joinedAt ?? DateTime.now().toIso8601String(),
      disappearingAfterSec: conv.disappearingAfterSec,
    );
  }
}
