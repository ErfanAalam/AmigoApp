// lib/db/database_helper.dart
import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _db;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('amigo_chat_app.db');
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 9,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // initial create
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        role TEXT NOT NULL,
        profile_pic TEXT,
        call_access INTEGER NOT NULL DEFAULT 0,
        needs_sync INTEGER NOT NULL DEFAULT 0, -- 0/1 flag for pending local updates
        updated_at INTEGER -- unix ms, optional
      );
    ''');

    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        profile_pic TEXT,
        updated_at INTEGER
      );
    ''');

    await db.execute('''
    CREATE TABLE calls (
      id INTEGER PRIMARY KEY,
      caller_id INTEGER NOT NULL,
      callee_id INTEGER NOT NULL,
      contact_id INTEGER NOT NULL,
      contact_name TEXT,
      contact_profile_pic TEXT,
      started_at TEXT NOT NULL,
      answered_at TEXT,
      ended_at TEXT,
      duration_seconds INTEGER NOT NULL,
      status TEXT NOT NULL,
      reason TEXT,
      call_type TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
  ''');

    await db.execute('''
      CREATE TABLE conversations (
        conversation_id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        user_profile_pic TEXT,
        joined_at TEXT NOT NULL,
        unread_count INTEGER NOT NULL DEFAULT 0,
        last_message_id INTEGER,
        last_message_body TEXT,
        last_message_type TEXT,
        last_message_sender_id INTEGER,
        last_message_created_at TEXT,
        last_message_at TEXT,
        pinned_message_id INTEGER,
        pinned_message_user_id INTEGER,
        pinned_message_pinned_at TEXT,
        is_online INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE groups (
        conversation_id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        role TEXT,
        joined_at TEXT NOT NULL,
        last_message_at TEXT,
        last_message_id INTEGER,
        last_message_body TEXT,
        last_message_type TEXT,
        last_message_sender_id INTEGER,
        last_message_sender_name TEXT,
        last_message_created_at TEXT,
        total_messages INTEGER DEFAULT 0,
        created_at TEXT,
        created_by INTEGER,
        members TEXT,
        unread_count INTEGER NOT NULL DEFAULT 0,
        pinned_message_id INTEGER,
        pinned_message_user_id INTEGER,
        pinned_message_pinned_at TEXT,
        updated_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE communities (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        group_ids TEXT NOT NULL,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY,
        conversation_id INTEGER NOT NULL,
        sender_id INTEGER NOT NULL,
        sender_name TEXT,
        sender_profile_pic TEXT,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        edited_at TEXT,
        deleted INTEGER DEFAULT 0,
        is_delivered INTEGER DEFAULT 0,
        is_read INTEGER DEFAULT 0,
        reply_to_message_id INTEGER,
        reply_to_body TEXT,
        reply_to_sender_id INTEGER,
        reply_to_sender_name TEXT,
        reply_to_sender_profile_pic TEXT,
        reply_to_type TEXT,
        reply_to_created_at TEXT,
        attachments TEXT,
        metadata TEXT,
        pinned INTEGER DEFAULT 0,
        starred INTEGER DEFAULT 0,
        local_media_path TEXT,
        updated_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at);
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_id ON messages(id);
    ''');

    await db.execute('''
      CREATE TABLE conversation_meta (
        conversation_id INTEGER PRIMARY KEY,
        total_count INTEGER NOT NULL,
        current_page INTEGER NOT NULL,
        total_pages INTEGER NOT NULL,
        has_next_page INTEGER NOT NULL,
        has_previous_page INTEGER NOT NULL,
        last_sync_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE group_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        profile_pic TEXT,
        role TEXT NOT NULL DEFAULT 'member',
        joined_at TEXT,
        updated_at INTEGER NOT NULL,
        UNIQUE(conversation_id, user_id)
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_group_members_conversation ON group_members(conversation_id);
    ''');

    await db.execute('''
      CREATE INDEX idx_group_members_user ON group_members(user_id);
    ''');
  }

  // simple migration example
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // add contacts table
      await db.execute('''
      CREATE TABLE IF NOT EXISTS contacts (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        role TEXT NOT NULL,
        profile_pic TEXT,
        updated_at INTEGER
      );
    ''');

      // create calls table for existing DB
      await db.execute('''
      CREATE TABLE IF NOT EXISTS calls (
        id INTEGER PRIMARY KEY,
        caller_id INTEGER NOT NULL,
        callee_id INTEGER NOT NULL,
        contact_id INTEGER NOT NULL,
        contact_name TEXT,
        contact_profile_pic TEXT,
        started_at TEXT NOT NULL,
        answered_at TEXT,
        ended_at TEXT,
        duration_seconds INTEGER NOT NULL,
        status TEXT NOT NULL,
        reason TEXT,
        call_type TEXT NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');

      // create conversations table for existing DB
      await db.execute('''
      CREATE TABLE IF NOT EXISTS conversations (
        conversation_id INTEGER PRIMARY KEY,
        type TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        user_profile_pic TEXT,
        joined_at TEXT NOT NULL,
        unread_count INTEGER NOT NULL DEFAULT 0,
        last_message_id INTEGER,
        last_message_body TEXT,
        last_message_type TEXT,
        last_message_sender_id INTEGER,
        last_message_created_at TEXT,
        last_message_at TEXT,
        is_online INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');
    }

    if (oldVersion < 3) {
      // create groups table for existing DB
      await db.execute('''
      CREATE TABLE IF NOT EXISTS groups (
        conversation_id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        role TEXT,
        joined_at TEXT NOT NULL,
        last_message_at TEXT,
        last_message_id INTEGER,
        last_message_body TEXT,
        last_message_type TEXT,
        last_message_sender_id INTEGER,
        last_message_sender_name TEXT,
        last_message_created_at TEXT,
        total_messages INTEGER DEFAULT 0,
        created_at TEXT,
        created_by INTEGER,
        members TEXT,
        updated_at INTEGER NOT NULL
      );
    ''');

      // create communities table for existing DB
      await db.execute('''
      CREATE TABLE IF NOT EXISTS communities (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        group_ids TEXT NOT NULL,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    }

    if (oldVersion < 4) {
      // create messages table for existing DB
      await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY,
        conversation_id INTEGER NOT NULL,
        sender_id INTEGER NOT NULL,
        sender_name TEXT,
        sender_profile_pic TEXT,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        edited_at TEXT,
        deleted INTEGER DEFAULT 0,
        is_delivered INTEGER DEFAULT 0,
        is_read INTEGER DEFAULT 0,
        reply_to_message_id INTEGER,
        reply_to_body TEXT,
        reply_to_sender_id INTEGER,
        reply_to_sender_name TEXT,
        reply_to_sender_profile_pic TEXT,
        reply_to_type TEXT,
        reply_to_created_at TEXT,
        attachments TEXT,
        metadata TEXT,
        pinned INTEGER DEFAULT 0,
        starred INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');

      await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at);
    ''');

      await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_messages_id ON messages(id);
    ''');

      // create conversation_meta table for existing DB
      await db.execute('''
      CREATE TABLE IF NOT EXISTS conversation_meta (
        conversation_id INTEGER PRIMARY KEY,
        total_count INTEGER NOT NULL,
        current_page INTEGER NOT NULL,
        total_pages INTEGER NOT NULL,
        has_next_page INTEGER NOT NULL,
        has_previous_page INTEGER NOT NULL,
        last_sync_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    }

    if (oldVersion < 5) {
      // Add local_media_path column to messages table
      await db.execute('''
        ALTER TABLE messages ADD COLUMN local_media_path TEXT;
      ''');
    }

    if (oldVersion < 6) {
      // Create group_members table for existing DB
      await db.execute('''
        CREATE TABLE IF NOT EXISTS group_members (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          conversation_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          user_name TEXT NOT NULL,
          profile_pic TEXT,
          role TEXT NOT NULL DEFAULT 'member',
          joined_at TEXT,
          updated_at INTEGER NOT NULL,
          UNIQUE(conversation_id, user_id)
        );
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_group_members_conversation ON group_members(conversation_id);
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_group_members_user ON group_members(user_id);
      ''');

      // Migrate existing group members from users table to group_members table
      // Note: This assumes members are stored in the groups.members JSON field
      // We'll populate this from the groups table members field
      final groups = await db.query('groups');
      for (final group in groups) {
        final membersJson = group['members'] as String?;
        if (membersJson != null && membersJson.isNotEmpty) {
          try {
            final members = jsonDecode(membersJson) as List;
            for (final member in members) {
              final memberMap = member as Map<String, dynamic>;
              await db.insert('group_members', {
                'conversation_id': group['conversation_id'],
                'user_id': memberMap['userId'] ?? memberMap['user_id'] ?? 0,
                'user_name': memberMap['name'] ?? memberMap['userName'] ?? '',
                'profile_pic':
                    memberMap['profilePic'] ?? memberMap['profile_pic'],
                'role': memberMap['role'] ?? 'member',
                'joined_at': memberMap['joinedAt'] ?? memberMap['joined_at'],
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              }, conflictAlgorithm: ConflictAlgorithm.ignore);
            }
          } catch (e) {
            print(
              'Error migrating members for group ${group['conversation_id']}: $e',
            );
          }
        }
      }

      // Clean up users table - keep only users with call_access (likely the current user)
      // or keep the first user if none have call_access
      final users = await db.query('users', orderBy: 'id ASC');
      if (users.isNotEmpty) {
        final currentUser = users.firstWhere(
          (u) => (u['call_access'] as int? ?? 0) == 1,
          orElse: () => users.first,
        );
        // Delete all users except the current user
        await db.delete(
          'users',
          where: 'id != ?',
          whereArgs: [currentUser['id']],
        );
      }
    }

    if (oldVersion < 7) {
      // Add unread_count column to groups table
      try {
        await db.execute('''
          ALTER TABLE groups ADD COLUMN unread_count INTEGER NOT NULL DEFAULT 0;
        ''');
        print('✅ Added unread_count column to groups table');
      } catch (e) {
        // Column might already exist, ignore error
        print('⚠️ Error adding unread_count column (might already exist): $e');
      }
    }

    if (oldVersion < 8) {
      // Add role column to users table
      await db.execute('''
        ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user';
      ''');
      print('✅ Added role column to users table');
    }

    if (oldVersion < 9) {
      // Add pinned message columns to conversations table
      try {
        await db.execute('''
          ALTER TABLE conversations ADD COLUMN pinned_message_id INTEGER;
        ''');
        await db.execute('''
          ALTER TABLE conversations ADD COLUMN pinned_message_user_id INTEGER;
        ''');
        await db.execute('''
          ALTER TABLE conversations ADD COLUMN pinned_message_pinned_at TEXT;
        ''');
        print('✅ Added pinned message columns to conversations table');
      } catch (e) {
        // Columns might already exist, ignore error
        print(
          '⚠️ Error adding pinned message columns to conversations (might already exist): $e',
        );
      }

      // Add pinned message columns to groups table
      try {
        await db.execute('''
          ALTER TABLE groups ADD COLUMN pinned_message_id INTEGER;
        ''');
        await db.execute('''
          ALTER TABLE groups ADD COLUMN pinned_message_user_id INTEGER;
        ''');
        await db.execute('''
          ALTER TABLE groups ADD COLUMN pinned_message_pinned_at TEXT;
        ''');
        print('✅ Added pinned message columns to groups table');
      } catch (e) {
        // Columns might already exist, ignore error
        print(
          '⚠️ Error adding pinned message columns to groups (might already exist): $e',
        );
      }
    }
  }

  /// Clear all data from all tables (used during logout)
  Future<void> clearAllData() async {
    final db = await instance.database;

    try {
      await db.transaction((txn) async {
        // Clear all tables in the correct order (respecting foreign key constraints)
        await txn.delete('messages');
        await txn.delete('conversation_meta');
        await txn.delete('conversations');
        await txn.delete('group_members');
        await txn.delete('groups');
        await txn.delete('communities');
        await txn.delete('calls');
        await txn.delete('contacts');
        await txn.delete('users');

        print('✅ All database tables cleared successfully');
      });
    } catch (e) {
      print('❌ Error clearing database: $e');
      rethrow;
    }
  }

  /// Reset database instance (close and clear cached instance)
  Future<void> resetInstance() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      print('✅ Database instance reset successfully');
    }
  }

  /// Close database connection and reset instance
  Future close() async {
    final db = await instance.database;
    await db.close();
    _db = null;
  }
}
