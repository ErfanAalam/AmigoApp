import 'package:amigo/utils/chat/chat-helpers.utils.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift/remote.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../models/message-status.model.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart' hide MessageStatusModel;
import '../../types/sqlite.types.dart';

class MessageStatusRepository {
  final sqliteDatabase = SqliteDatabase.instance;

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

  /// Helper method to convert MessageStatusModelData row to MessageStatusType model
  MessageStatusModel _statusToModel(MessageStatusModelData status) {
    return MessageStatusModel(
      id: status.id,
      conversationId: status.conversationId,
      messageId: status.messageId.toInt(),
      userId: status.userId,
      deliveredAt: status.deliveredAt,
      readAt: status.readAt,
      reaction: status.reaction,
    );
  }

  /// Insert a single message status
  Future<SqliteResult<void>> insertMessageStatus({
    required int conversationId,
    required int messageId,
    required int userId,
    String? deliveredAt,
    String? readAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final deliveredAtValue = deliveredAt != null
          ? "'${deliveredAt.replaceAll("'", "''")}'"
          : 'NULL';
      final readAtValue = readAt != null
          ? "'${readAt.replaceAll("'", "''")}'"
          : 'NULL';
      await db.customStatement('''
        INSERT INTO message_status_model (conversation_id, message_id, user_id, delivered_at, read_at)
        VALUES ($conversationId, ${BigInt.from(messageId)}, $userId, $deliveredAtValue, $readAtValue)
        ON CONFLICT(message_id, user_id) DO UPDATE SET
          conversation_id = excluded.conversation_id,
          delivered_at = COALESCE(excluded.delivered_at, message_status_model.delivered_at),
          read_at = COALESCE(excluded.read_at, message_status_model.read_at)
      ''');
      return SqliteResult.success(message: 'Message status inserted');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint("Error inserting message status: $e");
      return SqliteResult.error(
        message: 'Failed to insert message status',
        errorCode: errorCode,
      );
    }
  }

  /// Insert multiple message statuses (bulk insert)
  /// Uses raw SQL with ON CONFLICT to handle unique constraint on (message_id, user_id)
  /// This is much more efficient than checking existence first - single DB call per status
  /// No existence check needed - ON CONFLICT handles duplicates automatically
  Future<void> insertMessageStatuses(
    List<Map<String, dynamic>> statuses,
  ) async {
    if (statuses.isEmpty) return;

    final db = sqliteDatabase.database;
    await db.transaction(() async {
      // Use raw SQL with ON CONFLICT targeting the unique index (message_id, user_id)
      // This avoids the need to check existence first, reducing DB calls significantly
      // COALESCE preserves existing values if new ones are null
      for (final status in statuses) {
        try {
          final messageId = ChatHelpers.parseToInt(status['messageId']);
          final userId = status['userId'] as int;
          final conversationId = status['conversationId'] as int;
          final deliveredAt = status['deliveredAt'] as String?;
          final readAt = status['readAt'] as String?;
          final reaction = status['reaction'] as String?;

          // Escape SQL strings properly - values are already validated from status map
          final deliveredAtValue = deliveredAt != null
              ? "'${deliveredAt.replaceAll("'", "''")}'"
              : 'NULL';
          final readAtValue = readAt != null
              ? "'${readAt.replaceAll("'", "''")}'"
              : 'NULL';
          final reactionValue = reaction != null
              ? "'${reaction.replaceAll("'", "''")}'"
              : 'NULL';

          await db.customInsert(
            '''
            INSERT INTO message_status_model (
              conversation_id, message_id, user_id, delivered_at, read_at, reaction
            ) VALUES ($conversationId, ${BigInt.from(messageId)}, $userId, $deliveredAtValue, $readAtValue, $reactionValue)
            ON CONFLICT(message_id, user_id) DO UPDATE SET
              conversation_id = excluded.conversation_id,
              delivered_at = COALESCE(excluded.delivered_at, message_status_model.delivered_at),
              read_at = COALESCE(excluded.read_at, message_status_model.read_at),
              reaction = COALESCE(excluded.reaction, message_status_model.reaction)
            ''',
            updates: {db.messageStatusModel},
          );
        } catch (e) {
          final errorCode = _extractSqliteErrorCode(e);
          // Only log non-duplicate errors (duplicates are expected and handled by ON CONFLICT)
          if (errorCode != 1555 && errorCode != 2067) {
            debugPrint(
              "Error inserting message status: $e (errorCode: $errorCode)",
            );
          }
          // Continue with next status instead of failing the whole batch
        }
      }
    });
  }

