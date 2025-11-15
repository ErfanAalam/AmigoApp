import 'package:amigo/models/conversation_model.dart';
import 'package:drift/drift.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class ConvesationRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  /// Helper method to convert Conversations row to ConversationModel
  /// Joins with Users table to get userName and userProfilePic when userId is present
  Future<ConversationModel> _conversationToModel(Conversation conv) async {
    final db = sqliteDatabase.database;
    String userName = 'Unknown';
    String? userProfilePic;

    // If userId is present, try to get user info from Users table
    if (conv.userId != null) {
      final user = await (db.select(db.users)
            ..where((t) => t.id.equals(conv.userId!)))
          .getSingleOrNull();
      if (user != null) {
        userName = user.name;
        userProfilePic = user.profilePic;
      } else {
        // If user not found, use title for groups or 'Unknown' for DMs
        userName = conv.type.toLowerCase() == 'group'
            ? (conv.title ?? 'Group Chat')
            : 'Unknown';
      }
    } else {
      // For groups without userId, use title
      userName = conv.type.toLowerCase() == 'group'
          ? (conv.title ?? 'Group Chat')
          : 'Unknown';
    }

    return ConversationModel(
      id: conv.id,
      type: conv.type,
      title: conv.title,
      createrId: conv.createrId,
      lastMessageId: conv.lastMessageId,
      unreadCount: conv.unreadCount,
      userId: conv.userId,
      userName: userName,
      userProfilePic: userProfilePic,
      isDeleted: conv.isDeleted,
      isPinned: conv.isPinned,
      isMuted: conv.isMuted,
      isFavorite: conv.isFavorite,
      createdAt: conv.createdAt ?? DateTime.now().toIso8601String(),
    );
  }

  /// Insert multiple contacts (bulk insert)
  Future<void> insertConversations(
    List<ConversationModel> conversations,
  ) async {
    final db = sqliteDatabase.database;

    for (final conv in conversations) {
      final convCompanion = ConversationsCompanion.insert(
        id: Value(conv.id),
        type: conv.type,
        title: Value(conv.title),
        createrId: Value(conv.createrId),
        lastMessageId: Value(conv.lastMessageId),
        unreadCount: Value(conv.unreadCount ?? 0),
        createdAt: Value(conv.createdAt),
        userId: Value(conv.userId),
        isDeleted: Value(conv.isDeleted ?? false),
        isPinned: Value(conv.isPinned ?? false),
        isMuted: Value(conv.isMuted ?? false),
        isFavorite: Value(conv.isFavorite ?? false),
      );
      await db.into(db.conversations).insertOnConflictUpdate(convCompanion);
    }
  }

  /// Get all conversations
  /// Joins with Users table to get userName and userProfilePic when userId is present
  Future<List<ConversationModel>> getAllConversations() async {
    final db = sqliteDatabase.database;

    // Query conversations with optional join to Users table
    final query = db.select(db.conversations)
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.updatedAt,
              mode: OrderingMode.desc,
            ),
        (t) => OrderingTerm(
              expression: t.createdAt,
              mode: OrderingMode.desc,
            ),
      ]);

    final conversations = await query.get();

    // Convert to ConversationModel, joining with Users when needed
    final result = <ConversationModel>[];
    for (final conv in conversations) {
      result.add(await _conversationToModel(conv));
    }

    return result;
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
      unreadCount: Value(conversation.unreadCount ?? 0),
      createdAt: Value(conversation.createdAt),
      userId: Value(conversation.userId),
      isDeleted: Value(conversation.isDeleted ?? false),
      isPinned: Value(conversation.isPinned ?? false),
      isMuted: Value(conversation.isMuted ?? false),
      isFavorite: Value(conversation.isFavorite ?? false),
      updatedAt: Value(DateTime.now().toIso8601String()),
    );

    await db.update(db.conversations).replace(companion);
  }

  /// Get a conversation by ID
  Future<ConversationModel?> getConversationById(int conversationId) async {
    final db = sqliteDatabase.database;

    final conv = await (db.select(db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .getSingleOrNull();

    if (conv == null) return null;

    return await _conversationToModel(conv);
  }

  /// Delete a conversation by ID
  Future<bool> deleteConversation(int conversationId) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .go();
    return deleted > 0;
  }

  /// Update unread count for a conversation
  Future<void> updateUnreadCount(int conversationId, int unreadCount) async {
    final db = sqliteDatabase.database;
    await (db.update(db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(
      unreadCount: Value(unreadCount),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ));
  }

  /// Mark conversation as read (set unread count to 0)
  Future<void> markAsRead(int conversationId) async {
    await updateUnreadCount(conversationId, 0);
  }

  /// Toggle pin status of a conversation
  Future<void> togglePin(int conversationId, bool isPinned) async {
    final db = sqliteDatabase.database;
    await (db.update(db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(
      isPinned: Value(isPinned),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ));
  }

  /// Toggle mute status of a conversation
  Future<void> toggleMute(int conversationId, bool isMuted) async {
    final db = sqliteDatabase.database;
    await (db.update(db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(
      isMuted: Value(isMuted),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ));
  }

  /// Toggle favorite status of a conversation
  Future<void> toggleFavorite(int conversationId, bool isFavorite) async {
    final db = sqliteDatabase.database;
    await (db.update(db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(
      isFavorite: Value(isFavorite),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ));
  }

  /// Get conversations by type (dm, group, etc.)
  Future<List<ConversationModel>> getConversationsByType(String type) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.conversations)
      ..where((t) => t.type.equals(type))
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.updatedAt,
              mode: OrderingMode.desc,
            ),
        (t) => OrderingTerm(
              expression: t.createdAt,
              mode: OrderingMode.desc,
            ),
      ]);

    final conversations = await query.get();

    final result = <ConversationModel>[];
    for (final conv in conversations) {
      result.add(await _conversationToModel(conv));
    }

    return result;
  }

  /// Get pinned conversations
  Future<List<ConversationModel>> getPinnedConversations() async {
    final db = sqliteDatabase.database;

    final query = db.select(db.conversations)
      ..where((t) => t.isPinned.equals(true))
      ..orderBy([
        (t) => OrderingTerm(
              expression: t.updatedAt,
              mode: OrderingMode.desc,
            ),
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
        (t) => OrderingTerm(
              expression: t.updatedAt,
              mode: OrderingMode.desc,
            ),
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
    int conversationId,
    int lastMessageId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(
      lastMessageId: Value(lastMessageId),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ));
  }

  /// Mark conversation as deleted (soft delete)
  Future<void> markAsDeleted(int conversationId, bool isDeleted) async {
    final db = sqliteDatabase.database;
    await (db.update(db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(
      isDeleted: Value(isDeleted),
      updatedAt: Value(DateTime.now().toIso8601String()),
    ));
  }
}
