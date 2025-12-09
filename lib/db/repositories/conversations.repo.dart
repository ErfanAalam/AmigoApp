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

  /// Helper method to convert Conversations row to ConversationModel
  /// Joins with Users table to get userName and userProfilePic when userId is present
  Future<ConversationModel> _conversationToModel(Conversation conv) async {
    // final db = sqliteDatabase.database;

    // If userId is present, try to get user info from Users table
    // if (conv.createrId != null) {
    //   final user = await (db.select(
    //     db.users,
    //   )..where((t) => t.id.equals(conv.userId!))).getSingleOrNull();
    //   if (user != null) {
    //     userName = user.name;
    //     userProfilePic = user.profilePic;
    //   } else {
    //     // If user not found, use title for groups or 'Unknown' for DMs
    //     userName = conv.type.toLowerCase() == 'group'
    //         ? (conv.title ?? 'Group Chat')
    //         : 'Unknown';
    //   }
    // } else {
    //   // For groups without userId, use title
    //   userName = conv.type.toLowerCase() == 'group'
    //       ? (conv.title ?? 'Group Chat')
    //       : 'Unknown';
    // }

    return ConversationModel(
      id: conv.id,
      type: conv.type,
      title: conv.title,
      createrId: conv.createrId,
      lastMessageId: conv.lastMessageId,
      pinnedMessageId: conv.pinnedMessageId,
      unreadCount: conv.unreadCount,
      isDeleted: conv.isDeleted,
      isPinned: conv.isPinned,
      isMuted: conv.isMuted,
      isFavorite: conv.isFavorite,
      createdAt: conv.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: conv.updatedAt,
      needSync: conv.needSync,
    );
  }

  /// Insert multiple contacts (bulk insert)
  Future<void> insertConversations(
    List<ConversationModel> conversations,
  ) async {
    final db = sqliteDatabase.database;

    for (final conv in conversations) {
      // Check if conversation already exists to preserve needSync value
      // final existingConv = await getConversationById(conv.id);

      // Preserve existing needSync value if conversation exists, otherwise use provided value or default to true for new conversations
      // final needSyncValue = existingConv != null
      //     ? (conv.needSync ?? existingConv.needSync ?? true)
      //     : (conv.needSync ?? true);
      //
      // final lastmessageidvalue = existingConv != null
      //     ? (conv.lastMessageId ?? existingConv.lastMessageId)
      //     : (conv.lastMessageId);
      // final pinnedmessageidvalue = existingConv != null
      //     ? (conv.pinnedMessageId ?? existingConv.pinnedMessageId)
      //     : (conv.pinnedMessageId);

      final convCompanion = ConversationsCompanion.insert(
        id: Value(conv.id),
        type: conv.type,
        title: Value(conv.title),
        createrId: conv.createrId,
        lastMessageId: Value(conv.lastMessageId),
        pinnedMessageId: Value(conv.pinnedMessageId),
        unreadCount: Value(conv.unreadCount ?? 0),
        createdAt: Value(conv.createdAt),
        isDeleted: Value(conv.isDeleted ?? false),
        isPinned: Value(conv.isPinned ?? false),
        isMuted: Value(conv.isMuted ?? false),
        isFavorite: Value(conv.isFavorite ?? false),
        updatedAt: Value(conv.updatedAt),
      );
      await db.into(db.conversations).insert(convCompanion);
    }
  }

  // Get All members by conversation id with thier details from users table

  /// Get all conversations
  /// Joins with Users table to get userName and userProfilePic when userId is present
  Future<List<ConversationModel>> getAllConversations() async {
    final db = sqliteDatabase.database;

    // Query conversations with optional join to Users table
    final query = db.select(db.conversations)
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);

    final conversations = await query.get();

    // Convert to ConversationModel, joining with Users when needed
    final result = <ConversationModel>[];
    for (final conv in conversations) {
      result.add(await _conversationToModel(conv));
    }

    return result;
  }

  /// Get all conversation IDs
  /// If [type] is provided, returns only IDs for that conversation type
  /// If [type] is null, returns all conversation IDs
  Future<List<int>> getAllConversationIds({ChatType? type}) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.conversations);

    if (type != null) {
      query.where((t) => t.type.equals(type.value));
    }

    final conversations = await query.get();

    return conversations.map((conv) => conv.id).toList();
  }

  /// Clear all conversations from the database
  Future<void> clearAllConversations() async {
    final db = sqliteDatabase.database;
    await db.delete(db.conversations).go();
  }

  /// Update a conversation
  Future<void> updateConversation(ConversationModel conversation) async {
    final db = sqliteDatabase.database;

    final companion = ConversationsCompanion(
      id: Value(conversation.id),
      type: Value(conversation.type),
      title: Value(conversation.title),
      createrId: Value(conversation.createrId),
      lastMessageId: Value(conversation.lastMessageId),
      pinnedMessageId: Value(conversation.pinnedMessageId),
      unreadCount: Value(conversation.unreadCount ?? 0),
      createdAt: Value(conversation.createdAt),
      isDeleted: Value(conversation.isDeleted ?? false),
      isPinned: Value(conversation.isPinned ?? false),
      isMuted: Value(conversation.isMuted ?? false),
      isFavorite: Value(conversation.isFavorite ?? false),
      updatedAt: Value(
        conversation.updatedAt ?? DateTime.now().toIso8601String(),
      ),
      needSync: Value(conversation.needSync ?? false),
    );

    await db.update(db.conversations).replace(companion);
  }

  /// Get a conversation by ID
  Future<ConversationModel?> getConversationById(int conversationId) async {
    final db = sqliteDatabase.database;

    final conv = await (db.select(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    if (conv == null) return null;

    return await _conversationToModel(conv);
  }

  /// Get conversation type by ID
  Future<String?> getConversationTypeById(int conversationId) async {
    final db = sqliteDatabase.database;

    final conv = await (db.select(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    return conv?.type;
  }

  /// Get conversations by type (dm, group, etc.)
  Future<List<ConversationModel>> getConversationsByType(ChatType type) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.conversations)
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
  Future<bool> deleteConversation(int conversationId) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).go();
    return deleted > 0;
  }

  /// Update unread count for a conversation
  Future<void> updateUnreadCount(int conversationId, int unreadCount) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).write(
      ConversationsCompanion(
        unreadCount: Value(unreadCount),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Update pinnedMessageId for a conversation
  Future<void> updatePinnedMessage(
    int conversationId,
    int? pinnedMessageId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).write(
      ConversationsCompanion(
        pinnedMessageId: Value(pinnedMessageId),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Mark conversation as read (set unread count to 0)
  Future<void> markAsRead(int conversationId) async {
    await updateUnreadCount(conversationId, 0);
  }

  /// Toggle pin status of a conversation
  Future<void> togglePin(int conversationId, bool isPinned) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).write(
      ConversationsCompanion(
        isPinned: Value(isPinned),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Toggle mute status of a conversation
  Future<void> toggleMute(int conversationId, bool isMuted) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).write(
      ConversationsCompanion(
        isMuted: Value(isMuted),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Toggle favorite status of a conversation
  Future<void> toggleFavorite(int conversationId, bool isFavorite) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).write(
      ConversationsCompanion(
        isFavorite: Value(isFavorite),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Get pinned conversations
  Future<List<ConversationModel>> getPinnedConversations() async {
    final db = sqliteDatabase.database;

    final query = db.select(db.conversations)
      ..where((t) => t.isPinned.equals(true))
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

  /// Get favorite conversations
  Future<List<ConversationModel>> getFavoriteConversations() async {
    final db = sqliteDatabase.database;

    final query = db.select(db.conversations)
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
  Future<void> updateLastMessage(int conversationId, int lastMessageId) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).write(
      ConversationsCompanion(
        lastMessageId: Value(lastMessageId),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  // update last message id only
  Future<void> updateLastMessageId(
    int conversationId,
    int lastMessageId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(lastMessageId: Value(lastMessageId)));
  }

  /// Mark conversation as deleted (soft delete)
  Future<void> markAsDeleted(int conversationId, bool isDeleted) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).write(
      ConversationsCompanion(
        isDeleted: Value(isDeleted),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// get need sync from conversation id
  Future<bool> getNeedSyncStatus(int conversationId) async {
    final db = sqliteDatabase.database;

    final conv = await (db.select(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    if (conv == null) return false;

    return conv.needSync;
  }

  // update need sync status
  Future<void> updateNeedSyncStatus(int conversationId, bool needSync) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).write(
      ConversationsCompanion(
        needSync: Value(needSync),
        updatedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  // get all deleted DMs
  Future<List<DmModel>> getAllDeletedDms() async {
    final db = sqliteDatabase.database;

    // Query conversations by type and isDeleted
    final conversations =
        await (db.select(db.conversations)
              ..where((t) => t.type.equals('dm') & t.isDeleted.equals(true))
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
      // Get conversation members
      final members =
          await (db.select(db.conversationMembers)..where(
                (t) => t.conversationId.equals(conv.id) & t.removedAt.isNull(),
              ))
              .get();

      // Skip if no valid recipient found
      if (members[0].userId == 0) {
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

      // Create DmListModel
      final dmModel = DmModel(
        conversationId: conv.id,
        recipientId: recipientUser.id,
        recipientName: recipientUser.name,
        recipientPhone: recipientUser.phone,
        recipientProfilePic: recipientUser.profilePic,
        pinnedMessageId: conv.pinnedMessageId,
        lastMessageId: conv.lastMessageId,
        unreadCount: conv.unreadCount,
        isRecipientOnline: recipientUser.isOnline,
        isDeleted: conv.isDeleted,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        isFavorite: conv.isFavorite,
        createdAt: conv.createdAt ?? DateTime.now().toIso8601String(),
      );

      result.add(dmModel);
    }

    return result;
  }

  // Get all DMs by type with recipient info and last message details
  Future<List<DmModel>> getAllDmsWithRecipientInfo() async {
    final db = sqliteDatabase.database;

    // Query conversations by type
    final conversations =
        await (db.select(db.conversations)
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
      // Get conversation members
      final members =
          await (db.select(db.conversationMembers)..where(
                (t) => t.conversationId.equals(conv.id) & t.removedAt.isNull(),
              ))
              .get();

      // Skip if no valid recipient found
      if (members[0].userId == 0) {
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

      // Get last message details if lastMessageId exists
      String? lastMessageType;
      String? lastMessageBody;
      String? lastMessageAt;
      int? lastMessageId = conv.lastMessageId;

      if (conv.lastMessageId != null) {
        final lastMessage =
            await (db.select(db.messages)
                  ..where((t) => t.id.equals(BigInt.from(conv.lastMessageId!))))
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
          lastMessageId = lastMessage.id.toInt();
        }
      }

      // Create DmListModel
      final dmModel = DmModel(
        conversationId: conv.id,
        recipientId: recipientUser.id,
        recipientName: recipientUser.name,
        recipientPhone: recipientUser.phone,
        recipientProfilePic: recipientUser.profilePic,
        pinnedMessageId: conv.pinnedMessageId,
        lastMessageId: lastMessageId,
        lastMessageType: lastMessageType,
        lastMessageBody: lastMessageBody,
        lastMessageAt: lastMessageAt,
        unreadCount: conv.unreadCount,
        isRecipientOnline: recipientUser.isOnline,
        isDeleted: conv.isDeleted,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        isFavorite: conv.isFavorite,
        createdAt: conv.createdAt ?? DateTime.now().toIso8601String(),
      );

      result.add(dmModel);
    }

    return result;
  }

  // Get DM by conversation ID with recipient info and last message details
  Future<DmModel?> getDmByConversationId(int conversationId) async {
    final db = sqliteDatabase.database;

    // Query conversation by ID
    final conv = await (db.select(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    if (conv == null || conv.type != 'dm') {
      return null;
    }

    // Get conversation members
    final members =
        await (db.select(db.conversationMembers)..where(
              (t) => t.conversationId.equals(conv.id) & t.removedAt.isNull(),
            ))
            .get();

    // Return null if no valid recipient found
    if (members.isEmpty || members[0].userId == 0) {
      return null;
    }

    // Get recipient user info
    final recipientUser = await (db.select(
      db.users,
    )..where((t) => t.id.equals(members[0].userId))).getSingleOrNull();

    if (recipientUser == null) {
      return null;
    }

    // Get last message details if lastMessageId exists
    String? lastMessageType;
    String? lastMessageBody;
    String? lastMessageAt;
    int? lastMessageId = conv.lastMessageId;

    if (conv.lastMessageId != null) {
      final lastMessage =
          await (db.select(db.messages)
                ..where((t) => t.id.equals(BigInt.from(conv.lastMessageId!))))
              .getSingleOrNull();

      if (lastMessage != null) {
        lastMessageType = lastMessage.type;
        lastMessageBody = _getMessagePreviewText(
          lastMessage.type,
          lastMessage.body,
          lastMessage.attachments,
        );
        lastMessageAt = lastMessage.sentAt;
        lastMessageId = lastMessage.id.toInt();
      }
    }

    // Create and return DmModel
    return DmModel(
      conversationId: conv.id,
      recipientId: recipientUser.id,
      recipientName: recipientUser.name,
      recipientPhone: recipientUser.phone,
      recipientProfilePic: recipientUser.profilePic,
      pinnedMessageId: conv.pinnedMessageId,
      lastMessageId: lastMessageId,
      lastMessageType: lastMessageType,
      lastMessageBody: lastMessageBody,
      lastMessageAt: lastMessageAt,
      unreadCount: conv.unreadCount,
      isRecipientOnline: recipientUser.isOnline,
      isDeleted: conv.isDeleted,
      isPinned: conv.isPinned,
      isMuted: conv.isMuted,
      isFavorite: conv.isFavorite,
      createdAt: conv.createdAt ?? DateTime.now().toIso8601String(),
    );
  }

  // get group list
  Future<List<GroupModel>> getGroupListWithoutMembers() async {
    final db = sqliteDatabase.database;

    final currentUserInfo = await UserUtils().getUserDetails();

    // Query conversations by type
    final conversations =
        await (db.select(db.conversations)
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
      // Get last message details if lastMessageId exists
      String? lastMessageType;
      String? lastMessageBody;
      String? lastMessageAt;
      int? lastMessageId = conv.lastMessageId;

      if (conv.lastMessageId != null) {
        final lastMessage =
            await (db.select(db.messages)
                  ..where((t) => t.id.equals(BigInt.from(conv.lastMessageId!))))
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
          lastMessageId = lastMessage.id.toInt();
        }
      }

      ConversationMemberModel? currentUserMemberInfo;
      if (currentUserInfo != null) {
        currentUserMemberInfo = await ConversationMemberRepository()
            .getMemberByConversationAndUser(conv.id, currentUserInfo.id);
      }

      // Create DmListModel
      final groupModel = GroupModel(
        conversationId: conv.id,
        title: conv.title ?? 'Group Chat',
        pinnedMessageId: conv.pinnedMessageId,
        lastMessageId: lastMessageId,
        lastMessageType: lastMessageType,
        lastMessageBody: lastMessageBody,
        lastMessageAt: lastMessageAt,
        role: currentUserMemberInfo?.role,
        unreadCount: currentUserMemberInfo?.unreadCount ?? 0,
        isPinned: conv.isPinned,
        isMuted: conv.isMuted,
        isFavorite: conv.isFavorite,
        joinedAt:
            currentUserMemberInfo?.joinedAt ?? DateTime.now().toIso8601String(),
      );

      result.add(groupModel);
    }

    return result;
  }

  // Get group by conversation ID without members
  Future<GroupModel?> getGroupWithoutMembersByConvId(int conversationId) async {
    final db = sqliteDatabase.database;

    final currentUserInfo = await UserUtils().getUserDetails();

    // Query conversation by ID
    final conv = await (db.select(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    if (conv == null || conv.type != 'group') {
      return null;
    }

    // Get last message details if lastMessageId exists
    String? lastMessageType;
    String? lastMessageBody;
    String? lastMessageAt;
    int? lastMessageId = conv.lastMessageId;

    if (conv.lastMessageId != null) {
      final lastMessage =
          await (db.select(db.messages)
                ..where((t) => t.id.equals(BigInt.from(conv.lastMessageId!))))
              .getSingleOrNull();

      if (lastMessage != null) {
        lastMessageType = lastMessage.type;
        lastMessageBody = _getMessagePreviewText(
          lastMessage.type,
          lastMessage.body,
          lastMessage.attachments,
        );
        lastMessageAt = lastMessage.sentAt;
        lastMessageId = lastMessage.id.toInt();
      }
    }

    ConversationMemberModel? currentUserMemberInfo;
    if (currentUserInfo != null) {
      currentUserMemberInfo = await ConversationMemberRepository()
          .getMemberByConversationAndUser(conv.id, currentUserInfo.id);
    }

    // Create and return GroupModel
    return GroupModel(
      conversationId: conv.id,
      title: conv.title ?? 'Group Chat',
      pinnedMessageId: conv.pinnedMessageId,
      lastMessageId: lastMessageId,
      lastMessageType: lastMessageType,
      lastMessageBody: lastMessageBody,
      lastMessageAt: lastMessageAt,
      role: currentUserMemberInfo?.role,
      unreadCount: currentUserMemberInfo?.unreadCount ?? 0,
      isPinned: conv.isPinned,
      isMuted: conv.isMuted,
      isFavorite: conv.isFavorite,
      joinedAt:
          currentUserMemberInfo?.joinedAt ?? DateTime.now().toIso8601String(),
    );
  }

  // Get group by conversation ID with members
  Future<GroupModel?> getGroupWithMembersByConvId(int conversationId) async {
    final db = sqliteDatabase.database;

    final currentUserInfo = await UserUtils().getUserDetails();

    // Query conversation by ID
    final conv = await (db.select(
      db.conversations,
    )..where((t) => t.id.equals(conversationId))).getSingleOrNull();

    if (conv == null || conv.type != 'group') {
      return null;
    }

    // Get active conversation members
    final conversationMembers = await ConversationMemberRepository()
        .getActiveMembersByConversationId(conversationId);

    // Build GroupMember list with user details
    // Use a Map to deduplicate by userId (keep the first occurrence)
    final membersMap = <int, GroupMember>{};
    for (final member in conversationMembers) {
      // Skip if we already have this user (deduplicate)
      if (membersMap.containsKey(member.userId)) {
        continue;
      }

      // Get user info from users table
      final user = await (db.select(
        db.users,
      )..where((t) => t.id.equals(member.userId))).getSingleOrNull();

      if (user != null) {
        membersMap[member.userId] = GroupMember(
          userId: user.id,
          name: user.name,
          profilePic: user.profilePic,
          role: member.role,
          joinedAt: member.joinedAt,
        );
      }
    }

    // Convert map values to list
    final members = membersMap.values.toList();

    // Get last message details if lastMessageId exists
    String? lastMessageType;
    String? lastMessageBody;
    String? lastMessageAt;
    int? lastMessageId = conv.lastMessageId;

    if (conv.lastMessageId != null) {
      final lastMessage =
          await (db.select(db.messages)
                ..where((t) => t.id.equals(BigInt.from(conv.lastMessageId!))))
              .getSingleOrNull();

      if (lastMessage != null) {
        lastMessageType = lastMessage.type;
        lastMessageBody = _getMessagePreviewText(
          lastMessage.type,
          lastMessage.body,
          lastMessage.attachments,
        );
        lastMessageAt = lastMessage.sentAt;
        lastMessageId = lastMessage.id.toInt();
      }
    }

    ConversationMemberModel? currentUserMemberInfo;
    if (currentUserInfo != null) {
      currentUserMemberInfo = await ConversationMemberRepository()
          .getMemberByConversationAndUser(conv.id, currentUserInfo.id);
    }

    // Create and return GroupModel with members
    return GroupModel(
      conversationId: conv.id,
      title: conv.title ?? 'Group Chat',
      members: members,
      pinnedMessageId: conv.pinnedMessageId,
      lastMessageId: lastMessageId,
      lastMessageType: lastMessageType,
      lastMessageBody: lastMessageBody,
      lastMessageAt: lastMessageAt,
      role: currentUserMemberInfo?.role,
      unreadCount: currentUserMemberInfo?.unreadCount ?? 0,
      isPinned: conv.isPinned,
      isMuted: conv.isMuted,
      isFavorite: conv.isFavorite,
      joinedAt:
          currentUserMemberInfo?.joinedAt ?? DateTime.now().toIso8601String(),
    );
  }
}
