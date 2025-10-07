// lib/repositories/conversations_repository.dart
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/conversation_model.dart';

class ConversationsRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<int> insertOrUpdateConversation(ConversationModel conversation) async {
    final db = await dbHelper.database;
    return await db.insert(
      'conversations',
      _conversationToMap(conversation),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOrUpdateConversations(
    List<ConversationModel> conversations,
  ) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    for (final conversation in conversations) {
      batch.insert(
        'conversations',
        _conversationToMap(conversation),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ConversationModel>> getAllConversations() async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'conversations',
      orderBy: 'last_message_at DESC, joined_at DESC',
    );
    return rows.map((r) => _mapToConversation(r)).toList();
  }

  Future<ConversationModel?> getConversationById(int conversationId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'conversations',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapToConversation(rows.first);
  }

  Future<void> updateUnreadCount(int conversationId, int unreadCount) async {
    final db = await dbHelper.database;
    await db.update(
      'conversations',
      {
        'unread_count': unreadCount,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> updateOnlineStatus(int userId, bool isOnline) async {
    final db = await dbHelper.database;
    await db.update(
      'conversations',
      {
        'is_online': isOnline ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> deleteConversation(int conversationId) async {
    final db = await dbHelper.database;
    return await db.delete(
      'conversations',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> clearConversations() async {
    final db = await dbHelper.database;
    await db.delete('conversations');
  }

  Map<String, dynamic> _conversationToMap(ConversationModel conversation) {
    return {
      'conversation_id': conversation.conversationId,
      'type': conversation.type,
      'user_id': conversation.userId,
      'user_name': conversation.userName,
      'user_profile_pic': conversation.userProfilePic,
      'joined_at': conversation.joinedAt,
      'unread_count': conversation.unreadCount,
      'last_message_id': conversation.metadata?.lastMessage.id,
      'last_message_body': conversation.metadata?.lastMessage.body,
      'last_message_type': conversation.metadata?.lastMessage.type,
      'last_message_sender_id': conversation.metadata?.lastMessage.senderId,
      'last_message_created_at': conversation.metadata?.lastMessage.createdAt,
      'last_message_at': conversation.lastMessageAt,
      'is_online': conversation.isOnline == true ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  ConversationModel _mapToConversation(Map<String, dynamic> map) {
    ConversationMetadata? metadata;
    if (map['last_message_id'] != null) {
      metadata = ConversationMetadata(
        lastMessage: LastMessage(
          id: map['last_message_id'] as int,
          body: map['last_message_body'] as String? ?? '',
          type: map['last_message_type'] as String? ?? 'text',
          senderId: map['last_message_sender_id'] as int? ?? 0,
          createdAt: map['last_message_created_at'] as String? ??
              DateTime.now().toIso8601String(),
          conversationId: map['conversation_id'] as int,
        ),
      );
    }

    return ConversationModel(
      conversationId: map['conversation_id'] as int,
      type: map['type'] as String,
      userId: map['user_id'] as int,
      userName: map['user_name'] as String,
      userProfilePic: map['user_profile_pic'] as String?,
      joinedAt: map['joined_at'] as String,
      unreadCount: map['unread_count'] as int? ?? 0,
      metadata: metadata,
      lastMessageAt: map['last_message_at'] as String?,
      isOnline: map['is_online'] == 1,
    );
  }

  Future close() async => dbHelper.close();
}
