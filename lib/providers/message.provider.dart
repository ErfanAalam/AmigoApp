import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/repositories/conversations.repo.dart';
import '../db/repositories/message.repo.dart';
import '../models/conversations.model.dart';
import '../models/group.model.dart';
import '../models/message.model.dart';
import '../services/user-status.service.dart';

/// Reactive stream of messages for a specific conversation.
/// Backed by a Drift watch query — the UI auto-rebuilds whenever any write
/// path (WebSocket, long-polling, FCM background handler) inserts into SQLite.
final messageStreamProvider =
    StreamProvider.family<List<MessageModel>, int>((ref, convId) {
  return MessageRepository().watchMessages(convId);
});

/// Reactive stream of DM conversations ordered by last activity.
/// Backed by Drift — auto-sorts the list when a new message updates the
/// conversations table, regardless of how the message arrived.
final dmListStreamProvider = StreamProvider<List<DmModel>>((ref) {
  return ConversationRepository().watchDmConversations();
});

/// Reactive stream of group conversations ordered by last activity.
final groupListStreamProvider = StreamProvider<List<GroupModel>>((ref) {
  return ConversationRepository().watchGroupConversations();
});

/// Reactive stream of user online status map.
/// Bridges UserStatusService into Riverpod so the DM list rebuilds
/// whenever any user goes online/offline without needing a DB write.
final userStatusStreamProvider = StreamProvider<Map<int, bool>>((ref) {
  return UserStatusService().userStatusStream;
});
