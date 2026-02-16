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

class MessageRepository {
  final sqliteDatabase = SqliteDatabase.instance;
  Timer? _cleanupTimer;

  /// Helper method to convert Messages row to MessageModel
  MessageModel _messageToModel(Message message) {
    // Parse message type
    final messageType =
        MessageType.fromString(message.type) ?? MessageType.text;

    // Parse status
    final messageStatus =
        MessageStatusType.fromString(message.status) ?? MessageStatusType.sent;

    return MessageModel(
      id: message.id.toInt(),
      conversationId: message.conversationId,
      senderId: message.senderId,
      senderName: null, // Not stored in Messages table
      senderProfilePic: null, // Not stored in Messages table
      type: messageType,
      body: message.body,
      status: messageStatus,
      attachments: message.attachments,
      metadata: message.metadata,
      isStarred: message.isStarred ? true : null,
      isReplied: message.isReplied ? true : null,
      isForwarded: message.isForwarded ? true : null,
      isDeleted: message.isDeleted ? true : null,
      sentAt: message.sentAt,
    );
  }

  /// Helper method to convert MessageModel to MessagesCompanion for insertion
  MessagesCompanion _modelToCompanion(MessageModel message) {
    // Use canonicalId if available, otherwise optimisticId
    final messageId = message.id;

    return MessagesCompanion.insert(
      id: Value(BigInt.from(messageId)),
      conversationId: message.conversationId,
      senderId: message.senderId,
      type: message.type.value,
      body: Value(message.body),
      status: message.status.value,
      attachments: Value(message.attachments),
      metadata: Value(message.metadata),
      isStarred: Value(message.isStarred ?? false),
      isReplied: Value(message.isReplied ?? false),
      isForwarded: Value(message.isForwarded ?? false),
      isDeleted: Value(message.isDeleted ?? false),
      sentAt: message.sentAt,
    );
  }

