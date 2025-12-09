import 'package:amigo/db/repositories/user.repo.dart';
import 'package:amigo/models/conversations.model.dart';
import 'package:drift/drift.dart';
import '../../models/group.model.dart';
import '../../models/user.model.dart';
import '../sqlite.db.dart';
import '../sqlite.schema.dart';

class ConversationMemberRepository {
  final sqliteDatabase = SqliteDatabase.instance;

  /// Helper method to convert ConversationMember row to ConversationMemberModel
  ConversationMemberModel _conversationMemberToModel(
    ConversationMember member,
  ) {
    return ConversationMemberModel(
      id: member.id,
      conversationId: member.conversationId,
      userId: member.userId,
      role: member.role,
      unreadCount: member.unreadCount,
      joinedAt: member.joinedAt,
      removedAt: member.removedAt,
      lastReadMessageId: member.lastReadMessageId,
      lastDeliveredMessageId: member.lastDeliveredMessageId,
    );
  }

  /// Insert multiple conversation members (bulk insert)
  Future<void> insertConversationMembers(
    List<ConversationMemberModel> members,
  ) async {
    final db = sqliteDatabase.database;

    for (final member in members) {
      // Check if member already exists to preserve existing values
      final existingMember = await getMemberByConversationAndUser(
        member.conversationId,
        member.userId,
      );

      final memberCompanion = ConversationMembersCompanion.insert(
        conversationId: member.conversationId,
        userId: member.userId,
        role: member.role, // role is required (non-nullable)
        unreadCount: Value(
          member.unreadCount ?? existingMember?.unreadCount ?? 0,
        ),
        joinedAt: Value(member.joinedAt ?? existingMember?.joinedAt),
        removedAt: Value(member.removedAt ?? existingMember?.removedAt),
        lastReadMessageId: Value(
          member.lastReadMessageId ?? existingMember?.lastReadMessageId,
        ),
        lastDeliveredMessageId: Value(
          member.lastDeliveredMessageId ??
              existingMember?.lastDeliveredMessageId,
        ),
      );
      await db
          .into(db.conversationMembers)
          .insertOnConflictUpdate(memberCompanion);
    }
  }

  /// Insert multiple conversation members (insert only, no update on conflict)
  /// Use this when you've already checked that members don't exist
  Future<void> insertConversationMembersOnly(
    List<ConversationMemberModel> members,
  ) async {
    final db = sqliteDatabase.database;

    for (final member in members) {
      final memberCompanion = ConversationMembersCompanion.insert(
        conversationId: member.conversationId,
        userId: member.userId,
        role: member.role, // role is required (non-nullable)
        unreadCount: Value(member.unreadCount ?? 0),
        joinedAt: Value(member.joinedAt),
        removedAt: Value(member.removedAt),
        lastReadMessageId: Value(member.lastReadMessageId),
        lastDeliveredMessageId: Value(member.lastDeliveredMessageId),
      );
      await db.into(db.conversationMembers).insert(memberCompanion);
    }
  }

  /// Get all conversation members
  Future<List<ConversationMemberModel>> getAllConversationMembers() async {
    final db = sqliteDatabase.database;

    final query = db.select(db.conversationMembers)
      ..orderBy([
        (t) => OrderingTerm(expression: t.joinedAt, mode: OrderingMode.desc),
      ]);

    final members = await query.get();

    return members.map((member) => _conversationMemberToModel(member)).toList();
  }

  /// Clear all conversation members from the database
  Future<void> clearAllConversationMembers() async {
    final db = sqliteDatabase.database;
    await db.delete(db.conversationMembers).go();
  }

