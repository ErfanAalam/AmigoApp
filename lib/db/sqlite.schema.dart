import 'package:amigo/db/type_converters.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:amigo/types/call.type.dart';
import 'package:amigo/types/chat.type.dart';
import 'package:amigo/types/user.type.dart';

part 'sqlite.schema.g.dart';

// Users Table
class Users extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get role => text().map(const EnumNameConverter(UserRole.values))();
  TextColumn get profilePic => text().nullable()();

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
  TextColumn get status =>
      text().map(const EnumNameConverter(CallStatus.values))();
  TextColumn get callType =>
      text().map(const EnumNameConverter(CallType.values))();

  @override
  Set<Column> get primaryKey => {id};
}

// Conversations Table
class Conversations extends Table {
  IntColumn get id => integer()();
  TextColumn get type =>
      text().map(const EnumNameConverter(ConversationType.values))();
  TextColumn get createdAt => text().nullable()();
  TextColumn get dmKey => text().nullable()();
  IntColumn get createrId => integer().nullable()();
  TextColumn get title => text().nullable()();
  IntColumn get userId => integer().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  IntColumn get lastMessageId => integer().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
  TextColumn get updatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Conversation Members Table
class ConversationMembers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get conversationId => integer()();
  IntColumn get userId => integer()();
  TextColumn get role => text().map(const EnumNameConverter(ChatRole.values))();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  TextColumn get joinedAt => text().nullable()();
  TextColumn get removedAt => text().nullable()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get lastReadMessageId => integer().nullable()();
  IntColumn get lastDeliveredMessageId => integer().nullable()();
}

// Messages Table
class Messages extends Table {
  Int64Column get id => int64()();
  IntColumn get conversationId => integer()();
  IntColumn get senderId => integer()();
  TextColumn get type =>
      text().map(const EnumNameConverter(MessageType.values))();
  TextColumn get body => text().nullable()();
  TextColumn get status =>
      text().map(const EnumNameConverter(MessageStatus.values))();
  TextColumn get attachments =>
      text().nullable().map(const JsonMapConverter())();
  TextColumn get metadata => text().nullable().map(const JsonMapConverter())();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isStarred => boolean().withDefault(const Constant(false))();
  BoolColumn get isReplied => boolean().withDefault(const Constant(false))();
  BoolColumn get isForwarded => boolean().withDefault(const Constant(false))();
  TextColumn get sentAt => text()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class MessageStatusModel extends Table {
  Int64Column get id => int64().autoIncrement()();
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
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
