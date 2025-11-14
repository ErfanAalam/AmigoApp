// lib/repositories/communities_repository.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import '../../models/community_model.dart';

class CommunitiesRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<int> insertOrUpdateCommunity(CommunityModel community) async {
    final db = await dbHelper.database;
    return await db.insert(
      'communities',
      _communityToMap(community),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertOrUpdateCommunities(
    List<CommunityModel> communities,
  ) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    for (final community in communities) {
      batch.insert(
        'communities',
        _communityToMap(community),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CommunityModel>> getAllCommunities() async {
    final db = await dbHelper.database;
    final rows = await db.query('communities', orderBy: 'updated_at DESC');
    return rows.map((r) => _mapToCommunity(r)).toList();
  }

  Future<CommunityModel?> getCommunityById(int id) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'communities',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapToCommunity(rows.first);
  }

  Future<int> deleteCommunity(int id) async {
    final db = await dbHelper.database;
    return await db.delete('communities', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearCommunities() async {
    final db = await dbHelper.database;
    await db.delete('communities');
  }

  Map<String, dynamic> _communityToMap(CommunityModel community) {
    return {
      'id': community.id,
      'name': community.name,
      'group_ids': jsonEncode(community.groupIds),
      'metadata': jsonEncode(community.metadata),
      'created_at': community.createdAt,
      'updated_at': community.updatedAt,
    };
  }

  CommunityModel _mapToCommunity(Map<String, dynamic> map) {
    // Parse group_ids from JSON
    List<int> groupIds = [];
    if (map['group_ids'] != null) {
      try {
        final groupIdsList = jsonDecode(map['group_ids'] as String) as List;
        groupIds = groupIdsList.map((id) => id as int).toList();
      } catch (e) {
        print('Error parsing group_ids: $e');
      }
    }

    // Parse metadata from JSON
    Map<String, dynamic> metadata = {};
    if (map['metadata'] != null) {
      try {
        metadata =
            jsonDecode(map['metadata'] as String) as Map<String, dynamic>;
      } catch (e) {
        print('Error parsing metadata: $e');
      }
    }

    return CommunityModel(
      id: map['id'] as int,
      name: map['name'] as String,
      groupIds: groupIds,
      metadata: metadata,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  Future close() async => dbHelper.close();
}