  /// Update a conversation member
  Future<void> updateConversationMember(ConversationMemberModel member) async {
    final db = sqliteDatabase.database;

    // role is required (non-nullable), so always update it
    // For nullable fields, only update if provided, otherwise preserve existing using Value.absent()
    final companion = ConversationMembersCompanion(
      conversationId: Value(member.conversationId),
      userId: Value(member.userId),
      role: Value(member.role),
      unreadCount: member.unreadCount != null
          ? Value(member.unreadCount!)
          : const Value.absent(),
      joinedAt: member.joinedAt != null
          ? Value(member.joinedAt!)
          : const Value.absent(),
      removedAt: member.removedAt != null
          ? Value(member.removedAt!)
          : const Value.absent(),
      lastReadMessageId: member.lastReadMessageId != null
          ? Value(member.lastReadMessageId!)
          : const Value.absent(),
      lastDeliveredMessageId: member.lastDeliveredMessageId != null
          ? Value(member.lastDeliveredMessageId!)
          : const Value.absent(),
    );

    // Use update instead of replace to preserve existing values
    await (db.update(db.conversationMembers)..where(
          (t) =>
              t.conversationId.equals(member.conversationId) &
              t.userId.equals(member.userId),
        ))
        .write(companion);
  }

  /// Get a conversation member by ID
  Future<ConversationMemberModel?> getConversationMemberById(
    int memberId,
  ) async {
    final db = sqliteDatabase.database;

    final member = await (db.select(
      db.conversationMembers,
    )..where((t) => t.id.equals(memberId))).getSingleOrNull();

    if (member == null) return null;

    return _conversationMemberToModel(member);
  }

  /// Delete a conversation member by ID
  Future<bool> deleteConversationMember(int memberId) async {
    final db = sqliteDatabase.database;
    final deleted = await (db.delete(
      db.conversationMembers,
    )..where((t) => t.id.equals(memberId))).go();
    return deleted > 0;
  }