  // Insert messagestatus with multiple userids for a message
  /// Continues inserting even if some statuses fail (e.g., duplicates)
  Future<void> insertMessageStatusesWithMultipleUserIds({
    required int messageId,
    required int conversationId,
    required List<int> userIds,
    String? deliveredAt,
    String? readAt,
  }) async {
    final db = sqliteDatabase.database;
    await db.transaction(() async {
      for (final userId in userIds) {
        try {
          await insertMessageStatus(
            conversationId: conversationId,
            messageId: messageId,
            userId: userId,
            deliveredAt: deliveredAt,
            readAt: readAt,
          );
        } catch (e) {
          final errorCode = _extractSqliteErrorCode(e);
          // Only log non-duplicate errors (duplicates are expected)
          if (errorCode != 1555) {
            debugPrint(
              "Error inserting message status for userId $userId: $e (errorCode: $errorCode)",
            );
          }
          // Continue with next user instead of failing the whole batch
        }
      }
    });
  }

  /// Get all message statuses
  Future<List<MessageStatusModel>> getAllMessageStatuses() async {
    final db = sqliteDatabase.database;
    final statuses = await db.select(db.messageStatusModel).get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Get message status by ID
  Future<MessageStatusModel?> getMessageStatusById(int id) async {
    final db = sqliteDatabase.database;
    final status = await (db.select(
      db.messageStatusModel,
    )..where((t) => t.id.equals(BigInt.from(id)))).getSingleOrNull();

    if (status == null) return null;
    return _statusToModel(status);
  }

  /// Get message statuses by messageId
  Future<List<MessageStatusModel>> getMessageStatusesByMessageId(
    int messageId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses = await (db.select(
      db.messageStatusModel,
    )..where((t) => t.messageId.equals(BigInt.from(messageId)))).get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Get message statuses by conversationId
  Future<List<MessageStatusModel>> getMessageStatusesByConversationId(
    int conversationId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses = await (db.select(
      db.messageStatusModel,
    )..where((t) => t.conversationId.equals(conversationId))).get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Get message statuses by userId
  Future<List<MessageStatusModel>> getMessageStatusesByUserId(
    int userId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses = await (db.select(
      db.messageStatusModel,
    )..where((t) => t.userId.equals(userId))).get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Get all rows by messageId (returns raw data)
  Future<List<MessageStatusModelData>> getAllReadStatusesByMessageId(
    int messageId,
  ) async {
    final db = sqliteDatabase.database;
    final rows =
        await (db.select(db.messageStatusModel)..where(
              (t) =>
                  t.messageId.equals(BigInt.from(messageId)) &
                  t.readAt.isNotNull(),
            ))
            .get();
    return rows;
  }

  Future<List<MessageStatusModelData>> getAllDeliveredStatusesByMessageId(
    int messageId,
  ) async {
    final db = sqliteDatabase.database;
    final rows =
        await (db.select(db.messageStatusModel)..where(
              (t) =>
                  t.messageId.equals(BigInt.from(messageId)) &
                  t.deliveredAt.isNotNull(),
            ))
            .get();
    return rows;
  }

  /// Get all rows by conversationId (returns raw data)
  Future<List<MessageStatusModelData>> getAllRowsByConversationId(
    int conversationId,
  ) async {
    final db = sqliteDatabase.database;
    final rows = await (db.select(
      db.messageStatusModel,
    )..where((t) => t.conversationId.equals(conversationId))).get();
    return rows;
  }

  /// Get message status by messageId and userId (specific user's status for a message)
  Future<MessageStatusModel?> getMessageStatusByMessageAndUser(
    int messageId,
    int userId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses =
        await (db.select(db.messageStatusModel)..where(
              (t) =>
                  t.messageId.equals(BigInt.from(messageId)) &
                  t.userId.equals(userId),
            ))
            .get();

    if (statuses.isEmpty) return null;

    // If there are duplicates, return the first one and clean up duplicates
    if (statuses.length > 1) {
      // Keep the first one (usually the most recent due to auto-increment id)
      final firstStatus = statuses.first;

      // Delete duplicates in a transaction
      await db.transaction(() async {
        for (int i = 1; i < statuses.length; i++) {
          await (db.delete(
            db.messageStatusModel,
          )..where((t) => t.id.equals(statuses[i].id))).go();
        }
      });

      return _statusToModel(firstStatus);
    }

    return _statusToModel(statuses.first);
  }

  /// Get all read statuses for a message
  Future<List<MessageStatusModel>> getReadStatusesByMessageId(
    int messageId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses =
        await (db.select(db.messageStatusModel)..where(
              (t) =>
                  t.messageId.equals(BigInt.from(messageId)) &
                  t.readAt.isNotNull(),
            ))
            .get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Get all delivered statuses for a message
  Future<List<MessageStatusModel>> getDeliveredStatusesByMessageId(
    int messageId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses =
        await (db.select(db.messageStatusModel)..where(
              (t) =>
                  t.messageId.equals(BigInt.from(messageId)) &
                  t.deliveredAt.isNotNull(),
            ))
            .get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Mark message as delivered for a user
  Future<SqliteResult<void>> markAsDelivered({
    required int messageId,
    required int userId,
    String? deliveredAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final timestamp = deliveredAt ?? DateTime.now().toIso8601String();

      final message = await (db.select(
        db.messages,
      )..where((t) => t.id.equals(BigInt.from(messageId)))).getSingleOrNull();

      if (message != null) {
        final deliveredAtSql = "'${timestamp.replaceAll("'", "''")}'" ;
        await db.customStatement('''
          INSERT INTO message_status_model (conversation_id, message_id, user_id, delivered_at)
          VALUES (${message.conversationId}, ${BigInt.from(messageId)}, $userId, $deliveredAtSql)
          ON CONFLICT(message_id, user_id) DO UPDATE SET
            conversation_id = excluded.conversation_id,
            delivered_at = excluded.delivered_at
        ''');
        return SqliteResult.success(message: 'Message marked as delivered');
      } else {
        return SqliteResult.error(message: 'Message not found');
      }
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint("Error marking message as delivered: $e");
      return SqliteResult.error(
        message: 'Failed to mark message as delivered',
        errorCode: errorCode,
      );
    }
  }

  /// Mark message as read for a user
  Future<SqliteResult<void>> markAsRead({
    required int messageId,
    required int userId,
    String? readAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final timestamp = readAt ?? DateTime.now().toIso8601String();

      final message = await (db.select(
        db.messages,
      )..where((t) => t.id.equals(BigInt.from(messageId)))).getSingleOrNull();

      if (message != null) {
        final timestampSql = "'${timestamp.replaceAll("'", "''")}'";
        await db.customStatement('''
          INSERT INTO message_status_model (conversation_id, message_id, user_id, delivered_at, read_at)
          VALUES (${message.conversationId}, ${BigInt.from(messageId)}, $userId, $timestampSql, $timestampSql)
          ON CONFLICT(message_id, user_id) DO UPDATE SET
            conversation_id = excluded.conversation_id,
            delivered_at = COALESCE(message_status_model.delivered_at, excluded.delivered_at),
            read_at = excluded.read_at
        ''');
        return SqliteResult.success(message: 'Message marked as read');
      } else {
        return SqliteResult.error(message: 'Message not found');
      }
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint("Error marking message as read: $e");
      return SqliteResult.error(
        message: 'Failed to mark message as read',
        errorCode: errorCode,
      );
    }
  }

  /// Mark multiple messages as delivered for a user
  /// Continues processing even if some operations fail
  Future<void> markMultipleAsDelivered({
    required List<int> messageIds,
    required int userId,
    String? deliveredAt,
  }) async {
    if (messageIds.isEmpty) return;

    final db = sqliteDatabase.database;
    final timestamp = deliveredAt ?? DateTime.now().toIso8601String();

    await db.transaction(() async {
      for (final messageId in messageIds) {
        try {
          final message =
              await (db.select(db.messages)
                    ..where((t) => t.id.equals(BigInt.from(messageId))))
                  .getSingleOrNull();

          if (message != null) {
            final deliveredAtSql = "'${timestamp.replaceAll("'", "''")}'";
            await db.customStatement('''
              INSERT INTO message_status_model (conversation_id, message_id, user_id, delivered_at)
              VALUES (${message.conversationId}, ${BigInt.from(messageId)}, $userId, $deliveredAtSql)
              ON CONFLICT(message_id, user_id) DO UPDATE SET
                conversation_id = excluded.conversation_id,
                delivered_at = excluded.delivered_at
            ''');
          }
        } catch (e) {
          final errorCode = _extractSqliteErrorCode(e);
          debugPrint(
            "Error marking message $messageId as delivered: $e (errorCode: $errorCode)",
          );
          // Continue with next message instead of failing the whole batch
        }
      }
    });
  }

  /// Mark multiple messages as read for a user
  /// Continues processing even if some operations fail
  Future<void> markMultipleAsRead({
    required List<int> messageIds,
    required int userId,
    String? readAt,
  }) async {
    if (messageIds.isEmpty) return;

    final db = sqliteDatabase.database;
    final timestamp = readAt ?? DateTime.now().toIso8601String();

    await db.transaction(() async {
      for (final messageId in messageIds) {
        try {
          final message =
              await (db.select(db.messages)
                    ..where((t) => t.id.equals(BigInt.from(messageId))))
                  .getSingleOrNull();

          if (message != null) {
            final timestampSql = "'${timestamp.replaceAll("'", "''")}'";
            await db.customStatement('''
              INSERT INTO message_status_model (conversation_id, message_id, user_id, delivered_at, read_at)
              VALUES (${message.conversationId}, ${BigInt.from(messageId)}, $userId, $timestampSql, $timestampSql)
              ON CONFLICT(message_id, user_id) DO UPDATE SET
                conversation_id = excluded.conversation_id,
                delivered_at = COALESCE(message_status_model.delivered_at, excluded.delivered_at),
                read_at = excluded.read_at
            ''');
          }
        } catch (e) {
          final errorCode = _extractSqliteErrorCode(e);
          debugPrint(
            "Error marking message $messageId as read: $e (errorCode: $errorCode)",
          );
          // Continue with next message instead of failing the whole batch
        }
      }
    });
  }

  /// Update deliveredAt timestamp
  Future<void> updateDeliveredAt({
    required int messageId,
    String? deliveredAt,
  }) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messageStatusModel)
          ..where((t) => t.messageId.equals(BigInt.from(messageId))))
        .write(MessageStatusModelCompanion(deliveredAt: Value(deliveredAt)));
  }

  // update deliveredAt timestamp for a specific user with message id
  Future<SqliteResult<void>> updateDeliveredAtForUser({
    required int messageId,
    required int userId,
    required int conversationId,
    String? deliveredAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final deliveredAtSql = deliveredAt != null
          ? "'${deliveredAt.replaceAll("'", "''")}'"
          : 'NULL';
      await db.customStatement('''
        INSERT INTO message_status_model (conversation_id, message_id, user_id, delivered_at)
        VALUES ($conversationId, ${BigInt.from(messageId)}, $userId, $deliveredAtSql)
        ON CONFLICT(message_id, user_id) DO UPDATE SET
          conversation_id = excluded.conversation_id,
          delivered_at = excluded.delivered_at
      ''');
      return SqliteResult.success(message: 'DeliveredAt updated');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint(
        'Error updating deliveredAt for messageId $messageId and userId $userId: $e',
      );
      return SqliteResult.error(
        message: 'Failed to update deliveredAt',
        errorCode: errorCode,
      );
    }
  }

  // update readAt timestamp for a specific user with message id
  Future<SqliteResult<void>> updateReadAtForUser({
    required int messageId,
    required int userId,
    required int conversationId,
    String? readAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final readAtSql = readAt != null
          ? "'${readAt.replaceAll("'", "''")}'"
          : 'NULL';
      await db.customStatement('''
        INSERT INTO message_status_model (conversation_id, message_id, user_id, read_at)
        VALUES ($conversationId, ${BigInt.from(messageId)}, $userId, $readAtSql)
        ON CONFLICT(message_id, user_id) DO UPDATE SET
          conversation_id = excluded.conversation_id,
          read_at = excluded.read_at
      ''');
      return SqliteResult.success(message: 'ReadAt updated');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint(
        'Error updating readAt for messageId $messageId and userId $userId: $e',
      );
      return SqliteResult.error(
        message: 'Failed to update readAt',
        errorCode: errorCode,
      );
    }
  }

  /// Delete message status by ID
  Future<bool> deleteMessageStatus(int id) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.messageStatusModel,
    )..where((t) => t.id.equals(BigInt.from(id)))).go();
    return deleted > 0;
  }

