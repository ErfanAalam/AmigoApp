import 'dart:async';
import 'package:amigo/models/message.model.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift/remote.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';
import '../../types/sqlite.types.dart';

class MessageRepository {
  final sqliteDatabase = SqliteDatabase.instance;
  Timer? _cleanupTimer;

  /// Helper method to extract SQLite error code from exception
  int? _extractSqliteErrorCode(dynamic e) {
    try {
      if (e is DriftRemoteException) {
        final remoteCause = e.remoteCause;
        if (remoteCause is SqliteException) {
          return remoteCause.extendedResultCode;
        }
      }
    } catch (_) {
      // Ignore errors during error extraction
    }
    return null;
  }

  /// Helper method to convert Messages row to MessageModel
  MessageModel _messageToModel(Message message) {
    // Parse message type
    final messageType =
        MessageType.fromString(message.type) ?? MessageType.text;

    return MessageModel(
      id: message.id,
      chatId: message.chatId,
      senderId: message.senderId,
      senderName: null, // Not stored in Messages table
      senderProfilePic: null, // Not stored in Messages table
      repliedTo: message.repliedTo,
      type: messageType,
      body: message.body,
      attachments: message.attachments,
      isFailed: message.isFailed,
      sentAt: message.sentAt,
      deletedAt: message.deletedAt,
    );
  }

  /// Helper method to convert MessageModel to MessagesCompanion for insertion
  MessagesCompanion _modelToCompanion(MessageModel message) {
    return MessagesCompanion.insert(
      id: message.id,
      chatId: message.chatId,
      senderId: Value(message.senderId),
      repliedTo: Value(message.repliedTo),
      type: message.type.value,
      body: Value(message.body),
      attachments: Value(message.attachments),
      isFailed: Value(message.isFailed),
      sentAt: message.sentAt,
      deletedAt: Value(message.deletedAt),
    );
  }

  /// Insert a single message
  Future<Map<String, dynamic>> insertMessage(MessageModel message) async {
    final result = await insertMessageWithResult(message);
    return result.toMap();
  }

  /// If the message carries a server-attached `repliedToMessage` preview,
  /// build a synthetic MessageModel from it so callers can upsert it as a
  /// regular row. The real message — when later paged in via scroll — wins
  /// because we always use insertOrIgnore (preview never overwrites real).
  MessageModel? _previewToModel(MessageModel m) {
    final preview = m.repliedToMessage;
    if (preview == null) return null;
    final id = preview['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return MessageModel(
      id: id,
      chatId: m.chatId,
      senderId: preview['sender_id']?.toString(),
      senderName: preview['sender_name']?.toString(),
      type: MessageType.fromString(preview['type']?.toString()) ??
          MessageType.text,
      body: preview['body']?.toString(),
      attachments: preview['attachments'] is Map<String, dynamic>
          ? preview['attachments'] as Map<String, dynamic>
          : null,
      sentAt: preview['sent_at']?.toString() ?? m.sentAt,
    );
  }

  /// Insert a single message with SqliteResult
  Future<SqliteResult<int>> insertMessageWithResult(
    MessageModel message,
  ) async {
    final db = sqliteDatabase.database;

    try {
      await db.transaction(() async {
        final preview = _previewToModel(message);
        if (preview != null) {
          await db.into(db.messages).insert(
                _modelToCompanion(preview),
                mode: InsertMode.insertOrIgnore,
              );
        }
        final companion = _modelToCompanion(message);
        await db.into(db.messages).insert(
              companion,
              mode: InsertMode.insertOrIgnore,
            );
      });
      return SqliteResult.success(
        data: 0,
        message: 'Message inserted or already exists',
      );
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      return SqliteResult.error(
        message: 'Failed to insert message',
        errorCode: errorCode,
      );
    }
  }

  /// Insert multiple messages (bulk insert)
  /// Uses INSERT OR IGNORE so duplicates are silently skipped.
  Future<void> insertMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;

