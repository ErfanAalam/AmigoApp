import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift/remote.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/message-status.model.dart';
import '../../types/socket.types.dart' show MessageStatusType;
import '../sqlite.db.dart';
import '../sqlite.schema.dart';
import '../../types/sqlite.types.dart';

class MessageStatusRepository {
  final sqliteDatabase = SqliteDatabase.instance;
  static const _uuid = Uuid();

  int? _extractSqliteErrorCode(dynamic e) {
    try {
      if (e is DriftRemoteException) {
        final remoteCause = e.remoteCause;
        if (remoteCause is SqliteException) {
          return remoteCause.extendedResultCode;
        }
      }
    } catch (_) {}
    return null;
  }

  MessageInfoModel _rowToModel(MessageInfoData row) {
    return MessageInfoModel(
      id: row.id,
      chatId: row.chatId,
      messageId: row.messageId,
      userId: row.userId,
      deliveredAt: row.deliveredAt,
      readAt: row.readAt,
      reaction: row.reaction,
      deletedAt: row.deletedAt,
    );
  }

  /// Insert a single message info row
  Future<SqliteResult<void>> insertMessageStatus({
    required String chatId,
    required String messageId,
    required String userId,
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
      final id = _uuid.v4();
      await db.customInsert(
        '''
        INSERT INTO message_info (id, chat_id, message_id, user_id, delivered_at, read_at)
        VALUES ('$id', '$chatId', '$messageId', '$userId', $deliveredAtValue, $readAtValue)
        ON CONFLICT(message_id, user_id) DO UPDATE SET
          chat_id = excluded.chat_id,
          delivered_at = COALESCE(excluded.delivered_at, message_info.delivered_at),
          read_at = COALESCE(excluded.read_at, message_info.read_at)
        ''',
        updates: {db.messageInfo},
      );
      return SqliteResult.success(message: 'Message info inserted');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint("Error inserting message info: $e");
      return SqliteResult.error(
        message: 'Failed to insert message info',
        errorCode: errorCode,
      );
    }
  }

  /// Insert multiple message info rows in a single transaction.
  Future<void> insertMessageStatuses(
    List<Map<String, dynamic>> statuses,
  ) async {
    if (statuses.isEmpty) return;

    final db = sqliteDatabase.database;
    await db.transaction(() async {
      for (final status in statuses) {
        try {
          final messageId = status['messageId'].toString();
          final userId = status['userId'].toString();
          final chatId = (status['chatId'] ?? status['conversationId'])
              .toString();
          final deliveredAt = status['deliveredAt'] as String?;
          final readAt = status['readAt'] as String?;
          final reaction = status['reaction'] as String?;

          final deliveredAtValue = deliveredAt != null
              ? "'${deliveredAt.replaceAll("'", "''")}'"
              : 'NULL';
          final readAtValue = readAt != null
              ? "'${readAt.replaceAll("'", "''")}'"
              : 'NULL';
          final reactionValue = reaction != null
              ? "'${reaction.replaceAll("'", "''")}'"
              : 'NULL';
          final id = _uuid.v4();

          await db.customInsert(
            '''
            INSERT INTO message_info (
              id, chat_id, message_id, user_id, delivered_at, read_at, reaction
            ) VALUES ('$id', '$chatId', '$messageId', '$userId', $deliveredAtValue, $readAtValue, $reactionValue)
            ON CONFLICT(message_id, user_id) DO UPDATE SET
              chat_id = excluded.chat_id,
              delivered_at = COALESCE(excluded.delivered_at, message_info.delivered_at),
              read_at = COALESCE(excluded.read_at, message_info.read_at),
              reaction = COALESCE(excluded.reaction, message_info.reaction)
            ''',
            updates: {db.messageInfo},
          );
        } catch (e) {
          final errorCode = _extractSqliteErrorCode(e);
          if (errorCode != 1555 && errorCode != 2067) {
            debugPrint(
              "Error inserting message info: $e (errorCode: $errorCode)",
            );
          }
        }
      }
    });
  }

  Future<void> insertMessageStatusesWithMultipleUserIds({
    required String messageId,
    required String chatId,
    required List<String> userIds,
    String? deliveredAt,
    String? readAt,
  }) async {
    final db = sqliteDatabase.database;
    await db.transaction(() async {
      for (final userId in userIds) {
        try {
          await insertMessageStatus(
            chatId: chatId,
            messageId: messageId,
            userId: userId,
            deliveredAt: deliveredAt,
            readAt: readAt,
          );
        } catch (e) {
          final errorCode = _extractSqliteErrorCode(e);
          if (errorCode != 1555) {
            debugPrint(
              "Error inserting message info for userId $userId: $e (errorCode: $errorCode)",
            );
          }
        }
      }
    });
  }