  /// Delete message statuses by messageId
  Future<void> deleteMessageStatusesByMessageId(int messageId) async {
    final db = sqliteDatabase.database;
    await (db.delete(
      db.messageStatusModel,
    )..where((t) => t.messageId.equals(BigInt.from(messageId)))).go();
  }

  /// Delete message statuses by conversationId
  Future<void> deleteMessageStatusesByConversationId(int conversationId) async {
    final db = sqliteDatabase.database;
    await (db.delete(
      db.messageStatusModel,
    )..where((t) => t.conversationId.equals(conversationId))).go();
  }

  /// Delete message status by messageId and userId
  Future<bool> deleteMessageStatusByMessageAndUser(
    int messageId,
    int userId,
  ) async {
    final db = sqliteDatabase.database;
    final deleted =
        await (db.delete(db.messageStatusModel)..where(
              (t) =>
                  t.messageId.equals(BigInt.from(messageId)) &
                  t.userId.equals(userId),
            ))
            .go();
    return deleted > 0;
  }

  /// Clear all message statuses
  Future<void> clearAllMessageStatuses() async {
    final db = sqliteDatabase.database;
    await db.delete(db.messageStatusModel).go();
  }

  /// Get read count for a message
  Future<int> getReadCountByMessageId(int messageId) async {
    final db = sqliteDatabase.database;
    final count =
        await (db.selectOnly(db.messageStatusModel)
              ..addColumns([db.messageStatusModel.id.count()])
              ..where(
                db.messageStatusModel.messageId.equals(BigInt.from(messageId)) &
                    db.messageStatusModel.readAt.isNotNull(),
              ))
            .getSingle();
    return count.read(db.messageStatusModel.id.count()) ?? 0;
  }

