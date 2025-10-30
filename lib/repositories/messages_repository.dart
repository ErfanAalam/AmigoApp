// lib/repositories/messages_repository.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/message_model.dart';
import '../services/message_storage_service.dart'
    show ConversationMeta, CachedConversationData;

class MessagesRepository {
  final dbHelper = DatabaseHelper.instance;

  // ==================== INSERT/UPDATE ====================

  Future<int> insertOrUpdateMessage(MessageModel message) async {
    final db = await dbHelper.database;
    return await db.insert(
      'messages',
      _messageToMap(message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOrUpdateMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;

    final db = await dbHelper.database;
    final batch = db.batch();

    for (final message in messages) {
      batch.insert(
        'messages',
        _messageToMap(message),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ==================== RETRIEVE ====================

  Future<List<MessageModel>> getMessagesByConversation(
    int conversationId, {
    int? limit,
    int? offset,
  }) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
      limit: limit,
      offset: offset,
    );

    return rows.map((r) => _mapToMessage(r)).toList();
  }

  Future<MessageModel?> getMessageById(int messageId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return _mapToMessage(rows.first);
  }

  Future<int> getMessageCount(int conversationId) async {
    final db = await dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE conversation_id = ?',
      [conversationId],
    );

    return result.first['count'] as int? ?? 0;
  }

  Future<CachedConversationData?> getCachedMessages(int conversationId) async {
    final messages = await getMessagesByConversation(conversationId);
    final meta = await getConversationMeta(conversationId);
    final lastSync = await getLastSyncTime(conversationId);

    if (messages.isEmpty) return null;

    return CachedConversationData(
      messages: messages,
      meta:
          meta ??
          ConversationMeta(
            totalCount: messages.length,
            currentPage: 1,
            totalPages: 1,
            hasNextPage: false,
            hasPreviousPage: false,
          ),
      lastUpdated: lastSync,
    );
  }

  // ==================== UPDATE ====================

  Future<void> updateMessageId(int oldId, int newId) async {
    final db = await dbHelper.database;
    await db.update(
      'messages',
      {'id': newId, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [oldId],
    );

    print('🔄 Updated message ID from $oldId to $newId in DB');
  }

  /// Update optimistic message with server data
  Future<MessageModel?> updateOptimisticMessage(
    int conversationId,
    int? optimisticId,
    int? serverId,
    Map<String, dynamic> messageData,
  ) async {
    if (optimisticId == null || serverId == null) return null;

    try {
      // Get the optimistic message
      final optimisticMessage = await getMessageById(optimisticId);
      if (optimisticMessage == null) {
        debugPrint('⚠️ Optimistic message $optimisticId not found in DB');
        return null;
      }

      // Extract data from WebSocket message
      final data = messageData['data'] as Map<String, dynamic>? ?? {};
      final messageType = messageData['type'];

      String messageBody;
      if (messageType == 'message_reply') {
        messageBody = data['new_message'] ?? optimisticMessage.body;
      } else {
        messageBody = data['body'] ?? optimisticMessage.body;
      }

      // Create updated message with server ID
      final updatedMessage = MessageModel(
        id: serverId,
        body: messageBody,
        type: data['type'] ?? optimisticMessage.type,
        senderId: optimisticMessage.senderId,
        conversationId: optimisticMessage.conversationId,
        createdAt:
            data['created_at'] ??
            messageData['timestamp'] ??
            optimisticMessage.createdAt,
        editedAt: data['edited_at'] ?? optimisticMessage.editedAt,
        metadata: data['metadata'] ?? optimisticMessage.metadata,
        attachments: data['attachments'] ?? optimisticMessage.attachments,
        deleted: data['deleted'] == true,
        senderName: optimisticMessage.senderName,
        senderProfilePic: optimisticMessage.senderProfilePic,
        replyToMessage: optimisticMessage.replyToMessage,
        replyToMessageId: optimisticMessage.replyToMessageId,
        isDelivered: optimisticMessage.isDelivered,
      );

      // Delete old optimistic message and insert new one with server ID
      await deleteMessage(optimisticId);
      await insertOrUpdateMessage(updatedMessage);

      debugPrint(
        '✅ Updated optimistic message from $optimisticId to $serverId in DB',
      );
      return updatedMessage;
    } catch (e) {
      debugPrint('❌ Error updating optimistic message in DB: $e');
      return null;
    }
  }

  void debugPrint(String message) {
    print(message);
  }

  Future<void> updateMessageStatus({
    required int conversationId,
    required int messageId,
    bool? isDelivered,
    bool? isRead,
  }) async {
    final db = await dbHelper.database;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (isDelivered != null) updates['is_delivered'] = isDelivered ? 1 : 0;
    if (isRead != null) updates['is_read'] = isRead ? 1 : 0;

    await db.update(
      'messages',
      updates,
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> updateAllMessagesStatus({
    required int conversationId,
    required int senderId,
    bool? isDelivered,
    bool? isRead,
  }) async {
    final db = await dbHelper.database;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (isDelivered != null) updates['is_delivered'] = isDelivered ? 1 : 0;
    if (isRead != null) updates['is_read'] = isRead ? 1 : 0;

    await db.update(
      'messages',
      updates,
      where: 'conversation_id = ? AND sender_id = ?',
      whereArgs: [conversationId, senderId],
    );
  }

  // ==================== PIN/STAR ====================

  /// Save pinned message (matches MessageStorageService API)
  Future<void> savePinnedMessage({
    required int conversationId,
    required int? pinnedMessageId,
  }) async {
    await setPinnedMessage(conversationId, pinnedMessageId);
  }

  /// Get pinned message (matches MessageStorageService API)
  Future<int?> getPinnedMessage(int conversationId) async {
    return await getPinnedMessageId(conversationId);
  }

  Future<void> setPinnedMessage(int conversationId, int? messageId) async {
    final db = await dbHelper.database;

    // First unpin all messages in this conversation
    await db.update(
      'messages',
      {'pinned': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );

    // Then pin the specified message (if any)
    if (messageId != null) {
      await db.update(
        'messages',
        {'pinned': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [messageId],
      );

      print('📌 Pinned message $messageId for conversation $conversationId');
    } else {
      print('📌 Unpinned message for conversation $conversationId');
    }
  }

  Future<int?> getPinnedMessageId(int conversationId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'messages',
      columns: ['id'],
      where: 'conversation_id = ? AND pinned = 1',
      whereArgs: [conversationId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['id'] as int?;
  }

  Future<void> toggleStarMessage(int messageId) async {
    final db = await dbHelper.database;

    // Get current star status
    final rows = await db.query(
      'messages',
      columns: ['starred'],
      where: 'id = ?',
      whereArgs: [messageId],
      limit: 1,
    );

    if (rows.isEmpty) return;

    final currentStarred = rows.first['starred'] as int;
    final newStarred = currentStarred == 1 ? 0 : 1;

    await db.update(
      'messages',
      {
        'starred': newStarred,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> starMessage(int messageId) async {
    final db = await dbHelper.database;
    await db.update(
      'messages',
      {'starred': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> unstarMessage(int messageId) async {
    final db = await dbHelper.database;
    await db.update(
      'messages',
      {'starred': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  // ==================== MEDIA CACHING ====================

  /// Update local media path for a message
  Future<void> updateLocalMediaPath(int messageId, String localPath) async {
    final db = await dbHelper.database;
    await db.update(
      'messages',
      {
        'local_media_path': localPath,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
    debugPrint('💾 Updated local media path for message $messageId');
  }

  /// Get messages with media that need to be cached
  Future<List<MessageModel>> getMessagesNeedingCache(int conversationId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'messages',
      where: '''
        conversation_id = ? 
        AND type IN ('image', 'video', 'audio') 
        AND local_media_path IS NULL
      ''',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
      limit: 50, // Limit to recent messages
    );

    return rows.map((r) => _mapToMessage(r)).toList();
  }

  /// Check if message has local media cached
  Future<bool> hasLocalMedia(int messageId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'messages',
      columns: ['local_media_path'],
      where: 'id = ? AND local_media_path IS NOT NULL',
      whereArgs: [messageId],
      limit: 1,
    );

    return rows.isNotEmpty;
  }

  /// Get starred messages (matches MessageStorageService API)
  Future<Set<int>> getStarredMessages(int conversationId) async {
    return await getStarredMessageIds(conversationId);
  }

  /// Save starred messages (matches MessageStorageService API)
  Future<void> saveStarredMessages({
    required int conversationId,
    required Set<int> starredMessageIds,
  }) async {
    final db = await dbHelper.database;

    // First unstar all messages in this conversation
    await db.update(
      'messages',
      {'starred': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );

    // Then star the specified messages
    if (starredMessageIds.isNotEmpty) {
      final batch = db.batch();
      for (final messageId in starredMessageIds) {
        batch.update(
          'messages',
          {'starred': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [messageId],
        );
      }
      await batch.commit(noResult: true);

      print(
        '⭐ Saved ${starredMessageIds.length} starred messages for conversation $conversationId',
      );
    }
  }

  Future<Set<int>> getStarredMessageIds(int conversationId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'messages',
      columns: ['id'],
      where: 'conversation_id = ? AND starred = 1',
      whereArgs: [conversationId],
    );

    return rows.map((r) => r['id'] as int).toSet();
  }

  // ==================== DELETE ====================

  Future<void> deleteMessage(int messageId) async {
    final db = await dbHelper.database;
    await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> deleteMessages(List<int> messageIds) async {
    if (messageIds.isEmpty) return;

    final db = await dbHelper.database;
    final batch = db.batch();

    for (final messageId in messageIds) {
      batch.delete('messages', where: 'id = ?', whereArgs: [messageId]);
    }

    await batch.commit(noResult: true);
  }

  Future<void> clearConversationMessages(int conversationId) async {
    final db = await dbHelper.database;
    await db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  // ==================== CONVERSATION META ====================

  Future<void> saveConversationMeta(
    int conversationId,
    ConversationMeta meta,
  ) async {
    final db = await dbHelper.database;
    await db.insert('conversation_meta', {
      'conversation_id': conversationId,
      'total_count': meta.totalCount,
      'current_page': meta.currentPage,
      'total_pages': meta.totalPages,
      'has_next_page': meta.hasNextPage ? 1 : 0,
      'has_previous_page': meta.hasPreviousPage ? 1 : 0,
      'last_sync_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Save complete conversation (messages + meta)
  Future<void> saveMessages({
    required int conversationId,
    required List<MessageModel> messages,
    required ConversationMeta meta,
  }) async {
    await insertOrUpdateMessages(messages);
    await saveConversationMeta(conversationId, meta);

    print(
      '💾 Saved ${messages.length} messages for conversation $conversationId to local DB',
    );
  }

  /// Add new messages to existing cache
  Future<void> addMessagesToCache({
    required int conversationId,
    required List<MessageModel> newMessages,
    required ConversationMeta updatedMeta,
    bool insertAtBeginning = true,
  }) async {
    if (newMessages.isEmpty) return;

    // Insert new messages (will replace if IDs match)
    await insertOrUpdateMessages(newMessages);

    // Update metadata
    await saveConversationMeta(conversationId, updatedMeta);

    final action = insertAtBeginning ? 'older' : 'newer';
    print(
      '➕ Added ${newMessages.length} $action messages to DB for conversation $conversationId',
    );
  }

  /// Add a single message to cache
  Future<void> addMessageToCache({
    required int conversationId,
    required MessageModel newMessage,
    required ConversationMeta updatedMeta,
    bool insertAtBeginning = false,
  }) async {
    await insertOrUpdateMessage(newMessage);
    await saveConversationMeta(conversationId, updatedMeta);
  }

  /// Remove messages from cache
  Future<void> removeMessageFromCache({
    required int conversationId,
    required List<int> messageIds,
  }) async {
    await deleteMessages(messageIds);

    // Update meta count
    final meta = await getConversationMeta(conversationId);
    if (meta != null) {
      final updatedMeta = ConversationMeta(
        totalCount: meta.totalCount - messageIds.length,
        currentPage: meta.currentPage,
        totalPages: meta.totalPages,
        hasNextPage: meta.hasNextPage,
        hasPreviousPage: meta.hasPreviousPage,
      );
      await saveConversationMeta(conversationId, updatedMeta);
    }

    print('🗑️ Removed ${messageIds.length} messages from DB');
  }

  /// Validate reply message storage
  Future<bool> validateReplyMessageStorage(int conversationId) async {
    try {
      final messages = await getMessagesByConversation(conversationId);

      int replyMessagesCount = 0;
      int validReplyMessagesCount = 0;

      for (final message in messages) {
        if (message.replyToMessage != null ||
            message.replyToMessageId != null) {
          replyMessagesCount++;

          if (message.replyToMessage != null) {
            final replyMsg = message.replyToMessage!;
            if (replyMsg.id > 0 && replyMsg.body.isNotEmpty) {
              validReplyMessagesCount++;
            }
          } else if (message.replyToMessageId != null) {
            validReplyMessagesCount++;
          }
        }
      }

      return replyMessagesCount == 0 ||
          validReplyMessagesCount == replyMessagesCount;
    } catch (e) {
      debugPrint('❌ Error validating reply message storage');
      return false;
    }
  }

  Future<ConversationMeta?> getConversationMeta(int conversationId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'conversation_meta',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final row = rows.first;

    // Return ConversationMeta with the lastSyncAt stored in row
    // Note: ConversationMeta doesn't have lastSyncAt field, so we just use the standard constructor
    return ConversationMeta(
      totalCount: row['total_count'] as int,
      currentPage: row['current_page'] as int,
      totalPages: row['total_pages'] as int,
      hasNextPage: row['has_next_page'] == 1,
      hasPreviousPage: row['has_previous_page'] == 1,
    );
  }

  Future<DateTime?> getLastSyncTime(int conversationId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'conversation_meta',
      columns: ['last_sync_at'],
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final timestamp = rows.first['last_sync_at'] as int;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<bool> isCacheStale(int conversationId, {int maxAgeMinutes = 5}) async {
    final lastSync = await getLastSyncTime(conversationId);
    if (lastSync == null) return true;

    final now = DateTime.now();
    final diff = now.difference(lastSync);

    return diff.inMinutes > maxAgeMinutes;
  }

  // ==================== HELPER METHODS ====================

  Map<String, dynamic> _messageToMap(MessageModel message) {
    return {
      'id': message.id,
      'conversation_id': message.conversationId,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'sender_profile_pic': message.senderProfilePic,
      'body': message.body,
      'type': message.type,
      'created_at': message.createdAt,
      'edited_at': message.editedAt,
      'deleted': message.deleted ? 1 : 0,
      'is_delivered': message.isDelivered ? 1 : 0,
      'is_read': 0, // Will be updated separately
      'reply_to_message_id': message.replyToMessageId,
      'reply_to_body': message.replyToMessage?.body,
      'reply_to_sender_id': message.replyToMessage?.senderId,
      'reply_to_sender_name': message.replyToMessage?.senderName,
      'reply_to_sender_profile_pic': message.replyToMessage?.senderProfilePic,
      'reply_to_type': message.replyToMessage?.type,
      'reply_to_created_at': message.replyToMessage?.createdAt,
      'attachments': message.attachments != null
          ? jsonEncode(message.attachments)
          : null,
      'metadata': message.metadata != null
          ? jsonEncode(message.metadata)
          : null,
      'pinned': 0, // Will be set separately
      'starred': 0, // Will be set separately
      'local_media_path': message.localMediaPath,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  MessageModel _mapToMessage(Map<String, dynamic> map) {
    // Reconstruct reply message if data exists
    MessageModel? replyToMessage;
    final replyToMessageId = map['reply_to_message_id'] as int?;

    if (replyToMessageId != null && map['reply_to_body'] != null) {
      replyToMessage = MessageModel(
        id: replyToMessageId,
        body: map['reply_to_body'] as String? ?? '',
        type: map['reply_to_type'] as String? ?? 'text',
        senderId: map['reply_to_sender_id'] as int? ?? 0,
        conversationId: map['conversation_id'] as int,
        createdAt: map['reply_to_created_at'] as String? ?? '',
        deleted: false,
        senderName: map['reply_to_sender_name'] as String? ?? '',
        senderProfilePic: map['reply_to_sender_profile_pic'] as String?,
        isDelivered: false,
      );
    }

    // Parse JSON fields
    Map<String, dynamic>? attachments;
    if (map['attachments'] != null) {
      try {
        attachments =
            jsonDecode(map['attachments'] as String) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing attachments: $e');
      }
    }

    Map<String, dynamic>? metadata;
    if (map['metadata'] != null) {
      try {
        metadata =
            jsonDecode(map['metadata'] as String) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing metadata: $e');
      }
    }

    return MessageModel(
      id: map['id'] as int,
      body: map['body'] as String,
      type: map['type'] as String,
      senderId: map['sender_id'] as int,
      conversationId: map['conversation_id'] as int,
      createdAt: map['created_at'] as String,
      editedAt: map['edited_at'] as String?,
      metadata: metadata,
      attachments: attachments,
      deleted: map['deleted'] == 1,
      senderName: map['sender_name'] as String? ?? '',
      senderProfilePic: map['sender_profile_pic'] as String?,
      replyToMessage: replyToMessage,
      replyToMessageId: replyToMessageId,
      isDelivered: map['is_delivered'] == 1,
      localMediaPath: map['local_media_path'] as String?,
    );
  }

  Future close() async => dbHelper.close();
}
