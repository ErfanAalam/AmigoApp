import 'package:flutter/foundation.dart';

import '../../../db/repositories/call.repo.dart';
import '../../../models/call.model.dart' as app_call;

/// Persists Stream Video calls into the local SQLite `calls` table.
///
/// We get every state transition we need (ringing / accepted / rejected /
/// connected / disconnected) directly from the SDK's call.state stream, so
/// there's no need to depend on the backend webhook for call-history
/// bookkeeping. Each method is idempotent — replaying the same transition
/// is a no-op, which matters because the SDK can fire the same status
/// event multiple times in quick succession during reconnects.
///
/// Keys are the full Stream call cid (e.g. `default:<uuid>`). We use the
/// cid verbatim as the row id; that guarantees no collision with ids from
/// the legacy WebRTC backend (which writes plain UUIDs).
class StreamCallLogger {
  StreamCallLogger._();
  static final StreamCallLogger instance = StreamCallLogger._();

  final CallRepository _repo = CallRepository();

  /// In-flight per-call state, keyed by cid. Holds the values needed to
  /// finalise the row when the call ends — startedAt for status copy,
  /// answeredAt for duration calculation.
  final Map<String, _LiveCall> _live = {};

  /// First sight of a ringing call — caller dialled, or callee got rung.
  /// Inserts a `ringing` row keyed on cid; subsequent calls update only
  /// when state actually changes.
  Future<void> recordStart({
    required String cid,
    required String callerId,
    required String calleeId,
    required bool isOutgoing,
  }) async {
    if (_live.containsKey(cid)) return;
    final now = DateTime.now();
    _live[cid] = _LiveCall(
      cid: cid,
      callerId: callerId,
      calleeId: calleeId,
      startedAt: now,
    );
    try {
      await _repo.insertCall(app_call.CallModel(
        id: cid,
        callerId: callerId,
        calleeId: calleeId,
        contactId: isOutgoing ? calleeId : callerId,
        startedAt: now,
        status: app_call.CallStatus.ringing,
        callType: isOutgoing
            ? app_call.CallType.outgoing
            : app_call.CallType.incoming,
        createdAt: now,
      ));
    } catch (e, st) {
      debugPrint('[STREAM-LOG] recordStart failed: $e\n$st');
    }
  }

  /// Pickup transition — callee accepted, SFU connected. Stamps answeredAt
  /// so the terminal handler can compute the on-call duration.
  Future<void> recordAnswered(String cid) async {
    final entry = _live[cid];
    if (entry == null) return;
    if (entry.answeredAt != null) return;
    final now = DateTime.now();
    entry.answeredAt = now;
    try {
      await _repo.insertCall(app_call.CallModel(
        id: cid,
        callerId: entry.callerId,
        calleeId: entry.calleeId,
        contactId: entry.callerId, // overwritten by repo on read
        startedAt: entry.startedAt,
        answeredAt: now,
        status: app_call.CallStatus.answered,
        createdAt: entry.startedAt,
      ));
    } catch (e, st) {
      debugPrint('[STREAM-LOG] recordAnswered failed: $e\n$st');
    }
  }

  /// Final transition — disconnect / decline / miss. Computes durationSeconds
  /// from answeredAt when applicable, then drops the cid from the live map
  /// so a subsequent ring with the same cid (shouldn't happen, but) starts
  /// clean.
  Future<void> recordTerminal({
    required String cid,
    required app_call.CallStatus status,
    String? reason,
  }) async {
    final entry = _live[cid];
    if (entry == null) return;
    final now = DateTime.now();
    final duration = entry.answeredAt != null
        ? now.difference(entry.answeredAt!).inSeconds
        : 0;
    try {
      await _repo.insertCall(app_call.CallModel(
        id: cid,
        callerId: entry.callerId,
        calleeId: entry.calleeId,
        contactId: entry.callerId,
        startedAt: entry.startedAt,
        answeredAt: entry.answeredAt,
        endedAt: now,
        durationSeconds: duration,
        status: status,
        reason: reason,
        createdAt: entry.startedAt,
      ));
    } catch (e, st) {
      debugPrint('[STREAM-LOG] recordTerminal failed: $e\n$st');
    }
    _live.remove(cid);
  }

  /// Cold-path entry: the FCM background handler received `call.missed` —
  /// app was killed, no call.state stream ever fired. Insert a missed row
  /// straight from the push payload.
  Future<void> recordColdMissed({
    required String cid,
    required String callerId,
    required String calleeId,
  }) async {
    if (await _repo.callExists(cid)) return;
    final now = DateTime.now();
    try {
      await _repo.insertCall(app_call.CallModel(
        id: cid,
        callerId: callerId,
        calleeId: calleeId,
        contactId: callerId,
        startedAt: now,
        endedAt: now,
        status: app_call.CallStatus.missed,
        reason: 'timeout',
        callType: app_call.CallType.incoming,
        createdAt: now,
      ));
    } catch (e, st) {
      debugPrint('[STREAM-LOG] recordColdMissed failed: $e\n$st');
    }
  }

  /// Cold-path entry: caller cancelled before pickup, app was killed. Only
  /// inserts when the row doesn't already exist — if the warm-path got
  /// there first (foreground state-stream fired) we keep its richer entry.
  Future<void> recordColdEnded({
    required String cid,
    required String callerId,
    required String calleeId,
  }) async {
    if (await _repo.callExists(cid)) return;
    final now = DateTime.now();
    try {
      await _repo.insertCall(app_call.CallModel(
        id: cid,
        callerId: callerId,
        calleeId: calleeId,
        contactId: callerId,
        startedAt: now,
        endedAt: now,
        status: app_call.CallStatus.missed,
        reason: 'cancelled',
        callType: app_call.CallType.incoming,
        createdAt: now,
      ));
    } catch (e, st) {
      debugPrint('[STREAM-LOG] recordColdEnded failed: $e\n$st');
    }
  }

  /// Drop in-flight tracking on hard-reset paths (logout, dispose).
  void clear() => _live.clear();
}

class _LiveCall {
  final String cid;
  final String callerId;
  final String calleeId;
  final DateTime startedAt;
  DateTime? answeredAt;
  _LiveCall({
    required this.cid,
    required this.callerId,
    required this.calleeId,
    required this.startedAt,
  });
}
