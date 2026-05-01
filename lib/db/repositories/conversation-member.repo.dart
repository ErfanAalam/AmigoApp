import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../models/group.model.dart';
import '../../models/user.model.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class ConversationMemberRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  /// Helper method to convert ChatMember row to ChatMemberModel
  ChatMemberModel _chatMemberToModel(ChatMember member) {
    return ChatMemberModel(
      id: member.id,
      chatId: member.chatId,
      userId: member.userId,
      role: member.role,
      joinedAt: member.joinedAt,
      removedAt: member.removedAt,
      lastReadMsgId: member.lastReadMsgId,
      lastDeliveredMsgId: member.lastDeliveredMsgId,
    );
  }

  /// Insert multiple chat members (bulk insert)
  Future<void> insertConversationMembers(
    List<ChatMemberModel> members,
  ) async {
    final db = sqliteDatabase.database;

    for (final member in members) {
      final existingMember = await getMemberByConversationAndUser(
        member.chatId,
        member.userId,
      );

      final memberCompanion = ChatMembersCompanion.insert(
        id: member.id ?? existingMember?.id ?? '',
        chatId: member.chatId,
        userId: member.userId,
        role: member.role,
        joinedAt: Value(member.joinedAt ?? existingMember?.joinedAt),
        removedAt: Value(member.removedAt ?? existingMember?.removedAt),
        lastReadMsgId: Value(
          member.lastReadMsgId ?? existingMember?.lastReadMsgId,
        ),
        lastDeliveredMsgId: Value(
          member.lastDeliveredMsgId ?? existingMember?.lastDeliveredMsgId,
        ),
      );
      await db.into(db.chatMembers).insertOnConflictUpdate(memberCompanion);
    }
  }

  /// Insert or update chat members efficiently - only inserts new members and updates existing ones if data changed
  Future<void> insertOrUpdateConversationMembers(
    List<ChatMemberModel> members,
  ) async {
    if (members.isEmpty) return;

    final db = sqliteDatabase.database;

    final chatId = members.first.chatId;
    final existingMembers = await getMembersByConversationId(chatId);
    final existingMembersMap = {
      for (var member in existingMembers)
        '${member.chatId}_${member.userId}': member,
    };

    final List<ChatMemberModel> membersToInsert = [];
    final List<ChatMemberModel> membersToUpdate = [];

    for (final member in members) {
      final key = '${member.chatId}_${member.userId}';
      final existingMember = existingMembersMap[key];

      if (existingMember == null) {
        membersToInsert.add(member);
      } else {
        bool hasChanged = member.role != existingMember.role ||
            member.joinedAt != existingMember.joinedAt ||
            member.removedAt != existingMember.removedAt;

        if (hasChanged) {
          membersToUpdate.add(member);
        }
      }
    }

    if (membersToInsert.isNotEmpty) {
      for (final member in membersToInsert) {
        final memberCompanion = ChatMembersCompanion.insert(
          id: member.id ?? '${member.chatId}_${member.userId}',
          chatId: member.chatId,
          userId: member.userId,
          role: member.role,
          joinedAt: Value(member.joinedAt),
          removedAt: Value(member.removedAt),
          lastReadMsgId: Value(member.lastReadMsgId),
          lastDeliveredMsgId: Value(member.lastDeliveredMsgId),
        );
        await db.into(db.chatMembers).insert(memberCompanion);
      }
    }

    if (membersToUpdate.isNotEmpty) {
      for (final member in membersToUpdate) {
        final companion = ChatMembersCompanion(
          chatId: Value(member.chatId),
          userId: Value(member.userId),
          role: Value(member.role),
          joinedAt: member.joinedAt != null
              ? Value(member.joinedAt!)
              : const Value.absent(),
          removedAt: member.removedAt != null
              ? Value(member.removedAt!)
              : const Value.absent(),
        );
        await (db.update(db.chatMembers)
              ..where(
                (t) =>
                    t.chatId.equals(member.chatId) &
                    t.userId.equals(member.userId),
              ))
            .write(companion);
      }
    }
  }

  /// Bulk-upsert chat members atomically — single Drift batch wraps everything
  /// in one transaction so a partial-failure can't leak rows.
  Future<void> insertConversationMembersOnly(
    List<ChatMemberModel> members,
  ) async {
    if (members.isEmpty) return;
    final db = sqliteDatabase.database;

    await db.batch((b) {
      for (final member in members) {
        final memberCompanion = ChatMembersCompanion.insert(
          id: member.id ?? '${member.chatId}_${member.userId}',
          chatId: member.chatId,
          userId: member.userId,
          role: member.role,
          joinedAt: Value(member.joinedAt),
          removedAt: Value(member.removedAt),
          lastReadMsgId: Value(member.lastReadMsgId),
          lastDeliveredMsgId: Value(member.lastDeliveredMsgId),
        );
        b.insert(
          db.chatMembers,
          memberCompanion,
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Get all chat members
  Future<List<ChatMemberModel>> getAllConversationMembers() async {
    final db = sqliteDatabase.database;

    final query = db.select(db.chatMembers)
      ..orderBy([
        (t) => OrderingTerm(expression: t.joinedAt, mode: OrderingMode.desc),
      ]);

    final members = await query.get();

    return members.map(_chatMemberToModel).toList();
  }

  /// Clear all chat members from the database
  Future<void> clearAllConversationMembers() async {
    final db = sqliteDatabase.database;
    await db.delete(db.chatMembers).go();
  }

  /// Update a chat member
  Future<void> updateConversationMember(ChatMemberModel member) async {
    final db = sqliteDatabase.database;

    final companion = ChatMembersCompanion(
      chatId: Value(member.chatId),
      userId: Value(member.userId),
      role: Value(member.role),
      joinedAt: member.joinedAt != null
          ? Value(member.joinedAt!)
          : const Value.absent(),
      removedAt: member.removedAt != null
          ? Value(member.removedAt!)
          : const Value.absent(),
      lastReadMsgId: member.lastReadMsgId != null
          ? Value(member.lastReadMsgId!)
          : const Value.absent(),
      lastDeliveredMsgId: member.lastDeliveredMsgId != null
          ? Value(member.lastDeliveredMsgId!)
          : const Value.absent(),
    );

    await (db.update(db.chatMembers)
          ..where(
            (t) =>
                t.chatId.equals(member.chatId) &
                t.userId.equals(member.userId),
          ))
        .write(companion);
  }

  /// Get a chat member by ID
  Future<ChatMemberModel?> getConversationMemberById(String memberId) async {
    final db = sqliteDatabase.database;

    final member = await (db.select(db.chatMembers)
          ..where((t) => t.id.equals(memberId)))
        .getSingleOrNull();

    if (member == null) return null;

    return _chatMemberToModel(member);
  }

  /// Delete a chat member by ID
  Future<bool> deleteConversationMember(String memberId) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(db.chatMembers)
          ..where((t) => t.id.equals(memberId)))
        .go();
    return deleted > 0;
  }

  /// Get all members of a chat
  Future<List<ChatMemberModel>> getMembersByConversationId(
    String chatId,
  ) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.chatMembers)
      ..where((t) => t.chatId.equals(chatId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.joinedAt, mode: OrderingMode.desc),
      ]);

    final members = await query.get();

    return members.map(_chatMemberToModel).toList();
  }

  /// get all members of a chat with user details
  Future<List<UserModel>> getMembersWithUserDetailsByConversationId(
    String chatId,
  ) async {
    final members = await getMembersByConversationId(chatId);
    final userIds = members.map((member) => member.userId).toList();
    final users = await UserRepository()
        .getUsersByIds(userIds)
        .then(
          (users) =>
              users.map((user) => UserModel.fromJson(user.toJson())).toList(),
        );
    return users;
  }

  /// update member role
  Future<void> updateMemberRole(
    String chatId,
    String userId,
    String role,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(db.chatMembers)
          ..where(
            (t) => t.userId.equals(userId) & t.chatId.equals(chatId),
          ))
        .write(ChatMembersCompanion(role: Value(role)));
  }

  /// Get group members with their details and role using SQL JOIN
  Future<List<GroupMember>> getGroupMembersWithDetails(
    String chatId,
  ) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.chatMembers).join([
          leftOuterJoin(
            db.users,
            db.users.id.equalsExp(db.chatMembers.userId),
          ),
        ])
      ..where(db.chatMembers.chatId.equals(chatId))
      ..where(db.chatMembers.removedAt.isNull())
      ..orderBy([
        OrderingTerm(
          expression: db.chatMembers.joinedAt,
          mode: OrderingMode.asc,
        ),
      ]);

    final results = await query.get();

    return results.map((row) {
      final member = row.readTable(db.chatMembers);
      final user = row.readTableOrNull(db.users);

      return GroupMember(
        userId: member.userId,
        name: user?.name ?? '',
        profilePic: user?.profilePic,
        role: member.role,
        joinedAt: member.joinedAt ?? '',
      );
    }).toList();
  }

  /// Get all chats a user is a member of
  Future<List<ChatMemberModel>> getMembersByUserId(String userId) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.chatMembers)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.joinedAt, mode: OrderingMode.desc),
      ]);

    final members = await query.get();

    return members.map(_chatMemberToModel).toList();
  }

  /// Get active members of a chat (not removed)
  Future<List<ChatMemberModel>> getActiveMembersByConversationId(
    String chatId,
  ) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.chatMembers)
      ..where((t) => t.chatId.equals(chatId) & t.removedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.joinedAt, mode: OrderingMode.desc),
      ]);

    final members = await query.get();

    return members.map(_chatMemberToModel).toList();
  }

  /// Mark chat member as read (update lastReadMsgId)
  Future<void> markAsRead(String memberId, String lastReadMsgId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.chatMembers)
          ..where((t) => t.id.equals(memberId)))
        .write(
      ChatMembersCompanion(lastReadMsgId: Value(lastReadMsgId)),
    );
  }

  /// Update last delivered message ID for a chat member
  Future<void> updateLastDeliveredMessageId(
    String memberId,
    String lastDeliveredMsgId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(db.chatMembers)
          ..where((t) => t.id.equals(memberId)))
        .write(
      ChatMembersCompanion(lastDeliveredMsgId: Value(lastDeliveredMsgId)),
    );
  }

  /// Update role of a chat member
  Future<void> updateRole(String memberId, String role) async {
    final db = sqliteDatabase.database;
    await (db.update(db.chatMembers)
          ..where((t) => t.id.equals(memberId)))
        .write(ChatMembersCompanion(role: Value(role)));
  }

  /// Mark chat member as removed (soft delete)
  Future<void> markAsRemoved(String memberId) async {
    final db = sqliteDatabase.database;
    await (db.update(db.chatMembers)
          ..where((t) => t.id.equals(memberId)))
        .write(
      ChatMembersCompanion(
        removedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Get a chat member by chat ID and user ID
  Future<ChatMemberModel?> getMemberByConversationAndUser(
    String chatId,
    String userId,
  ) async {
    final db = sqliteDatabase.database;

    final members = await (db.select(db.chatMembers)
          ..where(
            (t) =>
                t.chatId.equals(chatId) &
                t.userId.equals(userId) &
                t.removedAt.isNull(),
          )
          ..orderBy([
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .get();

    if (members.isEmpty) return null;

    return _chatMemberToModel(members.first);
  }

  /// Delete all members of a chat
  Future<void> deleteMembersByConversationId(String chatId) async {
    final db = sqliteDatabase.database;
    await (db.delete(db.chatMembers)
          ..where((t) => t.chatId.equals(chatId)))
        .go();
  }

  /// Delete a member by chat ID and user ID
  Future<void> deleteMemberByConversationAndUserId(
    String chatId,
    String userId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.delete(db.chatMembers)
          ..where(
            (t) => t.userId.equals(userId) & t.chatId.equals(chatId),
          ))
        .go();
  }
}
