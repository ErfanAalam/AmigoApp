import 'sqlite.schema.dart';
import 'package:flutter/material.dart';

class SqliteDatabase {
  static final SqliteDatabase instance = SqliteDatabase._init();
  AppDatabase? _db;

  SqliteDatabase._init();

  AppDatabase get database {
    _db ??= AppDatabase();
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> clearAllData() async {
    final db = database;
    await db.transaction(() async {
      await db.delete(db.users).go();
      await db.delete(db.contacts).go();
      await db.delete(db.calls).go();
      await db.delete(db.conversations).go();
      await db.delete(db.conversationMembers).go();
      await db.delete(db.messages).go();
      await db.delete(db.messageStatusModel).go();
    });
  }

  Future<void> resetInstance() async {
    await close();
    debugPrint('✅ Database instance reset successfully');
  }
}