  /// Get delivered count for a message
  Future<int> getDeliveredCountByMessageId(int messageId) async {
    final db = sqliteDatabase.database;
    final count =
        await (db.selectOnly(db.messageStatusModel)
              ..addColumns([db.messageStatusModel.id.count()])
              ..where(
                db.messageStatusModel.messageId.equals(BigInt.from(messageId)) &
                    db.messageStatusModel.deliveredAt.isNotNull(),
              ))
            .getSingle();
    return count.read(db.messageStatusModel.id.count()) ?? 0;
  }

  /// Get unread count for a message
  Future<int> getUnreadCountByMessageId(int messageId) async {
    final db = sqliteDatabase.database;
    final totalCount =
        await (db.selectOnly(db.messageStatusModel)
              ..addColumns([db.messageStatusModel.id.count()])
              ..where(
                db.messageStatusModel.messageId.equals(BigInt.from(messageId)),
              ))
            .getSingle();
    final readCount = await getReadCountByMessageId(messageId);
    return (totalCount.read(db.messageStatusModel.id.count()) ?? 0) - readCount;
  }

  /// Get undelivered count for a message
  Future<int> getUndeliveredCountByMessageId(int messageId) async {
    final db = sqliteDatabase.database;
    final totalCount =
        await (db.selectOnly(db.messageStatusModel)
              ..addColumns([db.messageStatusModel.id.count()])
              ..where(
                db.messageStatusModel.messageId.equals(BigInt.from(messageId)),
              ))
            .getSingle();
    final deliveredCount = await getDeliveredCountByMessageId(messageId);
    return (totalCount.read(db.messageStatusModel.id.count()) ?? 0) -
        deliveredCount;
  }