  /// Get all members of a conversation
  Future<List<ConversationMemberModel>> getMembersByConversationId(
    int conversationId,
  ) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.conversationMembers)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.joinedAt, mode: OrderingMode.desc),
      ]);

    final members = await query.get();

    return members.map((member) => _conversationMemberToModel(member)).toList();
  }

  // get all members of conversations with user details
  Future<List<UserModel>> getMembersWithUserDetailsByConversationId(
    int conversationId,
  ) async {
    final members = await getMembersByConversationId(conversationId);
    final userIds = members.map((member) => member.userId).toList();
    final users = await UserRepository()
        .getUsersByIds(userIds)
        .then(
          (users) =>
              users.map((user) => UserModel.fromJson(user.toJson())).toList(),
        );
    return users;
  }

  // update member role
  Future<void> updateMemberRole(
    int conversationId,
    int userId,
    String role,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(db.conversationMembers)..where(
          (t) =>
              t.userId.equals(userId) & t.conversationId.equals(conversationId),
        ))
        .write(ConversationMembersCompanion(role: Value(role)));
  }

  /// Get group members with their details and role using SQL JOIN
  /// Joins ConversationMembers with Users table to get complete member information
  Future<List<GroupMember>> getGroupMembersWithDetails(
    int conversationId,
  ) async {
    final db = sqliteDatabase.database;

    // Create query with LEFT JOIN to Users table
    final query =
        db.select(db.conversationMembers).join([
            leftOuterJoin(
              db.users,
              db.users.id.equalsExp(db.conversationMembers.userId),
            ),
          ])
          ..where(db.conversationMembers.conversationId.equals(conversationId))
          ..where(
            db.conversationMembers.removedAt.isNull(),
          ) // Only active members
          ..orderBy([
            OrderingTerm(
              expression: db.conversationMembers.joinedAt,
              mode: OrderingMode.asc,
            ),
          ]);

    // Execute query and map results
    final results = await query.get();

    return results.map((row) {
      final member = row.readTable(db.conversationMembers);
      final user = row.readTableOrNull(db.users);

      return GroupMember(
        userId: member.userId,
        name: user?.name ?? '',
        profilePic: user?.profilePic,
        role: member.role,
        joinedAt: member.joinedAt,
      );
    }).toList();
  }

  /// Get all conversations a user is a member of
  Future<List<ConversationMemberModel>> getMembersByUserId(int userId) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.conversationMembers)
      ..where((t) => t.userId.equals(userId))
      ..orderBy([
        (t) => OrderingTerm(expression: t.joinedAt, mode: OrderingMode.desc),
      ]);

    final members = await query.get();

    return members.map((member) => _conversationMemberToModel(member)).toList();
  }

  /// Get active members of a conversation (not removed)
  Future<List<ConversationMemberModel>> getActiveMembersByConversationId(
    int conversationId,
  ) async {
    final db = sqliteDatabase.database;

    final query = db.select(db.conversationMembers)
      ..where(
        (t) => t.conversationId.equals(conversationId) & t.removedAt.isNull(),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.joinedAt, mode: OrderingMode.desc),
      ]);

    final members = await query.get();

    return members.map((member) => _conversationMemberToModel(member)).toList();
  }

  /// Update unread count for a conversation member
  Future<void> updateUnreadCount(int memberId, int unreadCount) async {
    final db = sqliteDatabase.database;
    await (db.update(db.conversationMembers)
          ..where((t) => t.id.equals(memberId)))
        .write(ConversationMembersCompanion(unreadCount: Value(unreadCount)));
  }

  /// Mark conversation member as read (update lastReadMessageId)
  Future<void> markAsRead(int memberId, int lastReadMessageId) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversationMembers,
    )..where((t) => t.id.equals(memberId))).write(
      ConversationMembersCompanion(
        lastReadMessageId: Value(lastReadMessageId),
        unreadCount: const Value(0),
      ),
    );
  }

  /// Update last delivered message ID for a conversation member
  Future<void> updateLastDeliveredMessageId(
    int memberId,
    int lastDeliveredMessageId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversationMembers,
    )..where((t) => t.id.equals(memberId))).write(
      ConversationMembersCompanion(
        lastDeliveredMessageId: Value(lastDeliveredMessageId),
      ),
    );
  }

  /// Update role of a conversation member
  Future<void> updateRole(int memberId, String role) async {
    final db = sqliteDatabase.database;
    await (db.update(db.conversationMembers)
          ..where((t) => t.id.equals(memberId)))
        .write(ConversationMembersCompanion(role: Value(role)));
  }

  /// Mark conversation member as removed (soft delete)
  Future<void> markAsRemoved(int memberId) async {
    final db = sqliteDatabase.database;
    await (db.update(
      db.conversationMembers,
    )..where((t) => t.id.equals(memberId))).write(
      ConversationMembersCompanion(
        removedAt: Value(DateTime.now().toIso8601String()),
      ),
    );
  }

  /// Get a conversation member by conversation ID and user ID
  Future<ConversationMemberModel?> getMemberByConversationAndUser(
    int conversationId,
    int userId,
  ) async {
    final db = sqliteDatabase.database;

    final members =
        await (db.select(db.conversationMembers)
              ..where(
                (t) =>
                    t.conversationId.equals(conversationId) &
                    t.userId.equals(userId) &
                    t.removedAt.isNull(), // Only get active members
              )
              ..orderBy([
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .get();

    if (members.isEmpty) return null;

    return _conversationMemberToModel(members.first);
  }

  /// Delete all members of a conversation
  Future<void> deleteMembersByConversationId(int conversationId) async {
    final db = sqliteDatabase.database;
    await (db.delete(
      db.conversationMembers,
    )..where((t) => t.conversationId.equals(conversationId))).go();
  }

  /// Delete a member by conversation ID and user ID
  Future<void> deleteMemberByConversationAndUserId(
    int conversationId,
    int userId,
  ) async {
    final db = sqliteDatabase.database;
    await (db.delete(db.conversationMembers)..where(
          (t) =>
              t.userId.equals(userId) & t.conversationId.equals(conversationId),
        ))
        .go();
  }
}