  /// Insert a single message
  Future<Map<String, dynamic>> insertMessage(MessageModel message) async {
    final db = sqliteDatabase.database;

    // Wrap in transaction to prevent database locks
    final trx_result = await db.transaction<Map<String, dynamic>>(() async {
      // final existingMessage = await (db.select(
      //   db.messages,
      // )..where((t) => t.id.equals(BigInt.from(message.id)))).getSingleOrNull();
      //
      // if (existingMessage != null) {
      //   return;
      // } else {
      try {
        final companion = _modelToCompanion(message);
        final result = await db.into(db.messages).insert(companion);
        // print("------------------message id ${message.id}-----------");
        // print("-----------message insertion result $result---------------");
        return {"success": true, "result": result};
      } catch (e) {
        // debugPrint("-------------------------------");
        final error = e as DriftRemoteException;
        final error2 = error.remoteCause as SqliteException;
        // debugPrint("-------------------------------");
        // debugPrint("-----------${error2.extendedResultCode}-----------");
        // debugPrint("-------------------------------");
        return {
          "success": false,
          "errorCode": error2.extendedResultCode,
          "message": "failed to insert message ",
        };
      }
      // }
      // If we have both canonicalId and optimisticId, we need to replace the optimistic message
      // with the canonical one to prevent duplicates
      // if (message.canonicalId != null && message.optimisticId != null) {
      //   // Check if optimistic message exists
      //   final optimisticMsg =
      //       await (db.select(db.messages)..where(
      //             (t) => t.id.equals(BigInt.from(message.optimisticId!)),
      //           ))
      //           .getSingleOrNull();
      //
      //   if (optimisticMsg != null) {
      //     // Check if canonical message already exists
      //     final canonicalMsg =
      //         await (db.select(db.messages)..where(
      //               (t) => t.id.equals(BigInt.from(message.canonicalId!)),
      //             ))
      //             .getSingleOrNull();
      //
      //     if (canonicalMsg == null) {
      //       // Canonical message doesn't exist, delete optimistic one
      //       await (db.delete(db.messages)..where(
      //             (t) => t.id.equals(BigInt.from(message.optimisticId!)),
      //           ))
      //           .go();
      //     } else {
      //       // Canonical message already exists, just delete optimistic one
      //       await (db.delete(db.messages)..where(
      //             (t) => t.id.equals(BigInt.from(message.optimisticId!)),
      //           ))
      //           .go();
      //       // Use existing canonical message data for merge
      //       final existingMessage = _messageToModel(canonicalMsg);
      //
      //       // Preserve existing body if new body is null/empty and existing has value
      //       final bodyValue = (message.body != null && message.body!.isNotEmpty)
      //           ? message.body
      //           : (existingMessage.body);
      //
      //       // Preserve existing attachments if new attachments are null/empty and existing has value
      //       final attachmentsValue =
      //           (message.attachments != null && message.attachments!.isNotEmpty)
      //           ? message.attachments
      //           : (existingMessage.attachments);
      //
      //       // Preserve existing metadata if new metadata is null/empty and existing has value
      //       final metadataValue =
      //           (message.metadata != null && message.metadata!.isNotEmpty)
      //           ? message.metadata
      //           : (existingMessage.metadata);
      //
      //       // Preserve existing isReplied flag if new one is false/null but existing is true
      //       final isRepliedValue = message.isReplied == true
      //           ? true
      //           : (existingMessage.isReplied ?? false);
      //
      //       // Create updated message with preserved values
      //       final updatedMessage = message.copyWith(
      //         body: bodyValue,
      //         attachments: attachmentsValue,
      //         metadata: metadataValue,
      //         isReplied: isRepliedValue ? true : null,
      //       );
      //
      //       final companion = _modelToCompanion(updatedMessage);
      //       await db.into(db.messages).insertOnConflictUpdate(companion);
      //       return; // Exit early since we've handled the update
      //     }
      //   }
      // }

      // Check if message already exists to preserve body and metadata
      // final messageId = message.canonicalId ?? message.optimisticId;
      // MessageModel? existingMessage;
      // if (messageId != null) {
      //   existingMessage = await getMessageById(messageId);
      // }
      //
      // // Preserve existing body if new body is null/empty and existing has value
      // final bodyValue = (message.body != null && message.body!.isNotEmpty)
      //     ? message.body
      //     : (existingMessage?.body);
      //
      // // Preserve existing attachments if new attachments are null/empty and existing has value
      // final attachmentsValue =
      //     (message.attachments != null && message.attachments!.isNotEmpty)
      //     ? message.attachments
      //     : (existingMessage?.attachments);
      //
      // // Preserve existing metadata if new metadata is null/empty and existing has value
      // final metadataValue =
      //     (message.metadata != null && message.metadata!.isNotEmpty)
      //     ? message.metadata
      //     : (existingMessage?.metadata);
      //
      // // Preserve existing isReplied flag if new one is false/null but existing is true
      // final isRepliedValue = message.isReplied == true
      //     ? true
      //     : (existingMessage?.isReplied ?? false);
      //
      // // Create updated message with preserved values
      // final updatedMessage = message.copyWith(
      //   body: bodyValue,
      //   attachments: attachmentsValue,
      //   metadata: metadataValue,
      //   isReplied: isRepliedValue ? true : null,
      // );
      //
      // final companion = _modelToCompanion(updatedMessage);
      // await db.into(db.messages).insertOnConflictUpdate(companion);
    });
    return trx_result;
  }

  /// Insert multiple messages (bulk insert)
  Future<void> insertMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;

