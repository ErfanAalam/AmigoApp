import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/repositories/conversations.repo.dart';
import '../db/repositories/message.repo.dart';
import '../db/sqlite.schema.dart';
import '../models/conversations.model.dart';
import '../models/group.model.dart';
import '../models/message.model.dart';
import '../services/socket/ws-message.handler.dart';
import '../services/user-status.service.dart';
import '../types/socket.types.dart';
import '../utils/user.utils.dart';

/// Reactive stream of messages for a specific conversation.
/// Backed by a Drift watch query — the UI auto-rebuilds whenever any write
/// path (WebSocket, long-polling, FCM background handler) inserts into SQLite.
final messageStreamProvider =
    StreamProvider.family<List<MessageModel>, String>((ref, convId) async* {
  final user = await UserUtils().getUserDetails();
  yield* MessageRepository().watchMessages(
    convId,
    currentUserId: user?.id,
  );
});

/// Reactive stream of DM conversations ordered by last activity.
/// Backed by Drift — auto-sorts the list when a new message updates the
/// conversations table, regardless of how the message arrived.
final dmListStreamProvider = StreamProvider<List<DmModel>>((ref) async* {
  // Resolve current user id once so the repo can exclude it from the DM's
  // member list when picking the "recipient" — otherwise if chat_members
  // contains both users, the current user's row may be picked first and
  // the DM list ends up showing our own name instead of the recipient's.
  final user = await UserUtils().getUserDetails();
  yield* ConversationRepository()
      .watchDmConversations(currentUserId: user?.id);
});

/// Reactive stream of group conversations ordered by last activity.
final groupListStreamProvider = StreamProvider<List<GroupModel>>((ref) {
  return ConversationRepository().watchGroupConversations();
});

/// Reactive watcher of a single chat row by id — emits whenever the row
/// changes. Lets AppBars (group-list rows, group-messaging header, chat-
/// details hero) repaint live when `chat_details:update` rewrites title or
/// profile pic in local DB.
final chatByIdStreamProvider =
    StreamProvider.family<Chat?, String>((ref, chatId) {
  return ConversationRepository().watchChatById(chatId);
});

/// Reactive stream of user online status map.
/// Bridges UserStatusService into Riverpod so the DM list rebuilds
/// whenever any user goes online/offline without needing a DB write.
final userStatusStreamProvider = StreamProvider<Map<String, bool>>((ref) {
  return UserStatusService().userStatusStream;
});

/// Reactive stream of peer profile updates (`user:update` WS event).
/// Surfaces every name/profile-pic change so screens that derive their
/// view from the local users table can invalidate themselves — Drift's
/// chats-table watchers don't re-fire on users-table writes alone.
final userUpdateStreamProvider = StreamProvider<UserUpdatePayload>((ref) {
  return WebSocketMessageHandler().userUpdateStream;
});