  /// Check if message is read by user
  Future<bool> isReadByUser(int messageId, int userId) async {
    final status = await getMessageStatusByMessageAndUser(messageId, userId);
    return status != null && status.readAt != null;
  }

  /// Check if message is delivered to user
  Future<bool> isDeliveredToUser(int messageId, int userId) async {
    final status = await getMessageStatusByMessageAndUser(messageId, userId);
    return status != null && status.deliveredAt != null;
  }

  // update the message id in the message status table
  Future<SqliteResult<void>> updateMessageId(
    int optimisticId,
    int canonicalId,
  ) async {
    try {
      final db = sqliteDatabase.database;
      await (db.update(
        db.messageStatusModel,
      )..where((t) => t.messageId.equals(BigInt.from(optimisticId)))).write(
        MessageStatusModelCompanion(messageId: Value(BigInt.from(canonicalId))),
      );
      return SqliteResult.success(message: 'Message ID updated');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint("Error updating message ID: $e");
      return SqliteResult.error(
        message: 'Failed to update message ID',
        errorCode: errorCode,
      );
    }
  }

  /// Mark all messages in a conversation as read for a user where readAt is null
  Future<SqliteResult<void>> markAllAsReadByConversationAndUser({
    required int conversationId,
    required int userId,
    String? readAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final timestamp = readAt ?? DateTime.now().toIso8601String();

      // Bulk update all undelivered statuses in a single query
      await (db.update(db.messageStatusModel)
            ..where((t) => t.userId.equals(userId) & t.readAt.isNull()))
          .write(MessageStatusModelCompanion(readAt: Value(timestamp)));
      return SqliteResult.success(message: 'All messages marked as read');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint(
        'Error marking all as read for conversation $conversationId and user $userId: $e',
      );
      return SqliteResult.error(
        message: 'Failed to mark all messages as read',
        errorCode: errorCode,
      );
    }
  }