    final db = sqliteDatabase.database;
    await db.transaction(() async {
      for (final message in messages) {
        final existingMessage =
            await (db.select(db.messages)
                  ..where((t) => t.id.equals(BigInt.from(message.id))))
                .getSingleOrNull();

        if (existingMessage != null) {
          return;
        } else {
          final companion = _modelToCompanion(message);
          await db.into(db.messages).insert(companion);
          return; // Exit early since we've handled the update
        }
        // Check if message already exists to preserve body and metadata
        // final messageId = message.canonicalId ?? message.optimisticId;
        // MessageModel? existingMessage;
        // if (messageId != null) {
        //   existingMessage = await getMessageById(messageId);
        // }
        //
        // // Preserve existing body if new body is null/empty and existing has value
        // final bodyValue = (message.body != null && message.body!.isNotEmpty)
        //     ? message.body
        //     : (existingMessage?.body);
        //
        // // Preserve existing attachments if new attachments are null/empty and existing has value
        // final attachmentsValue =
        //     (message.attachments != null && message.attachments!.isNotEmpty)
        //     ? message.attachments
        //     : (existingMessage?.attachments);
        //
        // // Preserve existing metadata if new metadata is null/empty and existing has value
        // final metadataValue =
        //     (message.metadata != null && message.metadata!.isNotEmpty)
        //     ? message.metadata
        //     : (existingMessage?.metadata);
        //
        // // Preserve existing isReplied flag if new one is false/null but existing is true
        // final isRepliedValue = message.isReplied == true
        //     ? true
        //     : (existingMessage?.isReplied ?? false);
        //
        // // Create updated message with preserved values
        // final updatedMessage = message.copyWith(
        //   body: bodyValue,
        //   attachments: attachmentsValue,
        //   metadata: metadataValue,
        //   isReplied: isRepliedValue ? true : null,
        // );
        //
        // final companion = _modelToCompanion(updatedMessage);
        // await db.into(db.messages).insertOnConflictUpdate(companion);
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
    int conversationId, {
    int? limit,
    int? offset,
    bool includeDeleted = false,
  }) async {
    final db = sqliteDatabase.database;

    // Create query with LEFT JOIN to Users table
    final query = db.select(db.messages).join([
      leftOuterJoin(db.users, db.users.id.equalsExp(db.messages.senderId)),
    ])..where(db.messages.conversationId.equals(conversationId));

    if (!includeDeleted) {
      query.where(db.messages.isDeleted.equals(false));
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

  /// Get a single message by ID
  Future<MessageModel?> getMessageById(int messageId) async {
    final db = sqliteDatabase.database;
    final message = await (db.select(
      db.messages,
    )..where((t) => t.id.equals(BigInt.from(messageId)))).getSingleOrNull();

    if (message == null) return null;
    return _messageToModel(message);
  }

  /// Get message count for a conversation
  Future<int> getMessageCount(
    int conversationId, {
    bool includeDeleted = false,
  }) async {
    final db = sqliteDatabase.database;

    final query = db.selectOnly(db.messages)
      ..addColumns([db.messages.id.count()])
      ..where(db.messages.conversationId.equals(conversationId));

    if (!includeDeleted) {
      query.where(db.messages.isDeleted.equals(false));
    }

    final result = await query.getSingle();
    return result.read(db.messages.id.count()) ?? 0;
  }

  /// Get messages by IDs
  Future<List<MessageModel>> getMessagesByIds(List<int> messageIds) async {
    if (messageIds.isEmpty) return [];

    final db = sqliteDatabase.database;
    final messages = await (db.select(
      db.messages,
    )..where((t) => t.id.isIn(messageIds.map((id) => BigInt.from(id))))).get();

    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Get messages by type
  Future<List<MessageModel>> getMessagesByType(
    MessageType type, {
    int? conversationId,
  }) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.messages)
      ..where((t) => t.type.equals(type.value));

    if (conversationId != null) {
      query.where((t) => t.conversationId.equals(conversationId));
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
    ]);

    final messages = await query.get();
    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Get starred messages for a conversation
  Future<Set<int>> getStarredMessages(int conversationId) async {
    final db = sqliteDatabase.database;
    final messages =
        await (db.select(db.messages)..where(
              (t) =>
                  t.conversationId.equals(conversationId) &
                  t.isStarred.equals(true),
            ))
            .get();

    return messages.map((msg) => msg.id.toInt()).toSet();
  }

  /// Get all starred messages across all conversations
  Future<List<MessageModel>> getAllStarredMessages() async {
    final db = sqliteDatabase.database;
    final messages =
        await (db.select(db.messages)
              ..where((t) => t.isStarred.equals(true))
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
              ]))
            .get();

    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Get deleted messages for a conversation
  Future<List<MessageModel>> getDeletedMessages(int conversationId) async {
    final db = sqliteDatabase.database;
    final messages =
        await (db.select(db.messages)
              ..where(
                (t) =>
                    t.conversationId.equals(conversationId) &
                    t.isDeleted.equals(true),
              )
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
              ]))
            .get();

    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Get forwarded messages
  Future<List<MessageModel>> getForwardedMessages({int? conversationId}) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.messages)
      ..where((t) => t.isForwarded.equals(true));