    final db = sqliteDatabase.database;
    await db.transaction(() async {
      for (final message in messages) {
        try {
          final preview = _previewToModel(message);
          if (preview != null) {
            await db.into(db.messages).insert(
                  _modelToCompanion(preview),
                  mode: InsertMode.insertOrIgnore,
                );
          }
          final companion = _modelToCompanion(message);
          await db.into(db.messages).insert(
                companion,
                mode: InsertMode.insertOrIgnore,
              );
        } catch (e) {
          debugPrint(
            "Error inserting message with ID ${message.id}: $e",
          );
        }
      }
    });
  }

  /// Save messages (alias for insertMessages for backward compatibility)
  Future<void> saveMessages(List<MessageModel> messages) async {
    await insertMessages(messages);
  }

  /// Get all messages
  Future<List<MessageModel>> getAllMessages() async {
    final db = sqliteDatabase.database;
    final messages = await db.select(db.messages)
      ..orderBy([
        (t) => OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
      ]);

    final results = await messages.get();
    return results.map((msg) => _messageToModel(msg)).toList();
  }

  /// Get messages by conversation ID with sender details
  /// This method uses SQL JOIN with the Users table to populate senderName and senderProfilePic
  Future<List<MessageModel>> getMessagesByConversation(
    String conversationId, {
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    final db = sqliteDatabase.database;

    // Create query with LEFT JOIN to Users table
    final query = db.select(db.messages).join([
      leftOuterJoin(db.users, db.users.id.equalsExp(db.messages.senderId)),
    ])..where(db.messages.chatId.equals(conversationId));

    if (!includeDeleted) {
      query.where(db.messages.deletedAt.isNull());
    }

    query.orderBy([
      OrderingTerm(expression: db.messages.sentAt, mode: OrderingMode.desc),
    ]);

    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    }

    // Execute query and map results
    final results = await query.get();

    return results.map((row) {
      final message = row.readTable(db.messages);
      final user = row.readTableOrNull(db.users);

      final messageModel = _messageToModel(message);

      return messageModel.copyWith(
        senderName: user?.name,
        senderProfilePic: user?.profilePic,
      );
    }).toList();
  }

  /// Watch messages for a conversation as a reactive Drift stream.
  /// The stream emits a new list whenever any message in this conversation
  /// is inserted, updated, or deleted in SQLite — including from FCM handlers.
  ///
  /// Messages soft-deleted globally (Messages.deletedAt) are kept in the
  /// stream so the UI can render a "this message was deleted" placeholder.
  /// Per-user "delete for me" rows (MessageInfo.deletedAt for [currentUserId])
  /// are filtered out so the message vanishes only for that user.
  Stream<List<MessageModel>> watchMessages(
    String conversationId, {
    String? currentUserId,
  }) {
    final db = sqliteDatabase.database;

    final uid = currentUserId;
    final infoForUser = uid == null ? null : db.alias(db.messageInfo, 'mi_self');

    final joins = <Join>[
      leftOuterJoin(db.users, db.users.id.equalsExp(db.messages.senderId)),
      if (infoForUser != null && uid != null)
        leftOuterJoin(
          infoForUser,
          infoForUser.messageId.equalsExp(db.messages.id) &
              infoForUser.userId.equals(uid),
        ),
    ];

    final query = db.select(db.messages).join(joins)
      ..where(db.messages.chatId.equals(conversationId));

    if (infoForUser != null) {
      query.where(infoForUser.deletedAt.isNull());
    }

    query.orderBy([
      OrderingTerm(expression: db.messages.sentAt, mode: OrderingMode.asc),
    ]);

    return query.watch().map((results) {
      return results.map((row) {
        final message = row.readTable(db.messages);
        final user = row.readTableOrNull(db.users);
        return _messageToModel(message).copyWith(
          senderName: user?.name,
          senderProfilePic: user?.profilePic,
        );
      }).toList();
    });
  }

  /// Get a single message by ID
  Future<MessageModel?> getMessageById(String messageId) async {
    final db = sqliteDatabase.database;
    final message = await (db.select(
      db.messages,
    )..where((t) => t.id.equals(messageId))).getSingleOrNull();

    if (message == null) return null;
    return _messageToModel(message);
  }

  /// Get message count for a conversation
  Future<int> getMessageCount(
    String conversationId, {
    bool includeDeleted = false,
  }) async {
    final db = sqliteDatabase.database;

    final query = db.selectOnly(db.messages)
      ..addColumns([db.messages.id.count()])
      ..where(db.messages.chatId.equals(conversationId));

    if (!includeDeleted) {
      query.where(db.messages.deletedAt.isNull());
    }

    final result = await query.getSingle();
    return result.read(db.messages.id.count()) ?? 0;
  }

  /// Get messages by IDs
  Future<List<MessageModel>> getMessagesByIds(List<String> messageIds) async {
    if (messageIds.isEmpty) return [];

    final db = sqliteDatabase.database;
    final messages = await (db.select(
      db.messages,
    )..where((t) => t.id.isIn(messageIds))).get();

    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Get messages by type
  Future<List<MessageModel>> getMessagesByType(
    MessageType type, {
    String? conversationId,
  }) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.messages)
      ..where((t) => t.type.equals(type.value));

    if (conversationId != null) {
      query.where((t) => t.chatId.equals(conversationId));
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
    ]);

    final messages = await query.get();
    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Get deleted messages for a conversation
  Future<List<MessageModel>> getDeletedMessages(String conversationId) async {
    final db = sqliteDatabase.database;
    final messages =
        await (db.select(db.messages)
              ..where(
                (t) =>
                    t.chatId.equals(conversationId) &
                    t.deletedAt.isNotNull(),
              )
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
              ]))
            .get();

    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Search messages by body text
  Future<List<MessageModel>> searchMessages(
    String searchQuery, {
    String? conversationId,
    int? limit,
  }) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.messages)
      ..where((t) => t.body.like('%$searchQuery%'));

    if (conversationId != null) {
      query.where((t) => t.chatId.equals(conversationId));
    }

    query
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
      ]);

    if (limit != null) {
      query.limit(limit);
    }

    final messages = await query.get();
    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Get last message for a conversation
  Future<MessageModel?> getLastMessage(String conversationId) async {
    final db = sqliteDatabase.database;
    final message =
        await (db.select(db.messages)
              ..where(
                (t) =>
                    t.chatId.equals(conversationId) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();

    if (message == null) return null;
    return _messageToModel(message);
  }

  /// Partially update a message by ID.
  ///
  /// Only the non-null fields you pass will be updated in the database.
  /// All other columns for that row are left unchanged.
  ///
  /// Example:
  ///   await updateMessageFields(
  ///     messageId,
  ///     body: 'new body',
  ///   );
  Future<SqliteResult> updateMessageFields(
    String messageId, {
    Map<String, dynamic>? attachments,
    String? body,
    bool? isFailed,
    bool? isDeleted,
  }) async {
    // If nothing was provided, there is nothing to do
    if (attachments == null &&
        body == null &&
        isFailed == null &&
        isDeleted == null) {
      return SqliteResult.error(message: 'No fields provided to update');
    }

    try {
      final db = sqliteDatabase.database;

      // Drift only updates the columns where the Value is present.
      final companion = MessagesCompanion(
        attachments: attachments != null
            ? Value(attachments)
            : const Value.absent(),
        body: body != null ? Value(body) : const Value.absent(),
        isFailed: isFailed != null ? Value(isFailed) : const Value.absent(),
        deletedAt: isDeleted != null
            ? Value(isDeleted ? DateTime.now().toIso8601String() : null)
            : const Value.absent(),
      );

      await (db.update(
        db.messages,
      )..where((t) => t.id.equals(messageId))).write(companion);

      return SqliteResult.success(message: 'Message fields updated');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint("Error updating message fields: $e (errorCode: $errorCode)");
      return SqliteResult.error(
        message: 'Failed to update message fields',
        errorCode: errorCode,
      );
      // Don't throw - allow operation to continue
    }
  }

  /// Delete a message (soft delete)
  Future<SqliteResult<void>> deleteMessage(String messageId) async {
    try {
      final db = sqliteDatabase.database;
      await (db.update(db.messages)
            ..where((t) => t.id.equals(messageId)))
          .write(
            MessagesCompanion(
              deletedAt: Value(DateTime.now().toIso8601String()),
            ),
          );
      return SqliteResult.success(message: 'Message deleted');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint("Error deleting message: $e");
      return SqliteResult.error(
        message: 'Failed to delete message',
        errorCode: errorCode,
      );
    }
  }

  /// Delete multiple messages (soft delete)
  Future<SqliteResult<void>> deleteMessages(List<String> messageIds) async {
    if (messageIds.isEmpty) {
      return SqliteResult.success(message: 'No messages to delete');
    }

    try {
      final db = sqliteDatabase.database;
      await (db.update(db.messages)
            ..where((t) => t.id.isIn(messageIds)))
          .write(
            MessagesCompanion(
              deletedAt: Value(DateTime.now().toIso8601String()),
            ),
          );
      return SqliteResult.success(message: 'Messages deleted');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint("Error deleting messages: $e");
      return SqliteResult.error(
        message: 'Failed to delete messages',
        errorCode: errorCode,
      );
    }
  }

  /// Permanently delete a message
  Future<bool> permanentlyDeleteMessage(String messageId) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.messages,
    )..where((t) => t.id.equals(messageId))).go();
    return deleted > 0;
  }

  /// Permanently delete multiple messages
  Future<int> permanentlyDeleteMessages(List<String> messageIds) async {
    if (messageIds.isEmpty) return 0;

    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.messages,
    )..where((t) => t.id.isIn(messageIds))).go();
    return deleted;
  }

  /// Delete all messages in a conversation
  Future<void> deleteConversationMessages(String conversationId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.chatId.equals(conversationId)))
        .write(
          MessagesCompanion(
            deletedAt: Value(DateTime.now().toIso8601String()),
          ),
        );
  }

  /// Mark a message as "deleted for me" by writing MessageInfo.deletedAt for
  /// the given user. The Messages.deletedAt column (global "deleted for
  /// everyone") is left untouched. watchMessages joins MessageInfo for the
  /// current user and filters these rows out — so they vanish locally
  /// without affecting other participants' view.
  Future<SqliteResult<void>> markDeletedForMe({
    required String messageId,
    required String userId,
    required String chatId,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final timestamp = DateTime.now().toIso8601String();
      final timestampSql = "'${timestamp.replaceAll("'", "''")}'";
      await db.customInsert(
        '''
        INSERT INTO message_info (chat_id, message_id, user_id, deleted_at)
        VALUES ('$chatId', '$messageId', '$userId', $timestampSql)
        ON CONFLICT(message_id, user_id) DO UPDATE SET
          chat_id = excluded.chat_id,
          deleted_at = excluded.deleted_at
        ''',
        updates: {db.messageInfo},
      );
      return SqliteResult.success(message: 'Message marked deleted for user');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint('Error marking message deleted for user: $e');
      return SqliteResult.error(
        message: 'Failed to mark message deleted for user',
        errorCode: errorCode,
      );
    }
  }

  /// Restore a deleted message
  Future<void> restoreMessage(String messageId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(messageId)))
        .write(const MessagesCompanion(deletedAt: Value(null)));
  }

  /// Update message body
  Future<void> updateMessageBody(String messageId, String body) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(messageId)))
        .write(MessagesCompanion(body: Value(body)));
  }

  /// Update message attachments
  Future<void> updateMessageAttachments(
    String messageId,
    Map<String, dynamic>? attachments,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(messageId)))
        .write(MessagesCompanion(attachments: Value(attachments)));
  }

  /// Update local media path for a message after caching/downloading.
  /// NOTE: localMediaPath is not persisted in SQLite — this is a no-op stub
  /// kept so callers compile. The in-memory MessageModel should be updated
  /// via copyWith() at the call site.
  Future<void> updateLocalMediaPath(
    String messageId,
    String? localMediaPath,
  ) async {
    // no-op: schema does not store localMediaPath
    return;
  }

  /// Add message to cache (alias for insertMessage)
  Future<void> addMessageToCache(MessageModel message) async {
    await insertMessage(message);
  }

  /// Add messages to cache (alias for insertMessages)
  Future<void> addMessagesToCache(List<MessageModel> messages) async {
    await insertMessages(messages);
  }

  /// Remove message from cache (delete message)
  Future<void> removeMessageFromCache(String messageId) async {
    await deleteMessage(messageId);
  }

  /// Get messages in date range
  Future<List<MessageModel>> getMessagesInDateRange(
    String conversationId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = sqliteDatabase.database;
    final startStr = startDate.toIso8601String();
    final endStr = endDate.toIso8601String();

    final messages =
        await (db.select(db.messages)
              ..where(
                (t) =>
                    t.chatId.equals(conversationId) &
                    t.sentAt.isBiggerOrEqualValue(startStr) &
                    t.sentAt.isSmallerOrEqualValue(endStr) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.sentAt, mode: OrderingMode.asc),
              ]))
            .get();

    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Get unread message count for a conversation
  Future<int> getUnreadMessageCount(
    String conversationId,
    String lastReadMessageId,
  ) async {
    final db = sqliteDatabase.database;

    final query = db.selectOnly(db.messages)
      ..addColumns([db.messages.id.count()])
      ..where(
        db.messages.chatId.equals(conversationId) &
            db.messages.id.isBiggerThanValue(lastReadMessageId) &
            db.messages.deletedAt.isNull(),
      );

    final result = await query.getSingle();
    return result.read(db.messages.id.count()) ?? 0;
  }

  /// Clear all messages (permanently delete)
  Future<void> clearAllMessages() async {
    final db = sqliteDatabase.database;
    await db.delete(db.messages).go();
  }

  /// Clear messages for a conversation (permanently delete)
  Future<void> clearConversationMessages(String conversationId) async {
    final db = sqliteDatabase.database;
    await (db.delete(
      db.messages,
    )..where((t) => t.chatId.equals(conversationId))).go();
  }

  /// Get messages with media attachments
  Future<List<MessageModel>> getMediaMessages({
    String? conversationId,
    MessageType? mediaType,
  }) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.messages)
      ..where((t) => t.attachments.isNotNull());

    if (conversationId != null) {
      query.where((t) => t.chatId.equals(conversationId));
    }

    if (mediaType != null) {
      query.where((t) => t.type.equals(mediaType.value));
    }

    query
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
      ]);

    final messages = await query.get();
    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Check if message exists
  Future<bool> messageExists(String messageId) async {
    final db = sqliteDatabase.database;
    final message = await (db.select(
      db.messages,
    )..where((t) => t.id.equals(messageId))).getSingleOrNull();
    return message != null;
  }

  /// Get message statistics for a conversation
  Future<Map<String, dynamic>> getMessageStatistics(
    String conversationId,
  ) async {
    final db = sqliteDatabase.database;

    final totalQuery = db.selectOnly(db.messages)
      ..addColumns([db.messages.id.count()])
      ..where(db.messages.chatId.equals(conversationId));

    final totalResult = await totalQuery.getSingle();
    final total = totalResult.read(db.messages.id.count()) ?? 0;

    final mediaQuery = db.selectOnly(db.messages)
      ..addColumns([db.messages.id.count()])
      ..where(
        db.messages.chatId.equals(conversationId) &
            db.messages.attachments.isNotNull(),
      );

    final mediaResult = await mediaQuery.getSingle();
    final mediaCount = mediaResult.read(db.messages.id.count()) ?? 0;

    return {
      'total': total,
      'media': mediaCount,
      'text': total - mediaCount,
    };
  }

  /// Start the automatic cleanup timer that runs every 10 seconds
  void startCleanupTimer() {
    _stopCleanupTimer(); // Stop any existing timer first

    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      // No-op cleanup; optimistic-ID reconciliation is no longer needed with
      // monotonic UUIDv7 client-generated ids.
    });

    debugPrint('✅ Optimistic message cleanup timer started (every 10 seconds)');
  }

  /// Stop the automatic cleanup timer
  void stopCleanupTimer() {
    _stopCleanupTimer();
  }

  void _stopCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  /// Failed messages for the given sender only.
  Future<List<MessageModel>> getStalledMessages({
    required String userId,
    required Duration unsentThreshold,
  }) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.messages)
      ..where(
        (t) =>
            t.senderId.equals(userId) &
            t.deletedAt.isNull() &
            t.isFailed.equals(true),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.sentAt)]);

    final rows = await query.get();
    return rows.map(_messageToModel).toList();
  }

  /// Dispose resources and stop the cleanup timer
  void dispose() {
    _stopCleanupTimer();
  }
}