  /// Upsert the emoji reaction for a specific user on a specific message.
  /// Pass [emoji] = null to clear the reaction.
  Future<void> upsertReaction({
    required int messageId,
    required int userId,
    required int conversationId,
    String? emoji,
  }) async {
    final db = sqliteDatabase.database;
    final emojiValue = emoji != null ? "'${emoji.replaceAll("'", "''")}'" : 'NULL';
    // Use customInsert (not customStatement) so Drift notifies reactive stream watchers.
    await db.customInsert(
      '''
      INSERT INTO message_status_model (conversation_id, message_id, user_id, reaction)
      VALUES ($conversationId, ${BigInt.from(messageId)}, $userId, $emojiValue)
      ON CONFLICT(message_id, user_id) DO UPDATE SET
        reaction = $emojiValue
      ''',
      updates: {db.messageStatusModel},
    );
  }

  /// Watch all emoji reactions for messages in a conversation.
  /// Returns a reactive map of messageId -> { emoji: [{user_id, user_name}] }
  Stream<Map<int, Map<String, dynamic>>> watchReactionsByConversation(
    int conversationId,
  ) {
    final db = sqliteDatabase.database;
    final query = db.customSelect(
      '''
      SELECT ms.message_id, ms.user_id, ms.reaction, u.name as user_name
      FROM message_status_model ms
      LEFT JOIN users u ON ms.user_id = u.id
      WHERE ms.conversation_id = ? AND ms.reaction IS NOT NULL
      ''',
      variables: [Variable.withInt(conversationId)],
      readsFrom: {db.messageStatusModel, db.users},
    );
    return query.watch().map((rows) {
      final Map<int, Map<String, dynamic>> result = {};
      for (final row in rows) {
        final msgId = row.read<int>('message_id');
        final userId = row.read<int>('user_id');
        final emoji = row.read<String?>('reaction');
        final userName = row.read<String?>('user_name') ?? 'User $userId';
        if (emoji == null) continue;
        result.putIfAbsent(msgId, () => {});
        result[msgId]!.putIfAbsent(emoji, () => <Map<String, dynamic>>[]);
        (result[msgId]![emoji] as List<Map<String, dynamic>>).add({
          'user_id': userId,
          'user_name': userName,
          'reacted_at': '',
        });
      }
      return result;
    });
  }

  /// mark all undelivered message_status as delivered for a user
  Future<SqliteResult<void>> markAllAsDeliveredForUser({
    required int userId,
    String? deliveredAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final timestamp = deliveredAt ?? DateTime.now().toIso8601String();
      // Bulk update all undelivered statuses in a single query
      await (db.update(db.messageStatusModel)
            ..where((t) => t.userId.equals(userId) & t.deliveredAt.isNull()))
          .write(MessageStatusModelCompanion(deliveredAt: Value(timestamp)));
      return SqliteResult.success(message: 'All messages marked as delivered');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint('Error marking all as delivered for user $userId: $e');
      return SqliteResult.error(
        message: 'Failed to mark all messages as delivered',
        errorCode: errorCode,
      );
    }
  }
}
