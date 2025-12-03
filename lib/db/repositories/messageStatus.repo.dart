import 'package:drift/drift.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import '../../models/message_status.model.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class MessageStatusRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  /// Helper method to convert MessageStatusModelData row to MessageStatusType model
  MessageStatusType _statusToModel(MessageStatusModelData status) {
    return MessageStatusType(
      id: status.id,
      conversationId: status.conversationId,
      messageId: status.messageId,
      userId: status.userId,
      deliveredAt: status.deliveredAt,
      readAt: status.readAt,
    );
  }

  /// Insert a single message status
  Future<void> insertMessageStatus({
    required int conversationId,
    required int messageId,
    required int userId,
    String? deliveredAt,
    String? readAt,
  }) async {
    final db = sqliteDatabase.database;

    // Check if status already exists to preserve existing values
    final existingStatus = await getMessageStatusByMessageAndUser(
      messageId,
      userId,
    );

    final companion = MessageStatusModelCompanion.insert(
      conversationId: conversationId,
      messageId: messageId,
      userId: userId,
      deliveredAt: Value(deliveredAt ?? existingStatus?.deliveredAt),
      readAt: Value(readAt ?? existingStatus?.readAt),
    );
    await db.into(db.messageStatusModel).insertOnConflictUpdate(companion);
  }

  /// Insert multiple message statuses (bulk insert)
  Future<void> insertMessageStatuses(
    List<Map<String, dynamic>> statuses,
  ) async {
    if (statuses.isEmpty) return;

    final db = sqliteDatabase.database;
    await db.transaction(() async {
      for (final status in statuses) {
        final messageId = status['messageId'] as int;
        final userId = status['userId'] as int;

        // Check if status already exists to preserve existing values
        final existingStatus = await getMessageStatusByMessageAndUser(
          messageId,
          userId,
        );

        final companion = MessageStatusModelCompanion.insert(
          conversationId: status['conversationId'] as int,
          messageId: messageId,
          userId: userId,
          deliveredAt: Value(
            (status['deliveredAt'] as String?) ?? existingStatus?.deliveredAt,
          ),
          readAt: Value(
            (status['readAt'] as String?) ?? existingStatus?.readAt,
          ),
        );
        await db.into(db.messageStatusModel).insertOnConflictUpdate(companion);
      }
    });
  }

  // Insert messagestatus with multiple userids for a message
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
        await insertMessageStatus(
          conversationId: conversationId,
          messageId: messageId,
          userId: userId,
          deliveredAt: null,
          readAt: null,
        );
      }
    });
  }

  /// Get all message statuses
  Future<List<MessageStatusType>> getAllMessageStatuses() async {
    final db = sqliteDatabase.database;
    final statuses = await db.select(db.messageStatusModel).get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Get message status by ID
  Future<MessageStatusType?> getMessageStatusById(int id) async {
    final db = sqliteDatabase.database;
    final status = await (db.select(
      db.messageStatusModel,
    )..where((t) => t.id.equals(BigInt.from(id)))).getSingleOrNull();

    if (status == null) return null;
    return _statusToModel(status);
  }

  /// Get message statuses by messageId
  Future<List<MessageStatusType>> getMessageStatusesByMessageId(
    int messageId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses = await (db.select(
      db.messageStatusModel,
    )..where((t) => t.messageId.equals(messageId))).get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Get message statuses by conversationId
  Future<List<MessageStatusType>> getMessageStatusesByConversationId(
    int conversationId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses = await (db.select(
      db.messageStatusModel,
    )..where((t) => t.conversationId.equals(conversationId))).get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Get message statuses by userId
  Future<List<MessageStatusType>> getMessageStatusesByUserId(int userId) async {
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
              (t) => t.messageId.equals(messageId) & t.readAt.isNotNull(),
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
              (t) => t.messageId.equals(messageId) & t.deliveredAt.isNotNull(),
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
  Future<MessageStatusType?> getMessageStatusByMessageAndUser(
    int messageId,
    int userId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses =
        await (db.select(db.messageStatusModel)..where(
              (t) => t.messageId.equals(messageId) & t.userId.equals(userId),
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
  Future<List<MessageStatusType>> getReadStatusesByMessageId(
    int messageId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses =
        await (db.select(db.messageStatusModel)..where(
              (t) => t.messageId.equals(messageId) & t.readAt.isNotNull(),
            ))
            .get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Get all delivered statuses for a message
  Future<List<MessageStatusType>> getDeliveredStatusesByMessageId(
    int messageId,
  ) async {
    final db = sqliteDatabase.database;
    final statuses =
        await (db.select(db.messageStatusModel)..where(
              (t) => t.messageId.equals(messageId) & t.deliveredAt.isNotNull(),
            ))
            .get();
    return statuses.map((status) => _statusToModel(status)).toList();
  }

  /// Mark message as delivered for a user
  Future<void> markAsDelivered({
    required int messageId,
    required int userId,
    String? deliveredAt,
  }) async {
    final db = sqliteDatabase.database;
    final timestamp = deliveredAt ?? DateTime.now().toIso8601String();

    // Check if status already exists
    final existing = await getMessageStatusByMessageAndUser(messageId, userId);

    if (existing != null) {
      // Update existing status
      await (db.update(db.messageStatusModel)..where(
            (t) => t.messageId.equals(messageId) & t.userId.equals(userId),
          ))
          .write(MessageStatusModelCompanion(deliveredAt: Value(timestamp)));
    } else {
      // Get conversationId from message
      final message = await (db.select(
        db.messages,
      )..where((t) => t.id.equals(BigInt.from(messageId)))).getSingleOrNull();

      if (message != null) {
        // Insert new status
        await insertMessageStatus(
          conversationId: message.conversationId,
          messageId: messageId,
          userId: userId,
          deliveredAt: timestamp,
        );
      }
    }
  }

  /// Mark message as read for a user
  Future<void> markAsRead({
    required int messageId,
    required int userId,
    String? readAt,
  }) async {
    final db = sqliteDatabase.database;
    final timestamp = readAt ?? DateTime.now().toIso8601String();

    // Check if status already exists
    final existing = await getMessageStatusByMessageAndUser(messageId, userId);

    if (existing != null) {
      // Update existing status
      await (db.update(db.messageStatusModel)..where(
            (t) => t.messageId.equals(messageId) & t.userId.equals(userId),
          ))
          .write(
            MessageStatusModelCompanion(
              readAt: Value(timestamp),
              // Also ensure deliveredAt is set if not already set
              deliveredAt: existing.deliveredAt == null
                  ? Value(timestamp)
                  : const Value.absent(),
            ),
          );
    } else {
      // Get conversationId from message
      final message = await (db.select(
        db.messages,
      )..where((t) => t.id.equals(BigInt.from(messageId)))).getSingleOrNull();

      if (message != null) {
        // Insert new status with both delivered and read timestamps
        await insertMessageStatus(
          conversationId: message.conversationId,
          messageId: messageId,
          userId: userId,
          deliveredAt: timestamp,
          readAt: timestamp,
        );
      }
    }
  }

  /// Mark multiple messages as delivered for a user
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
        final existing = await getMessageStatusByMessageAndUser(
          messageId,
          userId,
        );

        if (existing != null) {
          await (db.update(db.messageStatusModel)..where(
                (t) => t.messageId.equals(messageId) & t.userId.equals(userId),
              ))
              .write(
                MessageStatusModelCompanion(deliveredAt: Value(timestamp)),
              );
        } else {
          final message =
              await (db.select(db.messages)
                    ..where((t) => t.id.equals(BigInt.from(messageId))))
                  .getSingleOrNull();

          if (message != null) {
            await insertMessageStatus(
              conversationId: message.conversationId,
              messageId: messageId,
              userId: userId,
              deliveredAt: timestamp,
            );
          }
        }
      }
    });
  }

  /// Mark multiple messages as read for a user
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
        final existing = await getMessageStatusByMessageAndUser(
          messageId,
          userId,
        );

        if (existing != null) {
          await (db.update(db.messageStatusModel)..where(
                (t) => t.messageId.equals(messageId) & t.userId.equals(userId),
              ))
              .write(
                MessageStatusModelCompanion(
                  readAt: Value(timestamp),
                  deliveredAt: existing.deliveredAt == null
                      ? Value(timestamp)
                      : const Value.absent(),
                ),
              );
        } else {
          final message =
              await (db.select(db.messages)
                    ..where((t) => t.id.equals(BigInt.from(messageId))))
                  .getSingleOrNull();

          if (message != null) {
            await insertMessageStatus(
              conversationId: message.conversationId,
              messageId: messageId,
              userId: userId,
              deliveredAt: timestamp,
              readAt: timestamp,
            );
          }
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
          ..where((t) => t.messageId.equals(messageId)))
        .write(MessageStatusModelCompanion(deliveredAt: Value(deliveredAt)));
  }

  // update deliveredAt timestamp for a specific user with message id
  Future<void> updateDeliveredAtForUser({
    required int messageId,
    required int userId,
    required int conversationId,
    String? deliveredAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      // Check if status already exists
      final existing = await getMessageStatusByMessageAndUser(
        messageId,
        userId,
      );

      if (existing != null) {
        // Update existing status
        await (db.update(db.messageStatusModel)..where(
              (t) => t.messageId.equals(messageId) & t.userId.equals(userId),
            ))
            .write(
              MessageStatusModelCompanion(deliveredAt: Value(deliveredAt)),
            );
      } else {
        // Insert new status if it doesn't exist
        await insertMessageStatus(
          conversationId: conversationId,
          messageId: messageId,
          userId: userId,
          deliveredAt: deliveredAt,
        );
      }
    } catch (e) {
      debugPrint(
        'Error updating deliveredAt for messageId $messageId and userId $userId: $e',
      );
    }
  }

  // update readAt timestamp for a specific user with message id
  Future<void> updateReadAtForUser({
    required int messageId,
    required int userId,
    required int conversationId,
    String? readAt,
  }) async {
    try {
      final db = sqliteDatabase.database;
      // Check if status already exists
      final existing = await getMessageStatusByMessageAndUser(
        messageId,
        userId,
      );

      if (existing != null) {
        // Update existing status
        await (db.update(db.messageStatusModel)..where(
              (t) => t.messageId.equals(messageId) & t.userId.equals(userId),
            ))
            .write(MessageStatusModelCompanion(readAt: Value(readAt)));
      } else {
        // Insert new status if it doesn't exist
        await insertMessageStatus(
          conversationId: conversationId,
          messageId: messageId,
          userId: userId,
          readAt: readAt,
        );
      }
    } catch (e) {
      debugPrint(
        'Error updating readAt for messageId $messageId and userId $userId: $e',
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
    )..where((t) => t.messageId.equals(messageId))).go();
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
              (t) => t.messageId.equals(messageId) & t.userId.equals(userId),
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
                db.messageStatusModel.messageId.equals(messageId) &
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
                db.messageStatusModel.messageId.equals(messageId) &
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
              ..where(db.messageStatusModel.messageId.equals(messageId)))
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
              ..where(db.messageStatusModel.messageId.equals(messageId)))
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
  Future<void> updateMessageId(int optimisticId, int canonicalId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messageStatusModel)
          ..where((t) => t.messageId.equals(optimisticId)))
        .write(MessageStatusModelCompanion(messageId: Value(canonicalId)));
  }

  /// Mark all messages in a conversation as read for a user where readAt is null
  Future<void> markAllAsReadByConversationAndUser({
    required int conversationId,
    required int userId,
    String? readAt,
  }) async {
    final db = sqliteDatabase.database;
    final timestamp = readAt ?? DateTime.now().toIso8601String();

    try {
      // Bulk update all undelivered statuses in a single query
      await (db.update(db.messageStatusModel)
            ..where((t) => t.userId.equals(userId) & t.readAt.isNull()))
          .write(MessageStatusModelCompanion(readAt: Value(timestamp)));
    } catch (e) {
      debugPrint(
        'Error marking all as read for conversation $conversationId and user $userId: $e',
      );
    }
  }

  /// mark all undelivered message_status as delivered for a user
  Future<void> markAllAsDeliveredForUser({
    required int userId,
    String? deliveredAt,
  }) async {
    final db = sqliteDatabase.database;
    final timestamp = deliveredAt ?? DateTime.now().toIso8601String();
    try {
      // Bulk update all undelivered statuses in a single query
      await (db.update(db.messageStatusModel)
            ..where((t) => t.userId.equals(userId) & t.deliveredAt.isNull()))
          .write(MessageStatusModelCompanion(deliveredAt: Value(timestamp)));
      // final undeliveredStatuses = await (db.select(
      //   db.messageStatusModel,
      // )..where((t) => t.userId.equals(userId) & t.deliveredAt.isNull())).get();
      // if (undeliveredStatuses.isEmpty) return;
      // await db.transaction(() async {
      //   for (final status in undeliveredStatuses) {
      //     await (db.update(db.messageStatusModel)
      //           ..where((t) => t.id.equals(status.id)))
      //         .write(MessageStatusModelCompanion(deliveredAt: Value(timestamp)));
      //   }
      // });
    } catch (e) {
      debugPrint('Error marking all as delivered for user $userId: $e');
    }
  }
}
