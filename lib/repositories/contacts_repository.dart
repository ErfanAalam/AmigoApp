// lib/repositories/contacts_repository.dart
import 'package:sqflite/sqflite.dart';
import '../db/database_helper.dart';
import '../models/user_model.dart';

class ContactsRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<int> insertOrUpdateContact(UserModel contact) async {
    final db = await dbHelper.database;
    return await db.insert('contacts', {
      'id': contact.id,
      'name': contact.name,
      'phone': contact.phone,
      'profile_pic': contact.profilePic,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertOrUpdateContacts(List<UserModel> contacts) async {
    final db = await dbHelper.database;
    final batch = db.batch();
    for (final contact in contacts) {
      batch.insert('contacts', {
        'id': contact.id,
        'name': contact.name,
        'phone': contact.phone,
        'profile_pic': contact.profilePic,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<UserModel>> getAllContacts() async {
    final db = await dbHelper.database;
    final rows = await db.query('contacts', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map((r) => UserModel.fromDb(r)).toList();
  }

  Future<void> replaceAllContacts(List<UserModel> contacts) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('contacts');
      final batch = txn.batch();
      for (final contact in contacts) {
        batch.insert('contacts', {
          'id': contact.id,
          'name': contact.name,
          'phone': contact.phone,
          'profile_pic': contact.profilePic,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> deleteContact(int id) async {
    final db = await dbHelper.database;
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearContacts() async {
    final db = await dbHelper.database;
    await db.delete('contacts');
  }

  Future close() async => dbHelper.close();
}
