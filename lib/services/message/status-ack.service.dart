import 'dart:async';
import 'dart:convert';

import 'package:amigo/db/repositories/missed-ws-messages.repo.dart';
import 'package:amigo/services/socket/transport.manager.dart';
import 'package:amigo/types/socket.types.dart';
import 'package:amigo/utils/id.utils.dart';
import 'package:flutter/foundation.dart';

class _ChatAckBuffer {
  final Set<String> msgIds = {};
  final Set<String> statuses = {};
}

class StatusAckService {
  StatusAckService._();
  static final instance = StatusAckService._();

  static const _debounceMs = 800;

  final Map<String, _ChatAckBuffer> _buffer = {};
  Timer? _debounceTimer;
  String? _currentUserId;

  final _missedRepo = MissedWsMessagesRepository();

  void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// Current authenticated user id, if known. Set early during chat init, so
  /// it's a cheap synchronous source for presence/ack payloads.
  String? get currentUserId => _currentUserId;

  void ackMessage(String chatId, String msgId, {required bool isRead}) {
    debugPrint(
      '[StatusAck] Buffering msgId=$msgId chat=$chatId isRead=$isRead userId=$_currentUserId',
    );
    final buf = _buffer.putIfAbsent(chatId, () => _ChatAckBuffer());
    buf.msgIds.add(msgId);
    buf.statuses.add('delivered');
    if (isRead) buf.statuses.add('read');

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), _flush);
  }

  void flushNow() {
    _debounceTimer?.cancel();
    _flush();
  }

  void _flush() {
    if (_buffer.isEmpty) return;
    if (_currentUserId == null) {
      debugPrint('[StatusAck] ⚠️ _flush skipped — currentUserId is null!');
      return;
    }

    final totalMsgs = _buffer.values.fold<int>(
      0,
      (s, b) => s + b.msgIds.length,
    );
    debugPrint(
      '[StatusAck] Flushing ${_buffer.length} chats, $totalMsgs messages',
    );

    final acks = <Map<String, dynamic>>[];
    for (final entry in _buffer.entries) {
      acks.add({
        'chat_id': entry.key,
        'msg_ids': entry.value.msgIds.toList(),
        'status': entry.value.statuses.toList(),
      });
    }

    final payload = {
      'recipient_id': _currentUserId,
      'at': DateTime.now().toUtc().toIso8601String(),
      'acks': acks,
    };

    _buffer.clear();

    final wsMsg = WSMessage(
      type: WSMessageType.messageStatusAck,
      payload: MessageStatusAckPayload.fromJson(payload),
      wsTimestamp: DateTime.now(),
    );

    final transport = TransportManager();
    if (transport.isConnected) {
      debugPrint(
        '[StatusAck] Sending via WS: ${acks.length} chats, ${acks.map((a) => (a['msg_ids'] as List).length).reduce((a, b) => a + b)} msgs',
      );
      transport
          .sendMessage(wsMsg.toJson())
          .then((_) {
            debugPrint('[StatusAck] ✅ WS send succeeded');
          })
          .catchError((e) {
            debugPrint('[StatusAck] WS send failed, storing offline: $e');
            _storeOffline(payload);
            return false;
          });
    } else {
      _storeOffline(payload);
    }
  }

  void _storeOffline(Map<String, dynamic> payload) {
    debugPrint('[StatusAck] Storing offline for replay');
    _missedRepo.storeEvent('message:status:ack', payload);
  }

  void dispose() {
    _debounceTimer?.cancel();
    _buffer.clear();
  }
}
