import 'dart:async';

import '../db/repositories/message.repo.dart';
import '../models/message.model.dart';

/// Kicks off a conversation's first DB read while the navigation animation
/// runs, so the messaging screen has a snapshot ready by the time its
/// `initState` lands. Best-effort and fire-and-forget — the screen's Drift
/// stream still subscribes normally, so a missed pre-warm just means the
/// first paint waits the usual ~one frame for the stream to emit.
///
/// The pending future is held briefly (auto-evicted after [_ttl]) to avoid
/// unbounded memory growth if the user taps a tile but the screen never
/// opens (e.g. a route guard intercepts).
class ChatPrewarm {
  ChatPrewarm._();

  static const _ttl = Duration(seconds: 8);
  static const _defaultLimit = 50;
  static final _repo = MessageRepository();
  static final Map<String, Future<List<MessageModel>>> _pending = {};

  /// Call from a chat-list tile's onTap, before `Navigator.push`. Idempotent
  /// per chatId for the lifetime of one warm cycle — duplicate calls are
  /// ignored.
  static void warmMessages(String chatId, {int limit = _defaultLimit}) {
    if (chatId.isEmpty || _pending.containsKey(chatId)) return;
    final future = _repo
        .getMessagesByConversation(chatId, limit: limit)
        .catchError((_) => <MessageModel>[]);
    _pending[chatId] = future;
    Timer(_ttl, () {
      // Only evict if it's still the same future (defensive against a
      // second `warmMessages` call having replaced the entry).
      if (_pending[chatId] == future) _pending.remove(chatId);
    });
  }

  /// Removes and returns the pending prewarm for [chatId], if any. The
  /// caller takes ownership — a hit fires once and is gone.
  static Future<List<MessageModel>>? takeMessages(String chatId) {
    return _pending.remove(chatId);
  }
}
