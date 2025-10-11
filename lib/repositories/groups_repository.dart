// lib/repositories/groups_repository.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/group_model.dart';

class GroupsRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<int> insertOrUpdateGroup(GroupModel group) async {
    final db = await dbHelper.database;
    return await db.insert(
      'groups',
      _groupToMap(group),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOrUpdateGroups(List<GroupModel> groups) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    for (final group in groups) {
      batch.insert(
        'groups',
        _groupToMap(group),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<GroupModel>> getAllGroups() async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'groups',
      orderBy: 'last_message_at DESC, joined_at DESC',
    );
    return rows.map((r) => _mapToGroup(r)).toList();
  }

  Future<GroupModel?> getGroupById(int conversationId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'groups',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapToGroup(rows.first);
  }

  Future<int> deleteGroup(int conversationId) async {
    final db = await dbHelper.database;
    return await db.delete(
      'groups',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> clearGroups() async {
    final db = await dbHelper.database;
    await db.delete('groups');
  }

  Map<String, dynamic> _groupToMap(GroupModel group) {
    return {
      'conversation_id': group.conversationId,
      'title': group.title,
      'type': group.type,
      'role': group.role,
      'joined_at': group.joinedAt,
      'last_message_at': group.lastMessageAt,
      'last_message_id': group.metadata?.lastMessage?.id,
      'last_message_body': group.metadata?.lastMessage?.body,
      'last_message_type': group.metadata?.lastMessage?.type,
      'last_message_sender_id': group.metadata?.lastMessage?.senderId,
      'last_message_sender_name': group.metadata?.lastMessage?.senderName,
      'last_message_created_at': group.metadata?.lastMessage?.createdAt,
      'total_messages': group.metadata?.totalMessages ?? 0,
      'created_at': group.metadata?.createdAt,
      'created_by': group.metadata?.createdBy,
      'members': jsonEncode(group.members.map((m) => m.toJson()).toList()),
      'unread_count': group.unreadCount,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  GroupModel _mapToGroup(Map<String, dynamic> map) {
    GroupMetadata? metadata;
    if (map['last_message_id'] != null || map['total_messages'] != null) {
      GroupLastMessage? lastMessage;
      if (map['last_message_id'] != null) {
        lastMessage = GroupLastMessage(
          id: map['last_message_id'] as int,
          body: map['last_message_body'] as String? ?? '',
          type: map['last_message_type'] as String? ?? 'text',
          senderId: map['last_message_sender_id'] as int? ?? 0,
          senderName: map['last_message_sender_name'] as String? ?? '',
          createdAt:
              map['last_message_created_at'] as String? ??
              DateTime.now().toIso8601String(),
          conversationId: map['conversation_id'] as int,
        );
      }

      metadata = GroupMetadata(
        lastMessage: lastMessage,
        totalMessages: map['total_messages'] as int? ?? 0,
        createdAt: map['created_at'] as String?,
        createdBy: map['created_by'] as int? ?? 0,
      );
    }

    // Parse members from JSON
    List<GroupMember> members = [];
    if (map['members'] != null) {
      try {
        final membersList = jsonDecode(map['members'] as String) as List;
        members = membersList
            .map((m) => GroupMember.fromJson(m as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error parsing members: $e');
      }
    }

    return GroupModel(
      conversationId: map['conversation_id'] as int,
      title: map['title'] as String,
      type: map['type'] as String,
      members: members,
      metadata: metadata,
      lastMessageAt: map['last_message_at'] as String?,
      role: map['role'] as String?,
      unreadCount: map['unread_count'] as int? ?? 0,
      joinedAt: map['joined_at'] as String,
    );
  }

  Future close() async => dbHelper.close();
}