    if (conversationId != null) {
      query.where((t) => t.conversationId.equals(conversationId));
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
    ]);

    final messages = await query.get();
    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Get replied messages
  Future<List<MessageModel>> getRepliedMessages({int? conversationId}) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.messages)
      ..where((t) => t.isReplied.equals(true));

    if (conversationId != null) {
      query.where((t) => t.conversationId.equals(conversationId));
    }

    query.orderBy([
      (t) => OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
    ]);

    final messages = await query.get();
    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Search messages by body text
  Future<List<MessageModel>> searchMessages(
    String searchQuery, {
    int? conversationId,
    int? limit,
  }) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.messages)
      ..where((t) => t.body.like('%$searchQuery%'));

    if (conversationId != null) {
      query.where((t) => t.conversationId.equals(conversationId));
    }

    query
      ..where((t) => t.isDeleted.equals(false))
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
  Future<MessageModel?> getLastMessage(int conversationId) async {
    final db = sqliteDatabase.database;
    final message =
        await (db.select(db.messages)
              ..where(
                (t) =>
                    t.conversationId.equals(conversationId) &
                    t.isDeleted.equals(false),
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

  /// Update message status
  Future<void> updateMessageStatus(
    int messageId,
    MessageStatusType status,
  ) async {
    try {
      final db = sqliteDatabase.database;
      await (db.update(db.messages)
            ..where((t) => t.id.equals(BigInt.from(messageId))))
          .write(MessagesCompanion(status: Value(status.value)));
    } catch (e) {
      debugPrint("Error updating message status: $e");
    }
  }

  /// Partially update a message by ID.
  ///
  /// Only the non-null fields you pass will be updated in the database.
  /// All other columns for that row are left unchanged.
  ///
  /// Example:
  ///   await updateMessageFields(
  ///     messageId,
  ///     status: MessageStatusType.delivered,
  ///     metadata: updatedMetadata,
  ///   );
  Future<void> updateMessageFields(
    int messageId, {
    MessageStatusType? status,
    int? newId,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? attachments,
    String? body,
    bool? isStarred,
    bool? isReplied,
    bool? isForwarded,
    bool? isDeleted,
  }) async {
    // If nothing was provided, there is nothing to do
    if (status == null &&
        metadata == null &&
        attachments == null &&
        body == null &&
        isStarred == null &&
        isReplied == null &&
        isForwarded == null &&
        newId == null &&
        isDeleted == null) {
      return;
    }

    final db = sqliteDatabase.database;

    // Drift only updates the columns where the Value is present.
    final companion = MessagesCompanion(
      status: status != null ? Value(status.value) : const Value.absent(),
      id: newId != null ? Value(BigInt.from(newId)) : const Value.absent(),
      metadata: metadata != null ? Value(metadata) : const Value.absent(),
      attachments: attachments != null
          ? Value(attachments)
          : const Value.absent(),
      body: body != null ? Value(body) : const Value.absent(),
      isStarred: isStarred != null ? Value(isStarred) : const Value.absent(),
      isReplied: isReplied != null ? Value(isReplied) : const Value.absent(),
      isForwarded: isForwarded != null
          ? Value(isForwarded)
          : const Value.absent(),
      isDeleted: isDeleted != null ? Value(isDeleted) : const Value.absent(),
    );

    await (db.update(
      db.messages,
    )..where((t) => t.id.equals(BigInt.from(messageId)))).write(companion);
  }

  /// Update all messages status for a conversation
  Future<void> updateAllMessagesAsReadForDM(int conversationId) async {
    try {
      final db = sqliteDatabase.database;
      await (db.update(db.messages)..where(
            (t) =>
                t.conversationId.equals(conversationId) &
                t.status.equals(MessageStatusType.read.value).not(),
          ))
          .write(
            MessagesCompanion(status: Value(MessageStatusType.read.value)),
          );
    } catch (e) {
      debugPrint("Error updating all messages status for DMs: $e");
    }
  }

  /// update message status for all conversation for user id
  Future<void> updateAllMessagesAsDeliveredForUserId(int userId) async {
    try {
      final db = sqliteDatabase.database;

      // Update messages in those conversations
      await (db.update(db.messages)..where(
            (t) =>
                t.senderId.equals(userId) &
                t.status.equals(MessageStatusType.sent.value),
          ))
          .write(
            MessagesCompanion(status: Value(MessageStatusType.delivered.value)),
          );
    } catch (e) {
      debugPrint("Error updating all messages status for user ID: $e");
    }
  }

  /// Update message ID (for optimistic updates)
  Future<void> updateMessageId(int optimisticId, int canonicalId) async {
    final db = sqliteDatabase.database;

    // Check if optimistic message exists
    final optimisticMsg = await (db.select(
      db.messages,
    )..where((t) => t.id.equals(BigInt.from(optimisticId)))).getSingleOrNull();

    if (optimisticMsg == null) return;

    // Check if canonical message already exists
    final canonicalMsg = await (db.select(
      db.messages,
    )..where((t) => t.id.equals(BigInt.from(canonicalId)))).getSingleOrNull();

    if (canonicalMsg != null) {
      // Canonical message exists, delete optimistic one
      await deleteMessage(optimisticId);
    } else {
      // Update optimistic message ID to canonical
      await (db.update(db.messages)
            ..where((t) => t.id.equals(BigInt.from(optimisticId))))
          .write(MessagesCompanion(id: Value(BigInt.from(canonicalId))));
    }
  }

  /// Update optimistic message with server data
  Future<MessageModel?> updateOptimisticMessage(
    int conversationId,
    int optimisticId,
    int canonicalId,
    Map<String, dynamic> messageData,
  ) async {
    final db = sqliteDatabase.database;

    // Parse the message data
    final updatedMessage = MessageModel.fromJson(messageData);

    // Check if canonical message already exists
    final existingCanonical = await (db.select(
      db.messages,
    )..where((t) => t.id.equals(BigInt.from(canonicalId)))).getSingleOrNull();

    if (existingCanonical != null) {
      // Canonical message exists, delete optimistic one
      await deleteMessage(optimisticId);
      return _messageToModel(existingCanonical);
    }

    // Update optimistic message with canonical data
    final companion = MessagesCompanion(
      id: Value(BigInt.from(canonicalId)),
      conversationId: Value(updatedMessage.conversationId),
      senderId: Value(updatedMessage.senderId),
      type: Value(updatedMessage.type.value),
      body: Value(updatedMessage.body),
      status: Value(updatedMessage.status.value),
      attachments: Value(updatedMessage.attachments),
      metadata: Value(updatedMessage.metadata),
      isStarred: Value(updatedMessage.isStarred ?? false),
      isReplied: Value(updatedMessage.isReplied ?? false),
      isForwarded: Value(updatedMessage.isForwarded ?? false),
      isDeleted: Value(updatedMessage.isDeleted ?? false),
      sentAt: Value(updatedMessage.sentAt),
    );

    await (db.update(
      db.messages,
    )..where((t) => t.id.equals(BigInt.from(optimisticId)))).write(companion);

    // Return updated message
    final updated = await getMessageById(canonicalId);
    return updated;
  }

  /// Star a message
  Future<void> starMessage(int messageId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(BigInt.from(messageId))))
        .write(MessagesCompanion(isStarred: Value(true)));
  }

  /// Unstar a message
  Future<void> unstarMessage(int messageId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(BigInt.from(messageId))))
        .write(MessagesCompanion(isStarred: Value(false)));
  }

  /// Toggle star status of a message
  Future<void> toggleStarMessage(int messageId) async {
    final message = await getMessageById(messageId);
    if (message != null) {
      if (message.isStarred == true) {
        await unstarMessage(messageId);
      } else {
        await starMessage(messageId);
      }
    }
  }

  /// Save starred messages (bulk star)
  Future<void> saveStarredMessages(
    int conversationId,
    Set<int> messageIds,
  ) async {
    final db = sqliteDatabase.database;

    // First, unstar all messages in the conversation
    await (db.update(db.messages)
          ..where((t) => t.conversationId.equals(conversationId)))
        .write(MessagesCompanion(isStarred: Value(false)));

    // Then star the specified messages
    if (messageIds.isNotEmpty) {
      await (db.update(db.messages)
            ..where((t) => t.id.isIn(messageIds.map((id) => BigInt.from(id)))))
          .write(MessagesCompanion(isStarred: Value(true)));
    }
  }

  /// Mark message as replied
  Future<void> markAsReplied(int messageId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(BigInt.from(messageId))))
        .write(MessagesCompanion(isReplied: Value(true)));
  }

  /// Mark message as forwarded
  Future<void> markAsForwarded(int messageId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(BigInt.from(messageId))))
        .write(MessagesCompanion(isForwarded: Value(true)));
  }

  /// Delete a message (soft delete)
  Future<void> deleteMessage(int messageId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(BigInt.from(messageId))))
        .write(MessagesCompanion(isDeleted: Value(true)));
  }

  /// Delete multiple messages (soft delete)
  Future<void> deleteMessages(List<int> messageIds) async {
    if (messageIds.isEmpty) return;

    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.isIn(messageIds.map((id) => BigInt.from(id)))))
        .write(MessagesCompanion(isDeleted: Value(true)));
  }

  /// Permanently delete a message
  Future<bool> permanentlyDeleteMessage(int messageId) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.messages,
    )..where((t) => t.id.equals(BigInt.from(messageId)))).go();
    return deleted > 0;
  }

  /// Permanently delete multiple messages
  Future<int> permanentlyDeleteMessages(List<int> messageIds) async {
    if (messageIds.isEmpty) return 0;

    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.messages,
    )..where((t) => t.id.isIn(messageIds.map((id) => BigInt.from(id))))).go();
    return deleted;
  }

  /// Delete all messages in a conversation
  Future<void> deleteConversationMessages(int conversationId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.conversationId.equals(conversationId)))
        .write(MessagesCompanion(isDeleted: Value(true)));
  }

  /// Restore a deleted message
  Future<void> restoreMessage(int messageId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(BigInt.from(messageId))))
        .write(MessagesCompanion(isDeleted: Value(false)));
  }

  /// Update message body
  Future<void> updateMessageBody(int messageId, String body) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(BigInt.from(messageId))))
        .write(MessagesCompanion(body: Value(body)));
  }

  /// Update message attachments
  Future<void> updateMessageAttachments(
    int messageId,
    Map<String, dynamic>? attachments,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(BigInt.from(messageId))))
        .write(MessagesCompanion(attachments: Value(attachments)));
  }

  /// Update message metadata
  Future<void> updateMessageMetadata(
    int messageId,
    Map<String, dynamic>? metadata,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(db.messages)
          ..where((t) => t.id.equals(BigInt.from(messageId))))
        .write(MessagesCompanion(metadata: Value(metadata)));
  }

  /// Check if message has local media (checks metadata for localMediaPath)
  Future<bool> hasLocalMedia(int messageId) async {
    final message = await getMessageById(messageId);
    if (message == null) return false;

    final metadata = message.metadata;
    if (metadata == null) return false;

    return metadata.containsKey('localMediaPath') &&
        metadata['localMediaPath'] != null;
  }

  /// Update local media path in message metadata
  Future<void> updateLocalMediaPath(int messageId, String? localPath) async {
    final message = await getMessageById(messageId);
    if (message == null) return;

    final metadata = Map<String, dynamic>.from(message.metadata ?? {});
    if (localPath != null) {
      metadata['localMediaPath'] = localPath;
    } else {
      metadata.remove('localMediaPath');
    }

    await updateMessageMetadata(messageId, metadata);
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
  Future<void> removeMessageFromCache(int messageId) async {
    await deleteMessage(messageId);
  }

  /// Validate reply message storage (check if replied-to messages exist)
  Future<void> validateReplyMessageStorage(int conversationId) async {
    final db = sqliteDatabase.database;
    final messages = await getMessagesByConversation(conversationId);

    for (final message in messages) {
      if (message.isReplied == true && message.metadata != null) {
        final replyTo = message.metadata!['reply_to'];
        if (replyTo != null && replyTo['message_id'] != null) {
          final replyToId = replyTo['message_id'] as int;
          final repliedMessage = await getMessageById(replyToId);

          // message.id is a getter that returns canonicalId ?? optimisticId ?? 0, so it's never null
          if (repliedMessage == null && message.id > 0) {
            // Reply target doesn't exist, mark as not replied
            await (db.update(db.messages)
                  ..where((t) => t.id.equals(BigInt.from(message.id))))
                .write(MessagesCompanion(isReplied: Value(false)));
          }
        }
      }
    }
  }

  /// Get messages in date range
  Future<List<MessageModel>> getMessagesInDateRange(
    int conversationId,
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
                    t.conversationId.equals(conversationId) &
                    t.sentAt.isBiggerOrEqualValue(startStr) &
                    t.sentAt.isSmallerOrEqualValue(endStr) &
                    t.isDeleted.equals(false),
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
    int conversationId,
    int lastReadMessageId,
  ) async {
    final db = sqliteDatabase.database;

    final query = db.selectOnly(db.messages)
      ..addColumns([db.messages.id.count()])
      ..where(
        db.messages.conversationId.equals(conversationId) &
            db.messages.id.isBiggerThanValue(BigInt.from(lastReadMessageId)) &
            db.messages.isDeleted.equals(false),
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
  Future<void> clearConversationMessages(int conversationId) async {
    final db = sqliteDatabase.database;
    await (db.delete(
      db.messages,
    )..where((t) => t.conversationId.equals(conversationId))).go();
  }

  /// Get messages with media attachments
  Future<List<MessageModel>> getMediaMessages({
    int? conversationId,
    MessageType? mediaType,
  }) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.messages)
      ..where((t) => t.attachments.isNotNull());

    if (conversationId != null) {
      query.where((t) => t.conversationId.equals(conversationId));
    }

    if (mediaType != null) {
      query.where((t) => t.type.equals(mediaType.value));
    }

    query
      ..where((t) => t.isDeleted.equals(false))
      ..orderBy([
        (t) => OrderingTerm(expression: t.sentAt, mode: OrderingMode.desc),
      ]);

    final messages = await query.get();
    return messages.map((msg) => _messageToModel(msg)).toList();
  }

  /// Check if message exists
  Future<bool> messageExists(int messageId) async {
    final db = sqliteDatabase.database;
    final message = await (db.select(
      db.messages,
    )..where((t) => t.id.equals(BigInt.from(messageId)))).getSingleOrNull();
    return message != null;
  }

  /// Get message statistics for a conversation
  Future<Map<String, dynamic>> getMessageStatistics(int conversationId) async {
    final db = sqliteDatabase.database;

    final totalQuery = db.selectOnly(db.messages)
      ..addColumns([db.messages.id.count()])
      ..where(db.messages.conversationId.equals(conversationId));

    final totalResult = await totalQuery.getSingle();
    final total = totalResult.read(db.messages.id.count()) ?? 0;

    final mediaQuery = db.selectOnly(db.messages)
      ..addColumns([db.messages.id.count()])
      ..where(
        db.messages.conversationId.equals(conversationId) &
            db.messages.attachments.isNotNull(),
      );

    final mediaResult = await mediaQuery.getSingle();
    final mediaCount = mediaResult.read(db.messages.id.count()) ?? 0;

    final starredQuery = db.selectOnly(db.messages)
      ..addColumns([db.messages.id.count()])
      ..where(
        db.messages.conversationId.equals(conversationId) &
            db.messages.isStarred.equals(true),
      );

    final starredResult = await starredQuery.getSingle();
    final starredCount = starredResult.read(db.messages.id.count()) ?? 0;

    return {
      'total': total,
      'media': mediaCount,
      'starred': starredCount,
      'text': total - mediaCount,
    };
  }

  // function to delete all message of id less than or eual to 0
  Future<void> deleteAllMessagesLessThanOrEqualTo0() async {
    final db = sqliteDatabase.database;
    await (db.delete(
      db.messages,
    )..where((t) => t.id.isSmallerOrEqualValue(BigInt.zero))).go();
  }

  // function to delete all message of id less than or equal to 0 and sentAt is more than 10 seconds ago
  Future<void> removeoptimisticmessagesentatmorethan10sec() async {
    final db = sqliteDatabase.database;

    // Calculate timestamp 10 seconds ago
    final tenSecondsAgo = DateTime.now().subtract(const Duration(seconds: 10));
    final tenSecondsAgoStr = tenSecondsAgo.toIso8601String();

    await (db.delete(db.messages)..where(
          (t) =>
              t.id.isSmallerOrEqualValue(BigInt.zero) &
              t.sentAt.isSmallerOrEqualValue(tenSecondsAgoStr),
        ))
        .go();
  }

  /// Start the automatic cleanup timer that runs every 10 seconds
  void startCleanupTimer() {
    _stopCleanupTimer(); // Stop any existing timer first

    _cleanupTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      removeoptimisticmessagesentatmorethan10sec().catchError((error) {
        debugPrint('❌ Error in optimistic message cleanup: $error');
      });
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

  /// Dispose resources and stop the cleanup timer
  void dispose() {
    _stopCleanupTimer();
  }
}
