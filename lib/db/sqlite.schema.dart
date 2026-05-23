import 'dart:io';
import 'package:amigo/db/type-converters.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'sqlite.schema.g.dart';

// Users Table
class Users extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get role => text().nullable()();
  BoolColumn get isOnline => boolean()();
  TextColumn get profilePic => text().nullable()();
  BoolColumn get callAccess =>
      boolean().withDefault(const Constant(true)).nullable()();
  TextColumn get lastSeen => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Contacts Table — local device contacts, keyed by the same UUID string as
// the matching UserModel so bridging between contact list and user list is
// a simple 1:1 lookup.
class Contacts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get profilePic => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Calls Table
class Calls extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get callerId => text()();
  TextColumn get calleeId => text()();
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

// Chats Table (renamed from Conversations)
class Chats extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get type => text()(); // 'dm' or 'group' or 'community_group'
  TextColumn get title => text().nullable()();
  // Group avatar URL. Null for DMs (use peer's users.profilePic instead).
  // Updated by the chat_details:update WS event.
  TextColumn get profilePic => text().nullable()();
  TextColumn get createrId => text().nullable()();
  IntColumn get unreadCount =>
      integer().withDefault(const Constant(0)).nullable()();
  TextColumn get lastMsgId => text().nullable()();
  TextColumn get lastMsgAt => text().nullable()();
  TextColumn get pinnedMsgId => text().nullable()();
  TextColumn get deletedAt => text().nullable()();
  // Client-only pin-to-top. Null = not pinned; timestamp = when it was pinned.
  // The list view sorts pinned chats above non-pinned, with most-recently-pinned
  // first. Activity on a chat (new message etc.) cannot reshuffle pinned rows.
  TextColumn get pinnedAt => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  // Per-user mute end time as ISO-8601 UTC (mirrors chat_members.muted_until
  // on the server). Null = not muted. A far-future timestamp ("forever") is
  // produced by the backend's MUTED_FOREVER constant. UI / FCM handler treat
  // muted = (mutedUntil != null && DateTime.parse(mutedUntil).isAfter(now)).
  TextColumn get mutedUntil => text().nullable()();
  TextColumn get createdAt => text().nullable()();
  TextColumn get updatedAt => text().nullable()();
  BoolColumn get needSync => boolean().withDefault(const Constant(true))();
  // Disappearing-messages: null = off. Mirrors chats.disappearing_after_sec
  // on the server. Updated by the conversation:disappearing WS event.
  IntColumn get disappearingAfterSec => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Chat Members Table (renamed from ConversationMembers)
class ChatMembers extends Table {
  TextColumn get id => text()(); // UUID from backend
  TextColumn get chatId => text()();
  TextColumn get userId => text()();
  TextColumn get role => text()();
  TextColumn get joinedAt => text().nullable()();
  TextColumn get removedAt => text().nullable()();
  TextColumn get lastReadMsgId => text().nullable()();
  TextColumn get lastDeliveredMsgId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Messages Table
class Messages extends Table {
  TextColumn get id => text()(); // UUIDv7 client-generated, server PK
  TextColumn get chatId => text()();
  TextColumn get senderId => text().nullable()();
  TextColumn get repliedTo => text().nullable()();
  TextColumn get type => text()();
  TextColumn get body => text().nullable()();
  TextColumn get attachments =>
      text().nullable().map(const JsonMapConverter())();
  TextColumn get sentAt => text()();
  TextColumn get deletedAt => text().nullable()();
  // Disappearing-messages deadline; null = never expires. Server stamps
  // this at insert time and ships it on the message:new broadcast. The
  // view layer filters expired-but-not-yet-deleted messages from the list;
  // the row is only actually soft-deleted when the server's message:delete
  // event arrives.
  TextColumn get expiresAt => text().nullable()();
  BoolColumn get isFailed =>
      boolean().withDefault(const Constant(false))(); // client-only
  // Client-only star. Null = unstarred; ISO-8601 timestamp = when starred.
  // The starred-messages screen sorts by this DESC (most recent first).
  TextColumn get starredAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Per-user delivery / read / reaction / delete-for-me state
// (renamed from MessageStatusModel to MessageInfo for parity with backend)
class MessageInfo extends Table {
  TextColumn get chatId => text()();
  TextColumn get messageId => text()();
  TextColumn get userId => text()();
  TextColumn get deliveredAt => text().nullable()();
  TextColumn get readAt => text().nullable()();
  TextColumn get reaction => text().nullable()(); // per-user emoji
  TextColumn get deletedAt => text().nullable()(); // per-user "delete for me"

  @override
  Set<Column> get primaryKey => {messageId, userId};
}

// Outbound WS events queued while offline, replayed on reconnect.
class MissedWsMessages extends Table {
  TextColumn get id => text()();
  TextColumn get eventType => text()();
  TextColumn get payload => text()(); // JSON-encoded WS payload
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Users,
    Contacts,
    Calls,
    Chats,
    ChatMembers,
    Messages,
    MessageInfo,
    MissedWsMessages,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createIndices(m);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Drop every known table (legacy + current), then recreate fresh.
        const tables = <String>[
          // Legacy v≤6
          'conversations',
          'conversation_members',
          'message_status_model',
          // Current v8
          'users',
          'contacts',
          'calls',
          'chats',
          'chat_members',
          'messages',
          'message_info',
          'missed_ws_messages',
        ];
        for (final t in tables) {
          await m.database.customStatement('DROP TABLE IF EXISTS $t');
        }
        await m.createAll();
        await _createIndices(m);
      },
    );
  }

  Future<void> _createIndices(Migrator m) async {
    await m.database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS unique_chat_member_active '
      'ON chat_members(chat_id, user_id) WHERE removed_at IS NULL',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_chat_sent ON messages(chat_id, sent_at)',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_chat_sender ON messages(chat_id, sender_id)',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_message_info_chat ON message_info(chat_id)',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_message_info_message ON message_info(message_id)',
    );
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_chats_type ON chats(type)',
    );
    // Speeds up the per-chat starred-messages listing.
    await m.database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_chat_starred '
      'ON messages(chat_id, starred_at) WHERE starred_at IS NOT NULL',
    );
  }

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, 'amigo_chats.db'));
      return NativeDatabase.createInBackground(
        file,
        setup: (db) {
          db.execute('PRAGMA journal_mode=WAL');
          db.execute('PRAGMA busy_timeout=5000');
        },
      );
    });
  }
}
