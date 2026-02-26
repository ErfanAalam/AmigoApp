import 'package:amigo/db/type-converters.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'sqlite.schema.g.dart';

// Users Table
class Users extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get username => text().nullable()(); // Name from contact list
  TextColumn get phone => text()();
  TextColumn get role => text().nullable()();
  BoolColumn get isOnline => boolean()();
  TextColumn get profilePic => text().nullable()();
  BoolColumn get callAccess =>
      boolean().withDefault(const Constant(true)).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Contacts Table
class Contacts extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get profilePic => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Calls Table
class Calls extends Table {
  IntColumn get id => integer()();
  IntColumn get callerId => integer()();
  IntColumn get calleeId => integer()();
  TextColumn get startedAt => text()();
  TextColumn get answeredAt => text().nullable()();
  TextColumn get endedAt => text().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  TextColumn get status => text()();
  TextColumn get reason => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// Conversations Table
class Conversations extends Table {
  IntColumn get id => integer()();
  TextColumn get type => text()(); // 'dm' or 'group' or 'community_group'
  TextColumn get title => text().nullable()();
  IntColumn get createrId => integer()();
  IntColumn get unreadCount =>
      integer().withDefault(const Constant(0)).nullable()();
  Int64Column get lastMessageId => int64().nullable()();
  Int64Column get pinnedMessageId => int64().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();
  BoolColumn get needSync => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

// Conversation Members Table
class ConversationMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get conversationId => integer()();
  IntColumn get userId => integer()();
  TextColumn get role => text()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  TextColumn get joinedAt => text().nullable()();
  TextColumn get removedAt => text().nullable()();
  Int64Column get lastReadMessageId => int64().nullable()();
  Int64Column get lastDeliveredMessageId => int64().nullable()();
}

// Messages Table
class Messages extends Table {
  Int64Column get id => int64()();
  IntColumn get conversationId => integer()();
  IntColumn get senderId => integer()();
  TextColumn get type => text()();
  TextColumn get body => text().nullable()();
  TextColumn get status => text()();
  TextColumn get attachments =>
      text().nullable().map(const JsonMapConverter())();
  TextColumn get metadata => text().nullable().map(const JsonMapConverter())();
  BoolColumn get isFailed => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();
  BoolColumn get isReplied => boolean().withDefault(const Constant(false))();
  BoolColumn get isForwarded => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get sentAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class MessageStatusModel extends Table {
  Int64Column get id => int64().autoIncrement()();
  IntColumn get conversationId => integer()();
  Int64Column get messageId => int64()();
  IntColumn get userId => integer()();
  TextColumn get deliveredAt => text().nullable()();
  TextColumn get readAt => text().nullable()();
}

@DriftDatabase(
  tables: [
    Users,
    Contacts,
    Calls,
    Conversations,
    ConversationMembers,
    Messages,
    MessageStatusModel,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // Create unique index on messageId and userId
        await m.database.customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS unique_user_message ON message_status_model(message_id, user_id)',
        );
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration from version 1 to 2
        if (from < 2) {
          // Clean up any duplicate entries before adding the unique constraint
          // Keep the row with the highest id (most recent) for each (messageId, userId) pair
          await m.database.customStatement('''
            DELETE FROM message_status_model
            WHERE id NOT IN (
              SELECT MAX(id)
              FROM message_status_model
              GROUP BY message_id, user_id
            )
          ''');

          // Create unique index on messageId and userId
          await m.database.customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS unique_user_message ON message_status_model(message_id, user_id)',
          );
        }

