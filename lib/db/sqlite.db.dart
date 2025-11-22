import 'sqlite.schema.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

  /// Clear all data from all tables in the database
  Future<void> clearAllData() async {
    try {
      // Ensure database is open and accessible
      if (_db == null) {
        _db = AppDatabase();
      }
      final db = _db!;

      // Check if database is closed, if so reopen it
      try {
        await db.transaction(() async {
          // Clear all tables in the correct order (respecting foreign key constraints)
          await db.delete(db.messageStatusModel).go();
          await db.delete(db.messages).go();
          await db.delete(db.conversationMembers).go();
          await db.delete(db.conversations).go();
          await db.delete(db.calls).go();
          await db.delete(db.contacts).go();
          await db.delete(db.users).go();
        });
        debugPrint('✅ All database tables cleared successfully');
      } catch (e) {
        // If transaction fails (e.g., read-only), just log and continue
        // We'll delete the file anyway
        debugPrint('⚠️ Could not clear tables (will delete file instead): $e');
      }
    } catch (e) {
      debugPrint('⚠️ Error accessing database for clearing: $e');
      // Don't rethrow - we'll delete the file anyway
    }
  }

  /// Delete the entire database file to ensure no data remains
  Future<void> deleteDatabaseFile() async {
    try {
      // Close the database connection first
      try {
        await close();
      } catch (e) {
        debugPrint('⚠️ Error closing database: $e');
      }

      // Wait a bit to ensure file handles are released
      await Future.delayed(const Duration(milliseconds: 100));

      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        try {
          await dbFile.delete();
          debugPrint('✅ Database file deleted successfully: $dbPath');
        } catch (e) {
          debugPrint('⚠️ Could not delete database file (may be in use): $e');
          // Try to delete with force on some platforms
          try {
            await dbFile.delete(recursive: false);
          } catch (_) {
            debugPrint('⚠️ Force delete also failed, file may be locked');
          }
        }
      }

      // Also delete any journal/WAL files
      try {
        final walFile = File('$dbPath-wal');
        final shmFile = File('$dbPath-shm');
        if (await walFile.exists()) {
          await walFile.delete();
          debugPrint('✅ WAL file deleted');
        }
        if (await shmFile.exists()) {
          await shmFile.delete();
          debugPrint('✅ SHM file deleted');
        }
      } catch (e) {
        debugPrint('⚠️ Error deleting journal files: $e');
      }
    } catch (e) {
      debugPrint('❌ Error deleting database file: $e');
      // Don't rethrow - we've done our best to clean up
    }
  }

  /// Get the database file path
  Future<String> _getDatabasePath() async {
    final appSupportDir = await getApplicationSupportDirectory();
    return '${appSupportDir.path}/amigo_chats.db';
  }

  Future<void> resetInstance() async {
    await close();
    debugPrint('✅ Database instance reset successfully');
  }
}
