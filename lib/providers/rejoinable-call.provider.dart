import 'dart:async';

import 'package:amigo/env.dart';
import 'package:amigo/services/cookies.service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A call the local user (L) just dropped out of that the other party (G) is
/// still holding open. While this is non-null the call is rejoinable: a pulsing
/// green dot shows on its Call-Logs row and over the Calls tab, and tapping it
/// rejoins. It auto-clears at [expiresAt] (the 10s window the waiter granted).
@immutable
class RejoinableCall {
  /// Stream call cid (== the Call-Logs row id).
  final String cid;

  /// The waiter (G) — who L reconnects to.
  final String peerId;
  final String peerName;
  final String? peerPfp;

  /// When the waiter's rejoin window closes; the dot is gone after this.
  final DateTime expiresAt;

  const RejoinableCall({
    required this.cid,
    required this.peerId,
    required this.peerName,
    this.peerPfp,
    required this.expiresAt,
  });
}

/// Holds the single currently-rejoinable call (or null). Backed by a
/// self-cancelling expiry timer so the dot disappears exactly when the window
/// closes even if no explicit clear signal arrives.
class RejoinableCallNotifier extends Notifier<RejoinableCall?> {
  Timer? _expiryTimer;

  @override
  RejoinableCall? build() {
    ref.onDispose(() {
      _expiryTimer?.cancel();
      _expiryTimer = null;
    });
    return null;
  }

  /// Set (or replace — last drop wins) the current rejoinable call. Arms a
  /// timer that clears it exactly at [RejoinableCall.expiresAt]. A call that's
  /// already expired is ignored.
  void set(RejoinableCall call) {
    _expiryTimer?.cancel();
    final now = DateTime.now();
    if (!call.expiresAt.isAfter(now)) {
      state = null;
      return;
    }
    state = call;
    final ms = call.expiresAt.difference(now).inMilliseconds;
    _expiryTimer = Timer(Duration(milliseconds: ms), () {
      _expiryTimer = null;
      if (state?.cid == call.cid) {
        debugPrint('[REJOIN] window elapsed — clearing dot cid=${call.cid}');
        state = null;
      }
    });
    debugPrint('[REJOIN] set rejoinable cid=${call.cid} '
        'peer=${call.peerName} in ${ms}ms');
  }

  /// Clear the rejoinable call. With [cid], only clears if it matches the
  /// current one (so a stale `expired` for an older call can't wipe a newer).
  void clear({String? cid}) {
    if (cid != null && state?.cid != cid) return;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (state != null) debugPrint('[REJOIN] clear rejoinable cid=${state?.cid}');
    state = null;
  }

  /// Hydrate from the backend's rejoin-window registry. Used on app open /
  /// resume to cover the killed-then-reopened-within-the-window case where the
  /// WS / FCM push may have been missed.
  Future<void> hydrateFromBackend() async {
    try {
      final cookieService = CookieService();
      await cookieService.init();
      final accessToken = await cookieService.getAccessToken();
      if (accessToken == null) return;
      final res = await Dio().get(
        '${Environment.baseUrl}/call/stream/rejoinable',
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final data = res.data?['data'];
      if (data == null) {
        clear();
        return;
      }
      final cid = data['cid']?.toString();
      final peerId = data['peer_id']?.toString();
      final expiresAt =
          DateTime.tryParse(data['expires_at']?.toString() ?? '');
      if (cid == null || peerId == null || expiresAt == null) return;
      final peerName = data['peer_name']?.toString();
      set(RejoinableCall(
        cid: cid,
        peerId: peerId,
        peerName: (peerName != null && peerName.isNotEmpty) ? peerName : 'Unknown',
        peerPfp: data['peer_pfp']?.toString(),
        expiresAt: expiresAt,
      ));
    } catch (e) {
      debugPrint('[REJOIN] hydrateFromBackend failed: $e');
    }
  }
}

final rejoinableCallProvider =
    NotifierProvider<RejoinableCallNotifier, RejoinableCall?>(() {
  return RejoinableCallNotifier();
});
