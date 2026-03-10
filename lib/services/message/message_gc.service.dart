import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../api/api_service.dart';
import '../../db/repositories/conversations.repo.dart';
import '../../db/repositories/message.repo.dart';
import '../../models/message.model.dart';
import '../../types/socket.types.dart';
import '../../utils/user.utils.dart';
import '../socket/transport.manager.dart';

/// Singleton garbage collector for outbound messages.
///
/// Runs on reconnect, foreground resume, and a 3-minute periodic timer.
/// For each stalled message it first checks if the server already has it,
/// then either updates local status or retries the send.
class MessageGarbageCollector {
  static final MessageGarbageCollector _instance = MessageGarbageCollector._();
  factory MessageGarbageCollector() => _instance;
  static MessageGarbageCollector get instance => _instance;
  MessageGarbageCollector._();

  static const _unsentThreshold = Duration(seconds: 10);
  static const _periodicInterval = Duration(seconds: 20);

  final _messageRepo = MessageRepository();
  final _convRepo = ConversationRepository();
  final _transportManager = TransportManager();
  final _apiService = ApiService();

  bool _isRunning = false;
  Timer? _periodicTimer;

  /// Start the periodic GC timer. Call once after login.
  void init() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_periodicInterval, (_) => runGC());
    debugPrint(
      '[MSG-GC] Initialized (interval: ${_periodicInterval.inMinutes} min)',
    );
  }

  void dispose() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Run a single GC pass. Idempotent — concurrent calls are no-ops.
  Future<void> runGC() async {
    if (_isRunning) return;
    _isRunning = true;
    try {
      final currentUser = await UserUtils().getUserDetails();
      if (currentUser == null) return;

      final stalled = await _messageRepo.getStalledMessages(
        userId: currentUser.id,
        unsentThreshold: _unsentThreshold,
      );

      if (stalled.isEmpty) {
        debugPrint('[MSG-GC] No stalled messages found');
        return;
      }

      debugPrint('[MSG-GC] Found ${stalled.length} stalled message(s)');

      // Group by conversation
      final Map<int, List<MessageModel>> byConv = {};
      for (final m in stalled) {
        byConv.putIfAbsent(m.conversationId, () => []).add(m);
      }

      for (final entry in byConv.entries) {
        await _processGroup(entry.key, entry.value, currentUser.id);
      }
    } catch (e, st) {
      debugPrint('[MSG-GC] Error: $e\n$st');
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _processGroup(
    int convId,
    List<MessageModel> msgs,
    int userId,
  ) async {
    final ids = msgs.map((m) => m.id.toString()).toList();

    final response = await _apiService.chat.verifyMessageIds(
      messageIds: ids,
      conversationId: convId,
    );

    if (!response.isSuccess || response.data == null) {
      debugPrint('[MSG-GC] verifyMessageIds failed for conv $convId');
      return;
    }

    final data = response.data as Map<String, dynamic>;
    final found = (data['found'] as Map<String, dynamic>?) ?? {};
    final notFound =
        ((data['not_found'] as List?)?.map((e) => e.toString()).toSet()) ??
        <String>{};

    for (final msg in msgs) {
      final idStr = msg.id.toString();
      if (found.containsKey(idStr)) {
        await _updateFoundStatus(msg, found[idStr] as Map<String, dynamic>);
      } else if (notFound.contains(idStr)) {
        await _retryNotFound(msg, convId);
      }
    }
  }

  Future<void> _updateFoundStatus(
    MessageModel msg,
    Map<String, dynamic> info,
  ) async {
    final readBy = (info['read_by'] as List?)?.isNotEmpty ?? false;
    final deliveredTo = (info['delivered_to'] as List?)?.isNotEmpty ?? false;
    final newStatus = readBy
        ? MessageStatusType.read
        : deliveredTo
        ? MessageStatusType.delivered
        : MessageStatusType.sent;

    debugPrint(
      '[MSG-GC] msg ${msg.id} found on server → updating to ${newStatus.value}',
    );
    await _messageRepo.updateMessageStatus(msg.id, newStatus);
  }

  Future<void> _retryNotFound(MessageModel msg, int convId) async {
    // Skip media where upload itself failed
    final isMedia = [
      MessageType.image,
      MessageType.video,
      MessageType.audio,
      MessageType.document,
    ].contains(msg.type);
    if (isMedia && msg.metadata?['upload_failed'] == true) {
      debugPrint('[MSG-GC] msg ${msg.id} skipped — upload_failed=true');
      return;
    }

    if (!_transportManager.isConnected) {
      debugPrint('[MSG-GC] msg ${msg.id} not retried — transport disconnected');
      return;
    }

    // Resolve conversation type for payload
    final convTypeStr = await _convRepo.getConversationTypeById(convId);
    final convType = ChatType.fromString(convTypeStr) ?? ChatType.dm;

    // Reset to unsent before retry
    await _messageRepo.updateMessageFields(
      msg.id,
      status: MessageStatusType.unsent,
      isFailed: false,
    );

    debugPrint('[MSG-GC] Retrying msg ${msg.id} in conv $convId');

    final chatPayload = ChatMessagePayload(
      id: msg.id,
      convId: convId,
      senderId: msg.senderId,
      senderName: msg.senderName ?? '',
      attachments: msg.attachments,
      convType: convType,
      msgType: msg.type,
      body: msg.body,
      metadata: msg.metadata,
      sentAt: DateTime.parse(msg.sentAt).toUtc(),
    );

    final wsmsg = WSMessage(
      type: WSMessageType.messageNew,
      payload: chatPayload,
      wsTimestamp: DateTime.now(),
    ).toJson();

    final sent = await _transportManager.sendMessage(wsmsg);
    if (!sent) {
      debugPrint('[MSG-GC] Retry failed for msg ${msg.id} — marking failed');
      await _messageRepo.updateMessageFields(
        msg.id,
        status: MessageStatusType.failed,
        isFailed: true,
      );
    }
  }
}
