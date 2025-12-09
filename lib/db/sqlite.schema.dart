import 'package:amigo/db/type-converters.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'sqlite.schema.g.dart';

// Users Table
class Users extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get role => text().nullable()();
  BoolColumn get isOnline => boolean()();
  TextColumn get profilePic => text().nullable()();
  BoolColumn get callAccess => boolean().nullable()();

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
  TextColumn get endedAt => text().nullable()();
  TextColumn get status => text()();
  TextColumn get callType => text()();

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
  IntColumn get lastMessageId => integer().nullable()();
  IntColumn get pinnedMessageId => integer().nullable()();
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
  IntColumn get lastReadMessageId => integer().nullable()();
  IntColumn get lastDeliveredMessageId => integer().nullable()();
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
  IntColumn get messageId => integer()();
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
  int get schemaVersion => 2;

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
