// lib/repositories/group_members_repository.dart
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class GroupMemberInfo {
  final int userId;
  final String userName;
  final String? profilePic;
  final String role;
  final String? joinedAt;

  GroupMemberInfo({
    required this.userId,
    required this.userName,
    this.profilePic,
    required this.role,
    this.joinedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'user_name': userName,
      'profile_pic': profilePic,
      'role': role,
      'joined_at': joinedAt,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory GroupMemberInfo.fromMap(Map<String, dynamic> map) {
    return GroupMemberInfo(
      userId: map['user_id'] as int,
      userName: map['user_name'] as String,
      profilePic: map['profile_pic'] as String?,
      role: map['role'] as String,
      joinedAt: map['joined_at'] as String?,
    );
  }
}

class GroupMembersRepository {
  final dbHelper = DatabaseHelper.instance;

  /// Insert or update a single group member
  Future<int> insertOrUpdateGroupMember(
    int conversationId,
    GroupMemberInfo member,
  ) async {
    final db = await dbHelper.database;
    return await db.insert('group_members', {
      'conversation_id': conversationId,
      ...member.toMap(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert or update multiple group members for a conversation
  Future<void> insertOrUpdateGroupMembers(
    int conversationId,
    List<GroupMemberInfo> members,
  ) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    for (final member in members) {
      batch.insert('group_members', {
        'conversation_id': conversationId,
        ...member.toMap(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Get all members for a specific group/conversation
  Future<List<GroupMemberInfo>> getGroupMembers(int conversationId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'group_members',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'user_name COLLATE NOCASE ASC',
    );
    return rows.map((r) => GroupMemberInfo.fromMap(r)).toList();
  }

  /// Get a specific member in a group
  Future<GroupMemberInfo?> getGroupMember(
    int conversationId,
    int userId,
  ) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'group_members',
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GroupMemberInfo.fromMap(rows.first);
  }

  /// Get member info by user ID across all groups
  Future<GroupMemberInfo?> getMemberByUserId(int userId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'group_members',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return GroupMemberInfo.fromMap(rows.first);
  }

  /// Delete a member from a group
  Future<int> deleteGroupMember(int conversationId, int userId) async {
    final db = await dbHelper.database;
    return await db.delete(
      'group_members',
      where: 'conversation_id = ? AND user_id = ?',
      whereArgs: [conversationId, userId],
    );
  }

  /// Delete all members of a group
  Future<int> deleteGroupMembers(int conversationId) async {
    final db = await dbHelper.database;
    return await db.delete(
      'group_members',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  /// Clear all group members
  Future<void> clearAllGroupMembers() async {
    final db = await dbHelper.database;
    await db.delete('group_members');
  }

  Future close() async => dbHelper.close();
}
