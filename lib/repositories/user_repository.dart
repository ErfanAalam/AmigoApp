// lib/repositories/user_repository.dart
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/user_model.dart';

class UserRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<int> insertOrUpdateUser(
    UserModel user, {
    bool markNeedsSync = false,
  }) async {
    final db = await dbHelper.database;
    return await db.insert(
      'users',
      user.toDbMap(markNeedsSync: markNeedsSync),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // get a user by id
  Future<UserModel?> getUserById(int id) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserModel.fromDb(rows.first);
  }

  // get first user (useful if you only store current user)
  Future<UserModel?> getFirstUser() async {
    final db = await dbHelper.database;
    final rows = await db.query('users', limit: 1);
    if (rows.isEmpty) return null;
    return UserModel.fromDb(rows.first);
  }

  Future<int> deleteUser(int id) async {
    final db = await dbHelper.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<UserModel>> getPendingSyncUsers() async {
    final db = await dbHelper.database;
    final rows = await db.query('users', where: 'needs_sync = 1');
    return rows.map((r) => UserModel.fromDb(r)).toList();
  }

  Future<int> markUserSynced(int id) async {
    final db = await dbHelper.database;
    return await db.update(
      'users',
      {'needs_sync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertOrUpdateUsers(List<UserModel> users) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    for (final user in users) {
      batch.insert(
        'users',
        user.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await dbHelper.database;
    final rows = await db.query('users', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map((r) => UserModel.fromDb(r)).toList();
  }

  Future<void> replaceAllUsers(List<UserModel> users) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('users');
      final batch = txn.batch();
      for (final user in users) {
        batch.insert(
          'users',
          user.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future close() async => dbHelper.close();
}