  Future<List<MessageInfoModel>> getAllMessageStatuses() async {
    final db = sqliteDatabase.database;
    final rows = await db.select(db.messageInfo).get();
    return rows.map(_rowToModel).toList();
  }

  Future<MessageInfoModel?> getMessageStatusById(String id) async {
    final db = sqliteDatabase.database;
    final row = await (db.select(
      db.messageInfo,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _rowToModel(row);
  }

  Future<List<MessageInfoModel>> getMessageStatusesByMessageId(
    String messageId,
  ) async {
    final db = sqliteDatabase.database;
    final rows = await (db.select(
      db.messageInfo,
    )..where((t) => t.messageId.equals(messageId))).get();
    return rows.map(_rowToModel).toList();
  }

  Future<List<MessageInfoModel>> getMessageStatusesByConversationId(
    String chatId,
  ) async {
    final db = sqliteDatabase.database;
    final rows = await (db.select(
      db.messageInfo,
    )..where((t) => t.chatId.equals(chatId))).get();
    return rows.map(_rowToModel).toList();
  }

  Future<List<MessageInfoModel>> getMessageStatusesByUserId(
    String userId,
  ) async {
    final db = sqliteDatabase.database;
    final rows = await (db.select(
      db.messageInfo,
    )..where((t) => t.userId.equals(userId))).get();
    return rows.map(_rowToModel).toList();
  }

  Future<List<MessageInfoData>> getAllReadStatusesByMessageId(
    String messageId,
  ) async {
    final db = sqliteDatabase.database;
    return (db.select(db.messageInfo)
          ..where((t) => t.messageId.equals(messageId) & t.readAt.isNotNull()))
        .get();
  }

  Future<List<MessageInfoData>> getAllDeliveredStatusesByMessageId(
    String messageId,
  ) async {
    final db = sqliteDatabase.database;
    return (db.select(db.messageInfo)..where(
          (t) => t.messageId.equals(messageId) & t.deliveredAt.isNotNull(),
        ))
        .get();
  }

  Future<List<MessageInfoData>> getAllRowsByConversationId(
    String chatId,
  ) async {
    final db = sqliteDatabase.database;
    return (db.select(
      db.messageInfo,
    )..where((t) => t.chatId.equals(chatId))).get();
  }

  Future<MessageInfoModel?> getMessageStatusByMessageAndUser(
    String messageId,
    String userId,
  ) async {
    final db = sqliteDatabase.database;
    final rows =
        await (db.select(db.messageInfo)..where(
              (t) => t.messageId.equals(messageId) & t.userId.equals(userId),
            ))
            .get();

    if (rows.isEmpty) return null;

    if (rows.length > 1) {
      final first = rows.first;
      await db.transaction(() async {
        for (int i = 1; i < rows.length; i++) {
          await (db.delete(
            db.messageInfo,
          )..where((t) => t.id.equals(rows[i].id))).go();
        }
      });
      return _rowToModel(first);
    }

    return _rowToModel(rows.first);
  }

  Future<List<MessageInfoModel>> getReadStatusesByMessageId(
    String messageId,
  ) async {
    final db = sqliteDatabase.database;
    final rows =
        await (db.select(db.messageInfo)..where(
              (t) => t.messageId.equals(messageId) & t.readAt.isNotNull(),
            ))
            .get();
    return rows.map(_rowToModel).toList();
  }

  Future<List<MessageInfoModel>> getDeliveredStatusesByMessageId(
    String messageId,
  ) async {
    final db = sqliteDatabase.database;
    final rows =
        await (db.select(db.messageInfo)..where(
              (t) => t.messageId.equals(messageId) & t.deliveredAt.isNotNull(),
            ))
            .get();
    return rows.map(_rowToModel).toList();
  }

  Future<SqliteResult<void>> markAsDelivered({
    required String messageId,
    required String userId,
    String? deliveredAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final timestamp = deliveredAt ?? DateTime.now().toIso8601String();

      final message = await (db.select(
        db.messages,
      )..where((t) => t.id.equals(messageId))).getSingleOrNull();

      if (message != null) {
        final deliveredAtSql = "'${timestamp.replaceAll("'", "''")}'";
        final id = _uuid.v4();
        await db.customInsert(
          '''
          INSERT INTO message_info (id, chat_id, message_id, user_id, delivered_at)
          VALUES ('$id', '${message.chatId}', '$messageId', '$userId', $deliveredAtSql)
          ON CONFLICT(message_id, user_id) DO UPDATE SET
            chat_id = excluded.chat_id,
            delivered_at = excluded.delivered_at
          ''',
          updates: {db.messageInfo},
        );
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

  Future<SqliteResult<void>> markAsRead({
    required String messageId,
    required String userId,
    String? readAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final timestamp = readAt ?? DateTime.now().toIso8601String();

      final message = await (db.select(
        db.messages,
      )..where((t) => t.id.equals(messageId))).getSingleOrNull();

      if (message != null) {
        final timestampSql = "'${timestamp.replaceAll("'", "''")}'";
        final id = _uuid.v4();
        await db.customInsert(
          '''
          INSERT INTO message_info (id, chat_id, message_id, user_id, delivered_at, read_at)
          VALUES ('$id', '${message.chatId}', '$messageId', '$userId', $timestampSql, $timestampSql)
          ON CONFLICT(message_id, user_id) DO UPDATE SET
            chat_id = excluded.chat_id,
            delivered_at = COALESCE(message_info.delivered_at, excluded.delivered_at),
            read_at = excluded.read_at
          ''',
          updates: {db.messageInfo},
        );
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

  Future<void> markMultipleAsDelivered({
    required List<String> messageIds,
    required String userId,
    String? deliveredAt,
  }) async {
    if (messageIds.isEmpty) return;

    final db = sqliteDatabase.database;
    final timestamp = deliveredAt ?? DateTime.now().toIso8601String();

    await db.transaction(() async {
      for (final messageId in messageIds) {
        try {
          final message = await (db.select(
            db.messages,
          )..where((t) => t.id.equals(messageId))).getSingleOrNull();

          if (message != null) {
            final deliveredAtSql = "'${timestamp.replaceAll("'", "''")}'";
            final id = _uuid.v4();
            await db.customInsert(
              '''
              INSERT INTO message_info (id, chat_id, message_id, user_id, delivered_at)
              VALUES ('$id', '${message.chatId}', '$messageId', '$userId', $deliveredAtSql)
              ON CONFLICT(message_id, user_id) DO UPDATE SET
                chat_id = excluded.chat_id,
                delivered_at = excluded.delivered_at
              ''',
              updates: {db.messageInfo},
            );
          }
        } catch (e) {
          final errorCode = _extractSqliteErrorCode(e);
          debugPrint(
            "Error marking message $messageId as delivered: $e (errorCode: $errorCode)",
          );
        }
      }
    });
  }

  Future<void> markMultipleAsRead({
    required List<String> messageIds,
    required String userId,
    String? readAt,
  }) async {
    if (messageIds.isEmpty) return;

    final db = sqliteDatabase.database;
    final timestamp = readAt ?? DateTime.now().toIso8601String();

    await db.transaction(() async {
      for (final messageId in messageIds) {
        try {
          final message = await (db.select(
            db.messages,
          )..where((t) => t.id.equals(messageId))).getSingleOrNull();

          if (message != null) {
            final timestampSql = "'${timestamp.replaceAll("'", "''")}'";
            final id = _uuid.v4();
            await db.customInsert(
              '''
              INSERT INTO message_info (id, chat_id, message_id, user_id, delivered_at, read_at)
              VALUES ('$id', '${message.chatId}', '$messageId', '$userId', $timestampSql, $timestampSql)
              ON CONFLICT(message_id, user_id) DO UPDATE SET
                chat_id = excluded.chat_id,
                delivered_at = COALESCE(message_info.delivered_at, excluded.delivered_at),
                read_at = excluded.read_at
              ''',
              updates: {db.messageInfo},
            );
          }
        } catch (e) {
          final errorCode = _extractSqliteErrorCode(e);
          debugPrint(
            "Error marking message $messageId as read: $e (errorCode: $errorCode)",
          );
        }
      }
    });
  }

  Future<void> updateDeliveredAt({
    required String messageId,
    String? deliveredAt,
  }) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messageInfo)
          ..where((t) => t.messageId.equals(messageId)))
        .write(MessageInfoCompanion(deliveredAt: Value(deliveredAt)));
  }

  Future<SqliteResult<void>> updateDeliveredAtForUser({
    required String messageId,
    required String userId,
    required String chatId,
    String? deliveredAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final deliveredAtSql = deliveredAt != null
          ? "'${deliveredAt.replaceAll("'", "''")}'"
          : 'NULL';
      final id = _uuid.v4();
      await db.customInsert(
        '''
        INSERT INTO message_info (id, chat_id, message_id, user_id, delivered_at)
        VALUES ('$id', '$chatId', '$messageId', '$userId', $deliveredAtSql)
        ON CONFLICT(message_id, user_id) DO UPDATE SET
          chat_id = excluded.chat_id,
          delivered_at = excluded.delivered_at,
          reaction = COALESCE(message_info.reaction, excluded.reaction)
        ''',
        updates: {db.messageInfo},
      );
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

  Future<SqliteResult<void>> updateReadAtForUser({
    required String messageId,
    required String userId,
    required String chatId,
    String? readAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final readAtSql = readAt != null
          ? "'${readAt.replaceAll("'", "''")}'"
          : 'NULL';
      final id = _uuid.v4();
      await db.customInsert(
        '''
        INSERT INTO message_info (id, chat_id, message_id, user_id, read_at)
        VALUES ('$id', '$chatId', '$messageId', '$userId', $readAtSql)
        ON CONFLICT(message_id, user_id) DO UPDATE SET
          chat_id = excluded.chat_id,
          read_at = excluded.read_at,
          reaction = COALESCE(message_info.reaction, excluded.reaction)
        ''',
        updates: {db.messageInfo},
      );
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

  Future<bool> deleteMessageStatus(String id) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.messageInfo,
    )..where((t) => t.id.equals(id))).go();
    return deleted > 0;
  }

  Future<void> deleteMessageStatusesByMessageId(String messageId) async {
    final db = sqliteDatabase.database;
    await (db.delete(
      db.messageInfo,
    )..where((t) => t.messageId.equals(messageId))).go();
  }

  Future<void> deleteMessageStatusesByConversationId(String chatId) async {
    final db = sqliteDatabase.database;
    await (db.delete(
      db.messageInfo,
    )..where((t) => t.chatId.equals(chatId))).go();
  }

  Future<bool> deleteMessageStatusByMessageAndUser(
    String messageId,
    String userId,
  ) async {
    final db = sqliteDatabase.database;
    final deleted =
        await (db.delete(db.messageInfo)..where(
              (t) => t.messageId.equals(messageId) & t.userId.equals(userId),
            ))
            .go();
    return deleted > 0;
  }

  Future<void> clearAllMessageStatuses() async {
    final db = sqliteDatabase.database;
    await db.delete(db.messageInfo).go();
  }

  Future<int> getReadCountByMessageId(String messageId) async {
    final db = sqliteDatabase.database;
    final count =
        await (db.selectOnly(db.messageInfo)
              ..addColumns([db.messageInfo.id.count()])
              ..where(
                db.messageInfo.messageId.equals(messageId) &
                    db.messageInfo.readAt.isNotNull(),
              ))
            .getSingle();
    return count.read(db.messageInfo.id.count()) ?? 0;
  }

  Future<int> getDeliveredCountByMessageId(String messageId) async {
    final db = sqliteDatabase.database;
    final count =
        await (db.selectOnly(db.messageInfo)
              ..addColumns([db.messageInfo.id.count()])
              ..where(
                db.messageInfo.messageId.equals(messageId) &
                    db.messageInfo.deliveredAt.isNotNull(),
              ))
            .getSingle();
    return count.read(db.messageInfo.id.count()) ?? 0;
  }

  Future<int> getUnreadCountByMessageId(String messageId) async {
    final db = sqliteDatabase.database;
    final total =
        await (db.selectOnly(db.messageInfo)
              ..addColumns([db.messageInfo.id.count()])
              ..where(db.messageInfo.messageId.equals(messageId)))
            .getSingle();
    final readCount = await getReadCountByMessageId(messageId);
    return (total.read(db.messageInfo.id.count()) ?? 0) - readCount;
  }

  Future<int> getUndeliveredCountByMessageId(String messageId) async {
    final db = sqliteDatabase.database;
    final total =
        await (db.selectOnly(db.messageInfo)
              ..addColumns([db.messageInfo.id.count()])
              ..where(db.messageInfo.messageId.equals(messageId)))
            .getSingle();
    final deliveredCount = await getDeliveredCountByMessageId(messageId);
    return (total.read(db.messageInfo.id.count()) ?? 0) - deliveredCount;
  }

  Future<bool> isReadByUser(String messageId, String userId) async {
    final status = await getMessageStatusByMessageAndUser(messageId, userId);
    return status != null && status.readAt != null;
  }

  Future<bool> isDeliveredToUser(String messageId, String userId) async {
    final status = await getMessageStatusByMessageAndUser(messageId, userId);
    return status != null && status.deliveredAt != null;
  }

  /// Mark all messages in a chat as read for a user where readAt is null.
  Future<SqliteResult<void>> markAllAsReadByConversationAndUser({
    required String chatId,
    required String userId,
    String? readAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final timestamp = readAt ?? DateTime.now().toIso8601String();

      await (db.update(db.messageInfo)..where(
            (t) =>
                t.chatId.equals(chatId) &
                t.userId.equals(userId) &
                t.readAt.isNull(),
          ))
          .write(MessageInfoCompanion(readAt: Value(timestamp)));
      return SqliteResult.success(message: 'All messages marked as read');
    } catch (e) {
      final errorCode = _extractSqliteErrorCode(e);
      debugPrint(
        'Error marking all as read for chat $chatId and user $userId: $e',
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
    required String messageId,
    required String userId,
    required String chatId,
    String? emoji,
  }) async {
    debugPrint(
      '[upsertReaction] msgId=$messageId userId=$userId chatId=$chatId emoji=$emoji',
    );
    final db = sqliteDatabase.database;
    final emojiValue = emoji != null
        ? "'${emoji.replaceAll("'", "''")}'"
        : 'NULL';
    final id = _uuid.v4();
    await db.customInsert(
      '''
      INSERT INTO message_info (id, chat_id, message_id, user_id, reaction)
      VALUES ('$id', '$chatId', '$messageId', '$userId', $emojiValue)
      ON CONFLICT(message_id, user_id) DO UPDATE SET
        reaction = $emojiValue,
        delivered_at = COALESCE(message_info.delivered_at, excluded.delivered_at),
        read_at = COALESCE(message_info.read_at, excluded.read_at)
      ''',
      updates: {db.messageInfo},
    );
    debugPrint('[upsertReaction] ✅ write complete for msgId=$messageId');
  }

  /// Watch all emoji reactions for messages in a chat.
  /// Returns a reactive map of messageId -> { emoji: [{user_id, user_name}] }
  Stream<Map<String, Map<String, dynamic>>> watchReactionsByConversation(
    String chatId,
  ) {
    final db = sqliteDatabase.database;
    final query = db.customSelect(
      '''
      SELECT mi.message_id, mi.user_id, mi.reaction, u.name as user_name
      FROM message_info mi
      LEFT JOIN users u ON mi.user_id = u.id
      WHERE mi.chat_id = ? AND mi.reaction IS NOT NULL
      ''',
      variables: [Variable.withString(chatId)],
      readsFrom: {db.messageInfo, db.users},
    );
    return query.watch().map((rows) {
      final Map<String, Map<String, dynamic>> result = {};
      for (final row in rows) {
        final msgId = row.read<String>('message_id');
        final userId = row.read<String>('user_id');
        final emoji = row.read<String?>('reaction');
        final userName = row.read<String?>('user_name') ?? 'You';
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

  /// Reactive stream: msgId → {delivered: bool, read: bool}
  /// Fires whenever message_info changes for the given chat.
  Stream<Map<String, MessageStatusType>> watchDeliveryStatusByConversation(
    String chatId,
  ) {
    final db = sqliteDatabase.database;
    final query = db.customSelect(
      '''
      SELECT mi.message_id,
             MAX(mi.delivered_at) AS delivered_at,
             MAX(mi.read_at) AS read_at
      FROM message_info mi
      WHERE mi.chat_id = ?
      GROUP BY mi.message_id
      ''',
      variables: [Variable.withString(chatId)],
      readsFrom: {db.messageInfo},
    );
    return query.watch().map((rows) {
      final Map<String, MessageStatusType> result = {};
      for (final row in rows) {
        final msgId = row.read<String>('message_id');
        final readAt = row.read<String?>('read_at');
        final deliveredAt = row.read<String?>('delivered_at');
        if (readAt != null) {
          result[msgId] = MessageStatusType.read;
        } else if (deliveredAt != null) {
          result[msgId] = MessageStatusType.delivered;
        } else {
          result[msgId] = MessageStatusType.sent;
        }
      }
      return result;
    });
  }

  Future<SqliteResult<void>> markAllAsDeliveredForUser({
    required String userId,
    String? deliveredAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      final timestamp = deliveredAt ?? DateTime.now().toIso8601String();
      await (db.update(db.messageInfo)
            ..where((t) => t.userId.equals(userId) & t.deliveredAt.isNull()))
          .write(MessageInfoCompanion(deliveredAt: Value(timestamp)));
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