        // Migration from version 2 to 3
        if (from < 3) {
          // 1. Users table: Add username column
          await m.database.customStatement('''
            ALTER TABLE users ADD COLUMN username TEXT;
          ''');

          // 2. Calls table: Migrate to new schema
          // Add new columns first
          await m.database.customStatement('''
            ALTER TABLE calls ADD COLUMN answered_at TEXT;
            ALTER TABLE calls ADD COLUMN duration_seconds INTEGER DEFAULT 0;
            ALTER TABLE calls ADD COLUMN reason TEXT;
            ALTER TABLE calls ADD COLUMN created_at TEXT;
          ''');

          // Set created_at to started_at for existing records
          await m.database.customStatement('''
            UPDATE calls SET created_at = started_at WHERE created_at IS NULL;
          ''');

          // Remove callType column by recreating table
          // SQLite doesn't support DROP COLUMN directly in older versions
          await m.database.customStatement('''
            CREATE TABLE calls_new (
              id INTEGER NOT NULL PRIMARY KEY,
              caller_id INTEGER NOT NULL,
              callee_id INTEGER NOT NULL,
              started_at TEXT NOT NULL,
              answered_at TEXT,
              ended_at TEXT,
              duration_seconds INTEGER NOT NULL DEFAULT 0,
              status TEXT NOT NULL,
              reason TEXT,
              created_at TEXT NOT NULL
            );
          ''');

          // Copy data from old table to new table (excluding callType)
          await m.database.customStatement('''
            INSERT INTO calls_new (id, caller_id, callee_id, started_at, ended_at, duration_seconds, status, reason, created_at)
            SELECT 
              id, 
              caller_id, 
              callee_id, 
              started_at, 
              ended_at, 
              COALESCE(duration_seconds, 0) as duration_seconds,
              status,
              reason,
              COALESCE(created_at, started_at, datetime('now')) as created_at
            FROM calls;
          ''');

          // Drop old table and rename new one
          await m.database.customStatement('DROP TABLE calls;');
          await m.database.customStatement(
            'ALTER TABLE calls_new RENAME TO calls;',
          );

          // 3. Conversations table: Change lastMessageId and pinnedMessageId from INTEGER to INTEGER (BIGINT/INT64)
          // SQLite stores integers as 64-bit, but we need to ensure the column type is correct
          // Recreate table to change column types
          await m.database.customStatement('''
            CREATE TABLE conversations_new (
              id INTEGER NOT NULL PRIMARY KEY,
              type TEXT NOT NULL,
              title TEXT,
              creater_id INTEGER NOT NULL,
              unread_count INTEGER DEFAULT 0,
              last_message_id INTEGER,
              pinned_message_id INTEGER,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              is_pinned INTEGER NOT NULL DEFAULT 0,
              is_favorite INTEGER NOT NULL DEFAULT 0,
              is_muted INTEGER NOT NULL DEFAULT 0,
              created_at TEXT,
              updated_at TEXT,
              need_sync INTEGER NOT NULL DEFAULT 1
            );
          ''');

          // Copy data explicitly listing all columns (SQLite will handle integer conversion automatically)
          await m.database.customStatement('''
            INSERT INTO conversations_new (
              id, type, title, creater_id, unread_count, last_message_id, 
              pinned_message_id, is_deleted, is_pinned, is_favorite, is_muted, 
              created_at, updated_at, need_sync
            )
            SELECT 
              id, type, title, creater_id, unread_count, last_message_id, 
              pinned_message_id, is_deleted, is_pinned, is_favorite, is_muted, 
              created_at, updated_at, need_sync
            FROM conversations;
          ''');

          await m.database.customStatement('DROP TABLE conversations;');
          await m.database.customStatement(
            'ALTER TABLE conversations_new RENAME TO conversations;',
          );

          // 4. ConversationMembers table: Change lastReadMessageId and lastDeliveredMessageId to INT64
          await m.database.customStatement('''
            CREATE TABLE conversation_members_new (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              conversation_id INTEGER NOT NULL,
              user_id INTEGER NOT NULL,
              role TEXT NOT NULL,
              unread_count INTEGER NOT NULL DEFAULT 0,
              joined_at TEXT,
              removed_at TEXT,
              last_read_message_id INTEGER,
              last_delivered_message_id INTEGER
            );
          ''');

          await m.database.customStatement('''
            INSERT INTO conversation_members_new (
              id, conversation_id, user_id, role, unread_count, 
              joined_at, removed_at, last_read_message_id, last_delivered_message_id
            )
            SELECT 
              id, conversation_id, user_id, role, unread_count, 
              joined_at, removed_at, last_read_message_id, last_delivered_message_id
            FROM conversation_members;
          ''');

          await m.database.customStatement('DROP TABLE conversation_members;');
          await m.database.customStatement(
            'ALTER TABLE conversation_members_new RENAME TO conversation_members;',
          );

          // 5. Messages table: Add isFailed column
          await m.database.customStatement('''
            ALTER TABLE messages ADD COLUMN is_failed INTEGER NOT NULL DEFAULT 1;
          ''');

          // 6. MessageStatusModel table: Change messageId from INTEGER to INT64
          await m.database.customStatement('''
            CREATE TABLE message_status_model_new (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              conversation_id INTEGER NOT NULL,
              message_id INTEGER NOT NULL,
              user_id INTEGER NOT NULL,
              delivered_at TEXT,
              read_at TEXT
            );
          ''');

          await m.database.customStatement('''
            INSERT INTO message_status_model_new (
              id, conversation_id, message_id, user_id, delivered_at, read_at
            )
            SELECT 
              id, conversation_id, message_id, user_id, delivered_at, read_at
            FROM message_status_model;
          ''');

          await m.database.customStatement('DROP TABLE message_status_model;');
          await m.database.customStatement(
            'ALTER TABLE message_status_model_new RENAME TO message_status_model;',
          );

          // Recreate the unique index after table recreation
          await m.database.customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS unique_user_message ON message_status_model(message_id, user_id)',
          );
        }

        // Migration from version 3 to 4
        if (from < 4) {
          // Messages table: Change isFailed default from true (1) to false (0)
          // SQLite doesn't support changing column defaults, so we recreate the table
          await m.database.customStatement('''
            CREATE TABLE messages_new (
              id INTEGER NOT NULL PRIMARY KEY,
              conversation_id INTEGER NOT NULL,
              sender_id INTEGER NOT NULL,
              type TEXT NOT NULL,
              body TEXT,
              status TEXT NOT NULL,
              attachments TEXT,
              metadata TEXT,
              is_failed INTEGER NOT NULL DEFAULT 0,
              is_pinned INTEGER NOT NULL DEFAULT 0,
              is_starred INTEGER NOT NULL DEFAULT 0,
              is_replied INTEGER NOT NULL DEFAULT 0,
              is_forwarded INTEGER NOT NULL DEFAULT 0,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              sent_at TEXT NOT NULL
            );
          ''');

          // Copy data from old table to new table
          // Preserve existing is_failed values (only new records will get the new default of 0)
          await m.database.customStatement('''
            INSERT INTO messages_new (
              id, conversation_id, sender_id, type, body, status, 
              attachments, metadata, is_failed, is_pinned, is_starred, 
              is_replied, is_forwarded, is_deleted, sent_at
            )
            SELECT 
              id, conversation_id, sender_id, type, body, status,
              attachments, metadata, is_failed,
              is_pinned, is_starred, is_replied, is_forwarded, is_deleted, sent_at
            FROM messages;
          ''');

          // Drop old table and rename new one
          await m.database.customStatement('DROP TABLE messages;');
          await m.database.customStatement(
            'ALTER TABLE messages_new RENAME TO messages;',
          );
        }
      },
    );
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'amigo_chats.db',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
